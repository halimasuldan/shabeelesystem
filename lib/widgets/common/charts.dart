import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A single data point used by the chart widgets.
class ChartSlice {
  const ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// Ring chart (donut) with an optional value displayed in the middle.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 148,
    this.strokeWidth = 18,
    this.centerValue,
    this.centerLabel,
  });

  final List<ChartSlice> slices;
  final double size;
  final double strokeWidth;
  final String? centerValue;
  final String? centerLabel;

  double get _total => slices.fold<double>(
    0,
    (sum, slice) =>
        sum + (slice.value.isFinite && slice.value > 0 ? slice.value : 0),
  );

  @override
  Widget build(BuildContext context) {
    final total = _total;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              slices: slices,
              total: total,
              strokeWidth: strokeWidth,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(strokeWidth + 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerValue ?? total.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (centerLabel != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      centerLabel!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.strokeWidth,
  });

  final List<ChartSlice> slices;
  final double total;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.divider.withValues(alpha: 0.55);
    canvas.drawCircle(center, radius, background);

    if (total <= 0) return;

    final hasSegments = slices.length > 1;
    // Small gap between segments so the ring stays easy to read.
    const gap = 0.035;
    var startAngle = -math.pi / 2;

    for (final slice in slices) {
      if (!slice.value.isFinite || slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = slice.color;
      final drawSweep = hasSegments ? math.max(sweep - gap, 0.01) : sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (hasSegments ? gap / 2 : 0),
        drawSweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.slices.length != slices.length ||
      !_sameValues(oldDelegate.slices, slices);

  bool _sameValues(List<ChartSlice> a, List<ChartSlice> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value || a[i].color != b[i].color) return false;
    }
    return true;
  }
}

/// Colour key that explains the segments of a [DonutChart].
class ChartLegend extends StatelessWidget {
  const ChartLegend({
    super.key,
    required this.slices,
    this.showPercentage = true,
  });

  final List<ChartSlice> slices;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(
      0,
      (sum, slice) =>
          sum + (slice.value.isFinite && slice.value > 0 ? slice.value : 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: slices.map((slice) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: slice.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                showPercentage && total > 0
                    ? '${(slice.value / total * 100).toStringAsFixed(0)}%'
                    : slice.value.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 34,
                child: Text(
                  slice.value.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Horizontal ranked bars – ideal for per class / per exam comparisons.
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.slices,
    this.barHeight = 10,
    this.valueSuffix = '',
    this.emptyMessage = 'No data available for this period.',
  });

  final List<ChartSlice> slices;
  final double barHeight;
  final String valueSuffix;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return Text(
        emptyMessage,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      );
    }

    final maxValue = slices
        .map((slice) => slice.value.isFinite ? slice.value : 0.0)
        .reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: slices.map((slice) {
        final fraction = maxValue <= 0 ? 0.0 : (slice.value / maxValue);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${slice.value.toStringAsFixed(slice.value % 1 == 0 ? 0 : 1)}$valueSuffix',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: slice.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: AppColors.divider.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(barHeight / 2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction.clamp(0.0, 1.0),
                                    child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          slice.color,
                          slice.color.withValues(alpha: 0.65),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}






