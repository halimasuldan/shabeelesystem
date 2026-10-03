import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A simple custom bar chart built with Flutter primitives.
/// [data] maps labels to percentage values (0-100).
class SimpleBarChart extends StatelessWidget {
  final Map<String, double> data;
  final Color barColor;
  const SimpleBarChart({
    super.key,
    required this.data,
    this.barColor = AppColors.presentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: data.entries.map((entry) {
        final height = (entry.value.clamp(0, 100)) / 100 * 120;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('${entry.value.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 10)),
            const SizedBox(height: 4),
            Container(
              width: 24,
              height: height,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(entry.key, style: const TextStyle(fontSize: 10)),
          ],
        );
      }).toList(),
    );
  }
}
