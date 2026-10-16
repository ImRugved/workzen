import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import 'app_donut_chart.dart';

/// One row of a [DonutStatCard]: a name, its count and its colour.
class DonutStatItem {
  final String label;
  final int value;
  final Color color;

  const DonutStatItem(this.label, this.value, this.color);
}

/// White card with the app's donut chart on the left (the total in the centre)
/// and one tinted row per item on the right. Used for the admin overviews
/// (onboarding, pending leave types, leave requests). The ring grows in when
/// the card first appears.
class DonutStatCard extends StatelessWidget {
  final List<DonutStatItem> items;
  final String centerLabel;

  const DonutStatCard({
    super.key,
    required this.items,
    this.centerLabel = 'Total',
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, item) => sum + item.value);

    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => AppDonutChart(
                size: 112.r,
                strokeWidth: 22.r,
                gap: 1.r,
                cornerRadius: 4.r,
                progress: progress,
                segments: [
                  for (final item in items)
                    if (item.value > 0)
                      AppDonutSegment(item.value.toDouble(), item.color),
                ],
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: getTextTheme().headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.textColor,
                      ),
                    ),
                    Text(
                      centerLabel,
                      style: getTextTheme().labelSmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // All rows share the width of the widest one, so their edges line up
            Flexible(
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items) ...[
                      _row(item),
                      if (item != items.last) SizedBox(height: 6.h),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(DonutStatItem item) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Container(
            width: 14.r,
            height: 14.r,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColor,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Text(
            '${item.value}',
            style: getTextTheme().labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: ConstColors.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
