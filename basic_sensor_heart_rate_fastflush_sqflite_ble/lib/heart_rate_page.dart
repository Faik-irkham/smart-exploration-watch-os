import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'monitoring/monitoring_cubit.dart';
import 'monitoring/monitoring_state.dart';
import 'widgets/ble_status_indicator.dart';
import 'widgets/history_view.dart';
import 'widgets/interval_selector.dart';

/// Halaman utama watch. Menyediakan [MonitoringCubit] lalu menampilkan
/// state-nya; seluruh logika ada di cubit, di sini hanya UI.
class HeartRatePage extends StatelessWidget {
  const HeartRatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MonitoringCubit(),
      child: const _HeartRateView(),
    );
  }
}

class _HeartRateView extends StatefulWidget {
  const _HeartRateView();

  @override
  State<_HeartRateView> createState() => _HeartRateViewState();
}

class _HeartRateViewState extends State<_HeartRateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.85,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatCountdown(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: BlocBuilder<MonitoringCubit, MonitoringState>(
            builder: (context, state) {
              final cubit = context.read<MonitoringCubit>();
              return state.running
                  ? _buildRunning(context, cubit, state)
                  : _buildSetup(context, cubit, state);
            },
          ),
        ),
      ),
    );
  }

  /// Ekspor data lalu tampilkan hasilnya di SnackBar.
  Future<void> _export(
    BuildContext context,
    MonitoringCubit cubit, {
    required bool csv,
  }) async {
    String message;
    try {
      final name = csv ? await cubit.exportCsv() : await cubit.exportDb();
      message = name != null
          ? 'Tersimpan: Download/$name'
          : 'Ekspor gagal (butuh Android 10+)';
    } catch (e) {
      message = 'Ekspor gagal: $e';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Dua tombol kecil untuk ekspor CSV / file .db ke Downloads.
  Widget _exportRow(BuildContext context, MonitoringCubit cubit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () => _export(context, cubit, csv: true),
          icon: const Icon(Icons.download, size: 14),
          label: const Text('CSV', style: TextStyle(fontSize: 11)),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: () => _export(context, cubit, csv: false),
          icon: const Icon(Icons.download, size: 14),
          label: const Text('DB', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  /// Layar awal: pilih interval lalu mulai (sekaligus pintu izin).
  Widget _buildSetup(
    BuildContext context,
    MonitoringCubit cubit,
    MonitoringState state,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border, color: Colors.redAccent, size: 36),
          const SizedBox(height: 8),
          Text(
            state.permanentlyDenied
                ? 'Izin sensor diblokir. Aktifkan di Pengaturan aplikasi.'
                : state.denied
                ? 'Izin sensor ditolak. Tekan lagi lalu pilih "Allow".'
                : 'Pilih interval pengiriman ke ponsel.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: (state.permanentlyDenied || state.denied)
                  ? Colors.amber
                  : null,
            ),
          ),
          if (state.lastStatusName != null) ...[
            const SizedBox(height: 4),
            Text(
              'status izin: ${state.lastStatusName}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
          const SizedBox(height: 12),
          IntervalSelector(
            intervals: MonitoringCubit.intervals,
            selected: state.flushSeconds,
            onChanged: cubit.changeInterval,
          ),
          const SizedBox(height: 8),
          Text(
            'HR disimpan tiap detik; accelerometer diringkas tiap detik; '
            'data dikirim tiap '
            '${state.flushSeconds} detik.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.permanentlyDenied
                ? openAppSettings
                : cubit.requestAndStart,
            child: Text(
              state.permanentlyDenied ? 'Buka Pengaturan' : 'Izinkan & Mulai',
            ),
          ),
          if (state.denied) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Buka Pengaturan'),
            ),
          ],
          if (state.history.isNotEmpty) ...[
            const SizedBox(height: 16),
            HistoryView(history: state.history, onClear: cubit.clearHistory),
            _exportRow(context, cubit),
          ],
        ],
      ),
    );
  }

  /// Layar saat mode pemantauan berjalan.
  Widget _buildRunning(
    BuildContext context,
    MonitoringCubit cubit,
    MonitoringState state,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseController,
            child: Icon(
              Icons.favorite,
              color: state.hasReading ? Colors.redAccent : Colors.red[300],
              size: 40,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.hasReading ? state.latestBpm.toStringAsFixed(0) : '--',
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const Text('BPM', style: TextStyle(fontSize: 13, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(
            state.error ??
                (state.flushing
                    ? 'Mengirim data ke ponsel…'
                    : 'Kirim berikutnya dalam ${_formatCountdown(state.untilSync)}'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: state.error != null ? Colors.amber : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Belum terkirim: ${state.unsentCount}  •  '
            'irama ${state.flushSeconds} dtk',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          BleStatusIndicator(
            status: state.bleStatus,
            message: state.bleMessage,
          ),
          const SizedBox(height: 10),
          if (state.history.isNotEmpty) ...[
            HistoryView(history: state.history, onClear: cubit.clearHistory),
            _exportRow(context, cubit),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: cubit.stop,
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Berhenti'),
          ),
        ],
      ),
    );
  }
}
