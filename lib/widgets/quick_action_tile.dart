import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';

/// Small white tile for the dashboard's Quick Actions: a tinted icon box and
/// the full title beside it. Two sit side by side.
class QuickActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const QuickActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuStyle.radiusMedium.r),
      child: Ink(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: NeuStyle.raised(),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              decoration: BoxDecoration(
                color: ConstColors.lightShade,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 18.r, color: ConstColors.primaryDeep),
            ),
            SizedBox(width: 8.w),
            Expanded(
              // Wraps to a second line instead of cutting a long title short
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: getTextTheme().labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
