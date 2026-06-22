import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const HeartRateApp());
}

class HeartRateApp extends StatelessWidget {
  const HeartRateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heart Rate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const HeartRatePage(),
    );
  }
}

class HeartRatePage extends StatefulWidget {
  const HeartRatePage({super.key});

  @override
  State<HeartRatePage> createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage>
    with SingleTickerProviderStateMixin {
  // Harus sama dengan nama channel di MainActivity.kt
  static const _channel = EventChannel('heart_rate/stream');

  StreamSubscription<dynamic>? _subscription;
  late final AnimationController _pulseController;

  double? _bpm;
  int _accuracy = 0;
  String? _error; // error sensor (bukan soal izin)
  bool _measuring = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.85,
      upperBound: 1.0,
    )..repeat(reverse: true);
    // Jika izin sudah diberikan sebelumnya, langsung mulai.
    _maybeAutoStart();
  }

  Future<void> _maybeAutoStart() async {
    if (await Permission.sensors.isGranted) {
      _startStream();
    }
  }

  /// Dipanggil dari tombol: minta izin BODY_SENSORS lalu mulai stream.
  Future<void> _requestAndStart() async {
    final status = await Permission.sensors.request();
    if (status.isGranted) {
      setState(() => _permanentlyDenied = false);
      _startStream();
    } else if (status.isPermanentlyDenied) {
      setState(() => _permanentlyDenied = true);
    } else {
      // Ditolak biasa — biarkan user bisa coba lagi lewat tombol.
      setState(() => _permanentlyDenied = false);
    }
  }

  void _startStream() {
    _subscription?.cancel();
    setState(() {
      _error = null;
      _measuring = true;
    });
    _subscription = _channel.receiveBroadcastStream().listen(
      (event) {
        final data = (event as Map).cast<String, dynamic>();
        setState(() {
          _bpm = (data['bpm'] as num?)?.toDouble();
          _accuracy = (data['accuracy'] as num?)?.toInt() ?? 0;
          _error = null;
        });
      },
      onError: (Object err) {
        setState(() {
          _error = err is PlatformException
              ? (err.message ?? 'Gagal membaca sensor')
              : err.toString();
          _measuring = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_error != null) {
      child = _buildError();
    } else if (_measuring) {
      child = _buildReading();
    } else {
      child = _buildPermissionGate();
    }
    return Scaffold(body: Center(child: child));
  }

  Widget _buildPermissionGate() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border, color: Colors.redAccent, size: 40),
          const SizedBox(height: 8),
          Text(
            _permanentlyDenied
                ? 'Izin sensor diblokir. Aktifkan di Pengaturan aplikasi.'
                : 'Butuh izin sensor tubuh untuk membaca detak jantung.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _permanentlyDenied ? openAppSettings : _requestAndStart,
            child: Text(
              _permanentlyDenied ? 'Buka Pengaturan' : 'Izinkan & Mulai',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _requestAndStart,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildReading() {
    final hasReading = _bpm != null && _bpm! > 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulseController,
          child: const Icon(Icons.favorite, color: Colors.redAccent, size: 48),
        ),
        const SizedBox(height: 8),
        Text(
          hasReading ? _bpm!.toStringAsFixed(0) : '--',
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
        const Text('BPM', style: TextStyle(fontSize: 14, letterSpacing: 2)),
        const SizedBox(height: 6),
        Text(
          hasReading ? _accuracyLabel : 'Menghubungkan sensor…',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
      ],
    );
  }
}
