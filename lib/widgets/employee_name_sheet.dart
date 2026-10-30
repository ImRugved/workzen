import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';

/// One line of the [EmployeeNameSheet]: a name and a short detail under it.
class EmployeeNameEntry {
  final String name;
  final String subtitle;

  const EmployeeNameEntry(this.name, [this.subtitle = '']);
}

/// Bottom sheet listing employees, for example the ones who are present today.
/// The title carries the colour of the group and its count.
class EmployeeNameSheet {
  EmployeeNameSheet._();

  static void show(
    BuildContext context, {
    required String title,
    required Color color,
    required List<EmployeeNameEntry> entries,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: ConstColors.borderColor,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Container(
                      width: 14.r,
                      height: 14.r,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '$title (${entries.length})',
                        style: getTextTheme().titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ConstColors.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                if (entries.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Center(
                      child: Text(
                        'No employees',
                        style: getTextTheme().bodyMedium?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: ConstColors.borderColor),
                      itemBuilder: (_, index) =>
                          _row(entries[index], color),
                    ),
                  ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _row(EmployeeNameEntry entry, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18.r,
            backgroundColor: color.withValues(alpha: 0.18),
            child: Text(
              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : 'E',
              style: getTextTheme().labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.textColor,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  overflow: TextOverflow.ellipsis,
                  style: getTextTheme().bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                if (entry.subtitle.isNotEmpty)
                  Text(
                    entry.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
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
