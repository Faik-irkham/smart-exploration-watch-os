import 'package:flutter/material.dart';

import '../models/heart_rate_reading.dart';
import '../utils/date_format.dart';

/// Daftar seluruh riwayat detak jantung yang tersimpan (terbaru di atas).
class HistoryList extends StatelessWidget {
  const HistoryList({super.key, required this.history});

  final List<HeartRateReading> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data.\nTekan "Hubungkan watch" untuk mulai menerima.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = history[i];
        return ListTile(
          dense: true,
          leading:
              const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
          title: Text('${r.bpm.toStringAsFixed(0)} BPM'),
          subtitle: Text('Akurasi ${r.accuracy} • ${formatDateTime(r.time)}'),
        );
      },
    );
  }
}
