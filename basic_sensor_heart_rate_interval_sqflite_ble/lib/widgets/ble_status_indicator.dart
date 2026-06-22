import 'package:flutter/material.dart';

import '../ble_peripheral.dart';

/// Indikator status koneksi BLE ke smartphone.
class BleStatusIndicator extends StatelessWidget {
  const BleStatusIndicator({
    super.key,
    required this.status,
    required this.message,
  });

  final BleStatus status;
  final String? message;

  @override
  Widget build(BuildContext context) {
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
        label = message ?? 'BLE error';
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
}
