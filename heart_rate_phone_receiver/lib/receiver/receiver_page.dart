import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../widgets/history_list.dart';
import '../widgets/latest_card.dart';
import '../widgets/status_card.dart';
import 'receiver_cubit.dart';
import 'receiver_state.dart';

/// Halaman penerima. Menyediakan [ReceiverCubit] lalu menampilkan state-nya;
/// seluruh logika ada di cubit, di sini hanya UI.
class ReceiverPage extends StatelessWidget {
  const ReceiverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReceiverCubit(),
      child: const _ReceiverView(),
    );
  }
}

class _ReceiverView extends StatelessWidget {
  const _ReceiverView();

  /// Ekspor data lalu tampilkan hasilnya di SnackBar.
  Future<void> _export(
    BuildContext context,
    ReceiverCubit cubit, {
    required bool csv,
  }) async {
    final name = csv ? await cubit.exportCsv() : await cubit.exportDb();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          name != null
              ? 'Tersimpan: Download/$name'
              : 'Ekspor gagal (butuh Android 10+)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReceiverCubit, ReceiverState>(
      builder: (context, state) {
        final cubit = context.read<ReceiverCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Penerima Detak Jantung'),
            actions: [
              if (state.history.isNotEmpty) ...[
                PopupMenuButton<bool>(
                  tooltip: 'Ekspor ke Downloads',
                  icon: const Icon(Icons.download),
                  onSelected: (csv) => _export(context, cubit, csv: csv),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: true, child: Text('Export CSV')),
                    PopupMenuItem(value: false, child: Text('Export .db')),
                  ],
                ),
                IconButton(
                  tooltip: 'Hapus riwayat',
                  onPressed: cubit.clearHistory,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusCard(status: state.status, message: state.message),
                LatestCard(latest: state.latest),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Riwayat tersimpan (${state.history.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(child: HistoryList(history: state.history)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: state.isActive ? cubit.stop : cubit.start,
            icon: Icon(state.isActive
                ? Icons.bluetooth_disabled
                : Icons.bluetooth_searching),
            label: Text(state.isActive ? 'Putuskan' : 'Hubungkan watch'),
          ),
        );
      },
    );
  }
}
