import 'package:flutter/material.dart';

import '../ble_receiver.dart';

/// Kartu status koneksi penerima (idle/scan/connect/terhubung/error).
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.status, required this.message});

  final ReceiverStatus status;
  final String? message;

  @override
  Widget build(BuildContext context) {
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
      ReceiverStatus.error => (Icons.error_outline, Colors.redAccent, 'Error'),
      ReceiverStatus.idle => (Icons.bluetooth, Colors.grey, 'Belum terhubung'),
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
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
                if (message != null)
                  Text(
                    message!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
