import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_peripheral.dart';
import 'heart_rate_database.dart';

class HeartRatePage extends StatefulWidget {
  const HeartRatePage({super.key});

  @override
  State<HeartRatePage> createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage>
    with SingleTickerProviderStateMixin {
  // Harus sama dengan nama channel di MainActivity.kt
  static const _channel = EventChannel('heart_rate/stream');

  // Pilihan interval pengiriman batch yang tersedia (menit).
  static const _intervals = <int>[3, 5];

  // Akses penyimpanan SQLite untuk riwayat detak jantung.
  final _db = HeartRateDatabase.instance;

  // BLE peripheral: watch mengiklankan & mengirim data ke smartphone.
  final _ble = BlePeripheral.instance;

  late final AnimationController _pulseController;

  // Membaca sensor terus-menerus selama mode aktif.
  StreamSubscription<dynamic>? _sensorSub;
  Timer? _logTimer; // menyimpan 1 pembacaan tiap detik
  Timer? _intervalTimer; // mengirim batch tiap N menit

  int _intervalMinutes = 5; // interval pengiriman batch (menit), default 5
  bool _running = false; // mode pemantauan aktif
  bool _flushing = false; // sedang mengirim batch ke phone
  bool _permanentlyDenied = false;
  bool _denied = false; // izin ditolak (tapi belum permanen)
  PermissionStatus? _lastStatus; // status izin terakhir, untuk diagnostik
  String? _error; // error sensor (bukan soal izin)
  Duration _untilSync = Duration.zero; // sisa waktu ke pengiriman berikutnya

  double _latestBpm = 0; // nilai sensor terbaru
  int _latestAccuracy = 0;
  int _unsentCount = 0; // jumlah record belum terkirim ke phone
  final List<HeartRateReading> _history = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.85,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _ble.status.addListener(_onBleChanged);
    _ble.message.addListener(_onBleChanged);
    _loadHistory();
  }

  @override
  void dispose() {
    _cancelTimersAndStream();
    _ble.status.removeListener(_onBleChanged);
    _ble.message.removeListener(_onBleChanged);
    _ble.stop();
    _pulseController.dispose();
    super.dispose();
  }

  void _onBleChanged() {
    if (mounted) setState(() {});
  }

  /// Ambil riwayat + jumlah belum terkirim dari SQLite saat aplikasi dibuka.
  Future<void> _loadHistory() async {
    final readings = await _db.getReadings();
    final unsent = await _db.countUnsynced();
    if (!mounted) return;
    setState(() {
      _history
        ..clear()
        ..addAll(readings);
      _unsentCount = unsent;
    });
  }

  /// Dipanggil dari tombol: minta izin BODY_SENSORS (dan Bluetooth) lalu mulai
  /// pemantauan kontinu.
  Future<void> _requestAndStart() async {
    final status = await Permission.sensors.request();
    debugPrint('[HR] Status izin sensor: $status');
    setState(() => _lastStatus = status);
    if (status.isGranted || status.isLimited) {
      setState(() {
        _permanentlyDenied = false;
        _denied = false;
      });
      // Izin Bluetooth (Android 12+) untuk advertising & melayani GATT.
      await [
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ].request();
      _start();
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      setState(() {
        _permanentlyDenied = true;
        _denied = false;
      });
    } else {
      setState(() {
        _permanentlyDenied = false;
        _denied = true;
      });
    }
  }

  /// Mulai mode pemantauan: sensor menyala terus, tiap detik satu pembacaan
  /// valid disimpan ke SQLite, dan tiap [_intervalMinutes] menit seluruh data
  /// yang belum terkirim dikirim ke smartphone sebagai satu batch.
  void _start() {
    setState(() {
      _running = true;
      _error = null;
      _latestBpm = 0;
      _latestAccuracy = 0;
      _untilSync = Duration(minutes: _intervalMinutes);
    });

    // Mulai mengiklankan agar smartphone bisa terhubung.
    _ble.start();

    // Sensor dibaca terus-menerus selama sesi (tidak dilepas tiap siklus).
    _sensorSub = _channel.receiveBroadcastStream().listen(
      (event) {
        final data = (event as Map).cast<String, dynamic>();
        final bpm = (data['bpm'] as num?)?.toDouble() ?? 0;
        final accuracy = (data['accuracy'] as num?)?.toInt() ?? 0;
        if (mounted) {
          setState(() {
            if (bpm > 0) _latestBpm = bpm;
            _latestAccuracy = accuracy;
            _error = null;
          });
        }
      },
      onError: (Object err) {
        final message = err is PlatformException
            ? (err.message ?? 'Gagal membaca sensor')
            : err.toString();
        if (mounted) setState(() => _error = message);
      },
    );

    // Tiap detik: simpan pembacaan valid + perbarui hitung mundur.
    _logTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());

    // Tiap interval: kirim batch ke phone.
    _intervalTimer = Timer.periodic(
      Duration(minutes: _intervalMinutes),
      (_) => _flush(),
    );
  }

  /// Lepas semua timer dan subscription sensor (tanpa setState).
  void _cancelTimersAndStream() {
    _logTimer?.cancel();
    _logTimer = null;
    _intervalTimer?.cancel();
    _intervalTimer = null;
    _sensorSub?.cancel();
    _sensorSub = null;
  }

  /// Hentikan pemantauan dan perbarui UI.
  void _stop() {
    _cancelTimersAndStream();
    _ble.stop();
    setState(() {
      _running = false;
      _untilSync = Duration.zero;
    });
  }

  /// Dijalankan tiap detik saat mode aktif.
  Future<void> _onTick() async {
    if (!_running) return;

    // Perbarui hitung mundur ke pengiriman berikutnya.
    final next = _untilSync - const Duration(seconds: 1);
    setState(() => _untilSync = next.isNegative ? Duration.zero : next);

    // Simpan satu pembacaan valid per detik.
    if (_latestBpm > 0) {
      final saved = await _db.insertReading(
        HeartRateReading(
          bpm: _latestBpm,
          accuracy: _latestAccuracy,
          time: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _history.insert(0, saved);
        _unsentCount += 1;
      });
    }
  }

  /// Kirim seluruh record yang belum terkirim ke smartphone sebagai satu batch.
  /// Hanya record yang berhasil diterima native (ada phone terhubung) yang
  /// ditandai terkirim — sisanya menunggu interval berikutnya (store-and-forward).
  Future<void> _flush() async {
    if (_flushing) return;
    final pending = await _db.getUnsynced();
    // Selalu reset hitung mundur, ada data atau tidak.
    if (mounted) {
      setState(() => _untilSync = Duration(minutes: _intervalMinutes));
    }
    if (pending.isEmpty) return;

    setState(() => _flushing = true);
    final ok = await _ble.sendBatch(pending);
    if (ok) {
      final ids = [for (final r in pending) if (r.id != null) r.id!];
      await _db.markSynced(ids);
    }
    final unsent = await _db.countUnsynced();
    if (!mounted) return;
    setState(() {
      _flushing = false;
      _unsentCount = unsent;
    });
  }

  /// Hapus seluruh riwayat dari database dan dari UI.
  Future<void> _clearHistory() async {
    await _db.clearReadings();
    if (!mounted) return;
    setState(() {
      _history.clear();
      _unsentCount = 0;
    });
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  String _formatCountdown(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final child = _running ? _buildRunning() : _buildSetup();
    return Scaffold(body: SafeArea(child: Center(child: child)));
  }

  /// Layar awal: pilih interval lalu mulai (sekaligus pintu izin).
  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border, color: Colors.redAccent, size: 36),
          const SizedBox(height: 8),
          Text(
            _permanentlyDenied
                ? 'Izin sensor diblokir. Aktifkan di Pengaturan aplikasi.'
                : _denied
                    ? 'Izin sensor ditolak. Tekan lagi lalu pilih "Allow".'
                    : 'Pilih interval pengiriman ke ponsel.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: (_permanentlyDenied || _denied) ? Colors.amber : null,
            ),
          ),
          if (_lastStatus != null) ...[
            const SizedBox(height: 4),
            Text(
              'status izin: ${_lastStatus!.name}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
          const SizedBox(height: 12),
          _IntervalSelector(
            intervals: _intervals,
            selected: _intervalMinutes,
            onChanged: (value) => setState(() => _intervalMinutes = value),
          ),
          const SizedBox(height: 8),
          Text(
            'Sensor dibaca tiap detik; data dikirim tiap $_intervalMinutes menit.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _permanentlyDenied ? openAppSettings : _requestAndStart,
            child: Text(
              _permanentlyDenied ? 'Buka Pengaturan' : 'Izinkan & Mulai',
            ),
          ),
          if (_denied) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Buka Pengaturan'),
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildHistory(),
          ],
        ],
      ),
    );
  }

  /// Layar saat mode pemantauan berjalan.
  Widget _buildRunning() {
    final hasReading = _latestBpm > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseController,
            child: Icon(
              Icons.favorite,
              color: hasReading ? Colors.redAccent : Colors.red[300],
              size: 40,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasReading ? _latestBpm.toStringAsFixed(0) : '--',
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const Text('BPM', style: TextStyle(fontSize: 13, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(
            _error ??
                (_flushing
                    ? 'Mengirim data ke ponsel…'
                    : 'Kirim berikutnya dalam ${_formatCountdown(_untilSync)}'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: _error != null ? Colors.amber : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Belum terkirim: $_unsentCount  •  interval $_intervalMinutes mnt',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          _buildBleStatus(),
          const SizedBox(height: 10),
          if (_history.isNotEmpty) _buildHistory(),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _stop,
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Berhenti'),
          ),
        ],
      ),
    );
  }

  /// Indikator status koneksi BLE ke smartphone.
  Widget _buildBleStatus() {
    final status = _ble.status.value;
    final IconData icon;
    final Color color;
    final String label;
    switch (status) {
      case BleStatus.connected:
        icon = Icons.bluetooth_connected;
        color = Colors.lightBlueAccent;
        label = 'Ponsel terhubung';
      case BleStatus.advertising:
        icon = Icons.bluetooth_searching;
        color = Colors.blueGrey;
        label = 'Menunggu ponsel…';
      case BleStatus.error:
        icon = Icons.bluetooth_disabled;
        color = Colors.amber;
        label = _ble.message.value ?? 'BLE error';
      case BleStatus.idle:
        icon = Icons.bluetooth;
        color = Colors.grey;
        label = 'BLE nonaktif';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Riwayat (${_history.length})',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
            InkWell(
              onTap: _clearHistory,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline,
                        size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 2),
                    Text(
                      'Hapus',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Tampilkan maksimal 6 pembacaan terakhir agar muat di layar jam.
        ..._history.take(6).map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      r.synced ? Icons.check_circle : Icons.schedule,
                      size: 11,
                      color: r.synced ? Colors.lightBlueAccent : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(r.time),
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
                Text(
                  '${r.bpm.toStringAsFixed(0)} BPM',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pemilih interval (3 / 5 menit) berbentuk chip.
class _IntervalSelector extends StatelessWidget {
  const _IntervalSelector({
    required this.intervals,
    required this.selected,
    required this.onChanged,
  });

  final List<int> intervals;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: intervals.map((minutes) {
        final isSelected = minutes == selected;
        return ChoiceChip(
          label: Text('$minutes menit'),
          selected: isSelected,
          onSelected: (_) => onChanged(minutes),
        );
      }).toList(),
    );
  }
}
