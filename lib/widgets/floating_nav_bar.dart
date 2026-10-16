import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';

/// One tab of the [FloatingNavBar].
class NavBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// The dashboard's bottom navigation: a white pill that floats above the
/// bottom edge with a margin on the left, right and bottom, a fully round
/// border and a soft shadow. The selected tab grows into a tinted pill that
/// shows its label; the others show only their icon.
///
/// Use it as a Scaffold's bottomNavigationBar.
class FloatingNavBar extends StatelessWidget {
  final List<NavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10.w, 0.h, 10.w, 5.h),
        child: Container(
          height: 58.h,
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: ConstColors.cardBackground,
            borderRadius: BorderRadius.circular(40.r),
            border: Border.all(color: ConstColors.borderColor),
            boxShadow: NeuStyle.raised().boxShadow,
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  flex: i == currentIndex ? 2 : 1,
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          decoration: BoxDecoration(
            color: selected
                ? ConstColors.primary.withValues(alpha: 0.28)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 22.r,
                  color: selected
                      ? ConstColors.primaryDeep
                      : ConstColors.textColorLight,
                ),
                if (selected) ...[
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: getTextTheme().labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.textColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
