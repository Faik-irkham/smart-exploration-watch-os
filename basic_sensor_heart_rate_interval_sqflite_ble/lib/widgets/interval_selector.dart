import 'package:flutter/material.dart';

/// Pemilih interval (mis. 3 / 5 menit) berbentuk chip.
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
      children: intervals.map((minutes) {
        return ChoiceChip(
          label: Text('$minutes menit'),
          selected: minutes == selected,
          onSelected: (_) => onChanged(minutes),
        );
      }).toList(),
    );
  }
}
