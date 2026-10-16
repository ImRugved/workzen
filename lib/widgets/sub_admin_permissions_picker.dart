import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/permissions.dart';

/// Checklist an admin uses to choose what a sub admin may access.
class SubAdminPermissionsPicker extends StatelessWidget {
  final Set<String> selected;
  final void Function(String permission, bool granted) onChanged;
  final void Function(bool all) onSelectAll;

  const SubAdminPermissionsPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.length == Permissions.all.length;

    // A Material (not a coloured DecoratedBox) so the list tiles can paint
    // their ink and background on it
    return Material(
      color: ConstColors.lightShade,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: const BorderSide(color: ConstColors.borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sub admin access',
                      style: getTextTheme().titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.primaryDeep,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onSelectAll(!allSelected),
                    child: Text(allSelected ? 'Clear all' : 'Select all'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                'The sub admin only sees the screens and settings you tick.',
                style: getTextTheme().bodySmall?.copyWith(
                  color: ConstColors.textColorLight,
                ),
              ),
            ),
            ...Permissions.labels.entries.map(
              (entry) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: ConstColors.primary,
                title: Text(entry.value, style: getTextTheme().bodyMedium),
                value: selected.contains(entry.key),
                onChanged: (value) => onChanged(entry.key, value ?? false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
