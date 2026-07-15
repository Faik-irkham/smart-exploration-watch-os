import 'package:flutter/material.dart';

/// Pemilih irama pengiriman (mis. 15 / 30 detik) berbentuk chip.
class IntervalSelector extends StatelessWidget {
  const IntervalSelector({
    super.key,
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
      children: intervals.map((seconds) {
        return ChoiceChip(
          label: Text('$seconds detik'),
          selected: seconds == selected,
          onSelected: (_) => onChanged(seconds),
        );
      }).toList(),
    );
  }
}
