import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // Pilihan interval pembacaan yang tersedia.
  static const _intervals = <int>[1, 3, 5];

  // Berapa lama sensor diberi waktu untuk menghasilkan satu pembacaan valid
  // sebelum dianggap gagal pada siklus tersebut.
  static const _sampleTimeout = Duration(seconds: 25);

  // Akses penyimpanan SQLite untuk riwayat detak jantung.
  final _db = HeartRateDatabase.instance;

  late final AnimationController _pulseController;

  Timer? _intervalTimer; // memicu pembacaan setiap N menit
  Timer? _countdownTimer; // memperbarui hitung mundur tiap detik
  StreamSubscription<dynamic>? _sampleSubscription;

  int _intervalMinutes = 1; // interval terpilih (menit)
  bool _running = false; // mode interval aktif
  bool _sampling = false; // sedang mengambil satu pembacaan
  bool _permanentlyDenied = false;
  bool _denied = false; // izin ditolak (tapi belum permanen)
  PermissionStatus? _lastStatus; // status izin terakhir, untuk diagnostik
  String? _error; // error sensor (bukan soal izin)
  Duration _untilNext = Duration.zero; // sisa waktu ke pembacaan berikutnya

  double? _bpm;
  int _accuracy = 0;
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
    // Muat riwayat tersimpan dari database saat aplikasi dibuka.
    _loadHistory();
  }

  @override
  void dispose() {
    _cancelTimersAndStream();
    _pulseController.dispose();
    super.dispose();
  }

  /// Ambil riwayat yang sudah tersimpan di SQLite agar tetap tampil walau
  /// aplikasi baru saja dibuka kembali.
  Future<void> _loadHistory() async {
    final readings = await _db.getReadings();
    if (!mounted) return;
    setState(() {
      _history
        ..clear()
        ..addAll(readings);
    });
  }

  /// Dipanggil dari tombol: minta izin BODY_SENSORS lalu mulai mode interval.
  Future<void> _requestAndStart() async {
    final status = await Permission.sensors.request();
    debugPrint('[HR] Status izin sensor: $status');
    setState(() => _lastStatus = status);
    // isGranted juga true untuk "limited"/"provisional" pada beberapa platform.
    if (status.isGranted || status.isLimited) {
      setState(() {
        _permanentlyDenied = false;
        _denied = false;
      });
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

  /// Mulai mode interval: ambil satu pembacaan sekarang, lalu jadwalkan
  /// pembacaan berikutnya setiap [_intervalMinutes] menit.
  ///
  /// Riwayat dari sesi sebelumnya tetap dipertahankan (tidak dihapus) karena
  /// sudah tersimpan di database.
  void _start() {
    setState(() {
      _running = true;
      _error = null;
      _bpm = null;
      _accuracy = 0;
    });

    _takeReading();
    final interval = Duration(minutes: _intervalMinutes);
    _intervalTimer = Timer.periodic(interval, (_) => _takeReading());
    _restartCountdown();
  }

  /// Lepas semua timer dan subscription sensor (tanpa setState).
  /// Aman dipanggil dari dispose().
  void _cancelTimersAndStream() {
    _intervalTimer?.cancel();
    _intervalTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _sampleSubscription?.cancel();
    _sampleSubscription = null;
  }

  /// Hentikan mode interval dan perbarui UI.
  void _stop() {
    _cancelTimersAndStream();
    setState(() {
      _running = false;
      _sampling = false;
      _untilNext = Duration.zero;
    });
  }

  /// Hapus seluruh riwayat dari database dan dari UI.
  Future<void> _clearHistory() async {
    await _db.clearReadings();
    if (!mounted) return;
    setState(() => _history.clear());
  }

  /// Mulai ulang hitung mundur ke pembacaan berikutnya.
  void _restartCountdown() {
    _countdownTimer?.cancel();
    _untilNext = Duration(minutes: _intervalMinutes);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final next = _untilNext - const Duration(seconds: 1);
        _untilNext = next.isNegative ? Duration.zero : next;
      });
    });
  }

  /// Aktifkan sensor sebentar untuk mengambil satu pembacaan valid lalu matikan
  /// kembali (hemat baterai). Pembacaan dianggap valid bila bpm > 0 dan
  /// akurasinya minimal "rendah". Pembacaan valid langsung disimpan ke SQLite.
  Future<void> _takeReading() async {
    if (_sampling) return; // siklus sebelumnya belum selesai
    setState(() {
      _sampling = true;
      _error = null;
    });

    final completer = Completer<HeartRateReading?>();
    Timer? timeout;

    _sampleSubscription = _channel.receiveBroadcastStream().listen(
      (event) {
        final data = (event as Map).cast<String, dynamic>();
        final bpm = (data['bpm'] as num?)?.toDouble() ?? 0;
        final accuracy = (data['accuracy'] as num?)?.toInt() ?? 0;
        debugPrint('[HR] event bpm=$bpm accuracy=$accuracy');
        // Tampilkan nilai sementara agar user tahu sensor sedang bekerja.
        if (mounted) {
          setState(() {
            _bpm = bpm > 0 ? bpm : _bpm;
            _accuracy = accuracy;
          });
        }
        if (bpm > 0 && accuracy >= 1 && !completer.isCompleted) {
          completer.complete(
            HeartRateReading(
              bpm: bpm,
              accuracy: accuracy,
              time: DateTime.now(),
            ),
          );
        }
      },
      onError: (Object err) {
        debugPrint('[HR] error stream: $err');
        if (!completer.isCompleted) {
          final message = err is PlatformException
              ? (err.message ?? 'Gagal membaca sensor')
              : err.toString();
          completer.complete(null);
          if (mounted) setState(() => _error = message);
        }
      },
    );

    timeout = Timer(_sampleTimeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    final reading = await completer.future;

    timeout.cancel();
    await _sampleSubscription?.cancel();
    _sampleSubscription = null;

    // Simpan pembacaan valid ke database, lalu pakai objek hasil simpan
    // (yang sudah memiliki id) untuk ditampilkan di riwayat.
    HeartRateReading? saved;
    if (reading != null) {
      saved = await _db.insertReading(reading);
    }

    if (!mounted) return;
    setState(() {
      _sampling = false;
      if (saved != null) {
        _bpm = saved.bpm;
        _accuracy = saved.accuracy;
        _history.insert(0, saved);
      }
    });

    // Setiap selesai satu pembacaan, mulai ulang hitung mundur.
    if (_running) _restartCountdown();
  }

  String get _accuracyLabel {
    switch (_accuracy) {
      case 3:
        return 'Akurasi tinggi';
      case 2:
        return 'Akurasi sedang';
      case 1:
        return 'Akurasi rendah';
      default:
        return 'Mengukur…';
    }
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
    final Widget child;
    if (_running) {
      child = _buildRunning();
    } else {
      child = _buildSetup();
    }
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
                    : 'Pilih interval pembacaan detak jantung.',
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
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _permanentlyDenied ? openAppSettings : _requestAndStart,
            child: Text(
              _permanentlyDenied ? 'Buka Pengaturan' : 'Izinkan & Mulai',
            ),
          ),
          // Saat ditolak biasa, beri jalan pintas ke Pengaturan juga.
          if (_denied) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Buka Pengaturan'),
            ),
          ],
          // Riwayat tersimpan tetap bisa dilihat sebelum mode interval dimulai.
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildHistory(),
          ],
        ],
      ),
    );
  }

  /// Layar saat mode interval berjalan.
  Widget _buildRunning() {
    final hasReading = _bpm != null && _bpm! > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseController,
            child: Icon(
              Icons.favorite,
              color: _sampling ? Colors.redAccent : Colors.red[300],
              size: 40,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasReading ? _bpm!.toStringAsFixed(0) : '--',
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
                (_sampling
                    ? (hasReading ? _accuracyLabel : 'Mengukur…')
                    : 'Pembacaan berikutnya dalam ${_formatCountdown(_untilNext)}'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: _error != null ? Colors.amber : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Interval: $_intervalMinutes menit',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
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
            // Tombol hapus seluruh riwayat dari database.
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
                Text(
                  _formatTime(r.time),
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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

/// Pemilih interval (1 / 3 / 5 menit) berbentuk chip.
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
