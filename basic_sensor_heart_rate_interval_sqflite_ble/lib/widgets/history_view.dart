import 'package:flutter/material.dart';

import '../models/heart_rate_reading.dart';

/// Daftar ringkas riwayat detak jantung (maksimal 6 pembacaan terakhir agar
/// muat di layar jam) lengkap dengan tombol hapus.
class HistoryView extends StatelessWidget {
  const HistoryView({
    super.key,
    required this.history,
    required this.onClear,
  });

  final List<HeartRateReading> history;
  final VoidCallback onClear;

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Riwayat (${history.length})',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
            InkWell(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, size: 14, color: Colors.grey[400]),
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
        ...history.take(6).map(
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
