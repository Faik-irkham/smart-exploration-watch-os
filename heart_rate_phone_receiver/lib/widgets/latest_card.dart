import 'package:flutter/material.dart';

import '../models/heart_rate_reading.dart';
import '../utils/date_format.dart';

/// Kartu besar yang menonjolkan pembacaan BPM terbaru.
class LatestCard extends StatelessWidget {
  const LatestCard({super.key, required this.latest});

  final HeartRateReading? latest;

  @override
  Widget build(BuildContext context) {
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
            latest != null ? latest!.bpm.toStringAsFixed(0) : '--',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const Text(
            'BPM',
            style: TextStyle(letterSpacing: 3, color: Colors.white70),
          ),
          if (latest != null) ...[
            const SizedBox(height: 4),
            Text(
              formatDateTime(latest!.time),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            if (latest!.accelMagnitudeStd != null)
              Text(
                'Gerak σ ${latest!.accelMagnitudeStd!.toStringAsFixed(2)} '
                'm/s² • ${latest!.accelSampleCount} sampel',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ],
      ),
    );
  }
}
