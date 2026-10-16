import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/constant_colors.dart';

/// One slice of an [AppDonutChart]: a value (any unit) and its colour.
class AppDonutSegment {
  final double value;
  final Color color;

  const AppDonutSegment(this.value, this.color);
}

/// The app's donut chart: a thick ring of slices with softly rounded corners,
/// a thin even gap between neighbours and a faint light-to-colour shade on each
/// slice. [center] sits in the middle (a number and label, for example).
///
/// All sizes are logical pixels, scaled with screenutil. [progress] (0 to 1)
/// grows the ring, for example from an AnimationController. When every value
/// is zero a plain grey ring in [emptyColor] is drawn so the chart never
/// disappears.
class AppDonutChart extends StatelessWidget {
  final List<AppDonutSegment> segments;
  final double size;

  /// Thickness of the ring.
  final double strokeWidth;

  /// Space between two slices.
  final double gap;

  /// Radius of each slice's four corners.
  final double cornerRadius;

  final double progress;
  final Widget? center;
  final Color emptyColor;

  const AppDonutChart({
    super.key,
    required this.segments,
    this.size = 124,
    this.strokeWidth = 26,
    this.gap = 3,
    this.cornerRadius = 5,
    this.progress = 1,
    this.center,
    this.emptyColor = ConstColors.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size.r),
            painter: _DonutPainter(
              segments: segments,
              progress: progress,
              strokeWidth: strokeWidth.r,
              gap: gap.r,
              cornerRadius: cornerRadius.r,
              emptyColor: emptyColor,
            ),
          ),
          ?center,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<AppDonutSegment> segments;
  final double progress;
  final double strokeWidth;
  final double gap;
  final double cornerRadius;
  final Color emptyColor;

  const _DonutPainter({
    required this.segments,
    required this.progress,
    required this.strokeWidth,
    required this.gap,
    required this.cornerRadius,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerPoint = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer - strokeWidth;
    if (inner <= 0) return;
    final mid = (outer + inner) / 2;

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) {
      // Nothing to show: a plain grey ring
      canvas.drawCircle(
        centerPoint,
        mid,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = emptyColor,
      );
      return;
    }

    // The slice is drawn smaller by the corner radius and then stroked with a
    // round join of twice that width, which rounds all four corners. The gap
    // and the corner inset are both turned into angles at the ring's middle.
    final c = cornerRadius;
    // The gap is an angle, so it fans out towards the outside; sizing it at the
    // outer edge keeps it from looking wide there
    final gapAngle = gap / mid;
    final cornerAngle = c / mid;
    final outerRect = Rect.fromCircle(center: centerPoint, radius: outer - c);
    final innerRect = Rect.fromCircle(center: centerPoint, radius: inner + c);

    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = segment.value / total * 2 * math.pi * progress;
      final from = start + gapAngle / 2 + cornerAngle;
      final span = sweep - gapAngle - 2 * cornerAngle;
      start += sweep;
      if (span <= 0) continue;

      final path = Path()
        ..arcTo(outerRect, from, span, true)
        ..arcTo(innerRect, from + span, -span, false)
        ..close();

      final light = Color.lerp(segment.color, Colors.white, 0.28)!;
      final shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, segment.color],
      ).createShader(Offset.zero & size);

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = shader,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * c
          ..strokeJoin = StrokeJoin.round
          ..shader = shader,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.gap != gap ||
      old.cornerRadius != cornerRadius ||
      old.emptyColor != emptyColor ||
      old.segments != segments;
}
