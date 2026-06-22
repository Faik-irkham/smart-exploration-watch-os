import 'dart:async';

import 'package:flutter/material.dart';

import 'ble_receiver.dart';
import 'heart_rate_database.dart';

void main() {
  runApp(const ReceiverApp());
}

class ReceiverApp extends StatelessWidget {
  const ReceiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HR Receiver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101012),
      ),
      home: const ReceiverPage(),
    );
  }
}

class ReceiverPage extends StatefulWidget {
  const ReceiverPage({super.key});

  @override
  State<ReceiverPage> createState() => _ReceiverPageState();
}

class _ReceiverPageState extends State<ReceiverPage> {
  final _ble = BleReceiver.instance;
  final _db = HeartRateDatabase.instance;

  final List<HeartRateReading> _history = [];
  StreamSubscription<HeartRateReading>? _readingSub;

  @override
  void initState() {
    super.initState();
    _ble.status.addListener(_onChanged);
    _ble.message.addListener(_onChanged);
    // Setiap record baru dari watch: masukkan ke daftar paling atas.
    _readingSub = _ble.onReading.listen((reading) {
      if (!mounted) return;
      setState(() => _history.insert(0, reading));
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _ble.status.removeListener(_onChanged);
    _ble.message.removeListener(_onChanged);
    _readingSub?.cancel();
    _ble.stop();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Muat record yang sudah pernah diterima & disimpan sebelumnya.
  Future<void> _loadHistory() async {
    final readings = await _db.getReadings();
    if (!mounted) return;
    setState(() {
      _history
        ..clear()
        ..addAll(readings);
    });
  }

  Future<void> _clearHistory() async {
    await _db.clearReadings();
    if (!mounted) return;
    setState(() => _history.clear());
  }

  String _formatDateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _ble.status.value;
    final isActive = status == ReceiverStatus.scanning ||
        status == ReceiverStatus.connecting ||
        status == ReceiverStatus.connected;
    final latest = _history.isNotEmpty ? _history.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penerima Detak Jantung'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              tooltip: 'Hapus riwayat',
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(status),
            _buildLatest(latest),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Riwayat tersimpan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: _buildHistoryList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isActive ? _ble.stop : _ble.start,
        icon: Icon(
            isActive ? Icons.bluetooth_disabled : Icons.bluetooth_searching),
        label: Text(isActive ? 'Putuskan' : 'Hubungkan watch'),
      ),
    );
  }

  Widget _buildStatusCard(ReceiverStatus status) {
    final (IconData icon, Color color, String label) = switch (status) {
      ReceiverStatus.connected => (
          Icons.bluetooth_connected,
          Colors.lightBlueAccent,
          'Terhubung'
        ),
      ReceiverStatus.connecting => (
          Icons.bluetooth_searching,
          Colors.amber,
          'Menghubungkan…'
        ),
      ReceiverStatus.scanning => (
          Icons.bluetooth_searching,
          Colors.amber,
          'Mencari watch…'
        ),
      ReceiverStatus.error => (
          Icons.error_outline,
          Colors.redAccent,
          'Error'
        ),
      ReceiverStatus.idle => (
          Icons.bluetooth,
          Colors.grey,
          'Belum terhubung'
        ),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold)),
                if (_ble.message.value != null)
                  Text(
                    _ble.message.value!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatest(HeartRateReading? latest) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.red.shade900, Colors.red.shade700],
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            latest != null ? latest.bpm.toStringAsFixed(0) : '--',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const Text('BPM',
              style: TextStyle(letterSpacing: 3, color: Colors.white70)),
          if (latest != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatDateTime(latest.time),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data.\nTekan "Hubungkan watch" untuk mulai menerima.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return ListView.separated(
      itemCount: _history.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _history[i];
        return ListTile(
          dense: true,
          leading:
              const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
          title: Text('${r.bpm.toStringAsFixed(0)} BPM'),
          subtitle: Text('Akurasi ${r.accuracy} • ${_formatDateTime(r.time)}'),
        );
      },
    );
  }
}
