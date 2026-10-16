import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../models/leave_balance_model.dart';
import '../providers/request_provider.dart';
import 'app_donut_chart.dart';

/// Leave balance card: a header, a donut of the days left (one slice per leave
/// type, total in the centre) and a tinted row per type with its balance and
/// total. [animation] grows the ring when the dashboard loads.
class LeaveBalanceCard extends StatelessWidget {
  final LeaveBalanceModel model;
  final Animation<double> animation;
  final RequestProvider requests;

  const LeaveBalanceCard({
    super.key,
    required this.model,
    required this.animation,
    required this.requests,
  });

  String _count(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

  @override
  Widget build(BuildContext context) {
    final types = <_LeaveType>[
      _LeaveType(
        'PL',
        'Privilege',
        model.plUsed,
        model.plTotal,
        ConstColors.primary,
      ),
      _LeaveType(
        'SL',
        'Sick',
        model.slUsed,
        model.slTotal,
        ConstColors.successGreen,
      ),
      _LeaveType(
        'CL',
        'Casual',
        model.clUsed,
        model.clTotal,
        ConstColors.inProgressOrange,
      ),
      if (requests.compOffEarned > 0)
        _LeaveType(
          'CO',
          'Comp Off',
          requests.compOffUsed,
          requests.compOffEarned,
          ConstColors.calendarCompOff,
        ),
    ];

    final totalLeft = types.fold<num>(0, (sum, t) => sum + t.balance);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 10.h),
      // Same white raised surface as every other card
      decoration: NeuStyle.raised(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          //  SizedBox(height: 8.h),
          Row(
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) => AppDonutChart(
                  size: 122.r,
                  strokeWidth: 23.r,
                  gap: 1.r,
                  cornerRadius: 4.r,
                  progress: animation.value,
                  segments: [
                    for (final type in types)
                      if (type.balance > 0)
                        AppDonutSegment(type.balance.toDouble(), type.color),
                  ],
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _count(totalLeft),
                        style: getTextTheme().headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ConstColors.textColor,
                        ),
                      ),
                      Text(
                        'days left',
                        style: getTextTheme().labelSmall?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // All rows share the width of the widest one, so their edges line up
              IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final type in types) ...[
                      _typePill(type),
                      if (type != types.last) SizedBox(height: 6.h),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 36.r,
          height: 36.r,
          decoration: const BoxDecoration(
            color: ConstColors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.eco, size: 18.r, color: ConstColors.white),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave Balance',
                style: getTextTheme().titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
              Text(
                'Your time matters',
                style: getTextTheme().labelSmall?.copyWith(
                  color: ConstColors.textColorLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // A tinted row: solid colour dot, bold code, name, and balance / total in the
  // type's colour.
  Widget _typePill(_LeaveType type) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 15.r,
            height: 15.r,
            decoration: BoxDecoration(
              color: type.color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 5.w),
          Text(
            type.code,
            style: getTextTheme().labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: ConstColors.textColor,
            ),
          ),
          SizedBox(width: 5.w),
          Text(
            '${type.name} Leave',
            overflow: TextOverflow.ellipsis,
            style: getTextTheme().bodySmall?.copyWith(
              color: ConstColors.textColor,
            ),
          ),
          SizedBox(width: 15.w),
          Text(
            '${_count(type.balance)} / ${_count(type.total)}',
            style: getTextTheme().labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: type.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveType {
  final String code;
  final String name;
  final num used;
  final num total;
  final Color color;

  const _LeaveType(this.code, this.name, this.used, this.total, this.color);

  num get balance => total - used < 0 ? 0 : total - used;

  // The soft blue is too faint for text on a light tint, so PL text uses the
  // deeper blue; the other colours are readable as they are
  Color get textColor =>
      color == ConstColors.primary ? ConstColors.primaryDeep : color;
}
