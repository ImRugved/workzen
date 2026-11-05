import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_snackbar.dart';
import '../models/employee_of_month_model.dart';
import '../providers/company_info_provider.dart';

// Employee of the month on the Info pages and its own screen.
//
// - [EmployeeOfMonthCard]: the card of one month (picture, name, designation,
//   month, why they were chosen).
// - [EmployeeOfMonthTile]: the card on the admin screen; swiping it left
//   switches it on or off (nothing is deleted).
// - [EmployeeOfMonthSummaryCard]: the small card on the admin Info page.
// - [EmployeeOfMonthSection]: the card on the employee Info page.
//
// A month's choice is shown to everyone only during its own month and while it
// is switched on; earlier months are history on the admin screen.

/// Round picture of an employee, or their initial when there is none, inside a
/// soft ring.
class EmployeeAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  const EmployeeAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ConstColors.primary, width: 2),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: ConstColors.lightShade,
        backgroundImage: url == null ? null : CachedNetworkImageProvider(url),
        child: url == null
            ? Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: getTextTheme().titleLarge?.copyWith(
                  color: ConstColors.primaryDeep,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );
  }
}

/// "OCTOBER 2026" pill.
class _MonthPill extends StatelessWidget {
  final EmployeeOfMonthModel record;

  const _MonthPill({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: ConstColors.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        DateFormat('MMMM yyyy').format(record.monthDate).toUpperCase(),
        style: getTextTheme().labelSmall?.copyWith(
          color: ConstColors.primaryDeep,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// "Active" / "Inactive" / "Ended" tag.
class _StatusTag extends StatelessWidget {
  final EmployeeOfMonthStatus status;

  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EmployeeOfMonthStatus.active => ('Active', ConstColors.successGreen),
      EmployeeOfMonthStatus.inactive => ('Inactive', ConstColors.textColorLight),
      EmployeeOfMonthStatus.expired => ('Ended', ConstColors.inProgressOrange),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        label,
        style: getTextTheme().labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// The card of one month: the employee's picture in a ring, the month, their
/// name and designation, and why they were chosen. [showStatus] adds the
/// Active / Inactive / Ended tag (admin screen).
class EmployeeOfMonthCard extends StatelessWidget {
  final EmployeeOfMonthModel record;
  final bool showStatus;

  const EmployeeOfMonthCard({
    super.key,
    required this.record,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = record.statusAt(DateTime.now());
    final dimmed = showStatus && status != EmployeeOfMonthStatus.active;

    return Opacity(
      opacity: dimmed ? 0.7 : 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ConstColors.primary.withValues(alpha: 0.30),
              ConstColors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: ConstColors.borderColor),
          boxShadow: NeuStyle.raised().boxShadow,
        ),
        child: Stack(
          children: [
            // Trophy in the corner
            Positioned(
              right: 12.w,
              top: 10.h,
              child: Icon(
                Icons.emoji_events,
                size: 26.r,
                color: ConstColors.primaryDeep.withValues(alpha: 0.55),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      EmployeeAvatar(
                        name: record.name,
                        imageUrl: record.profileImageUrl,
                        radius: 32.r,
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6.w,
                              runSpacing: 4.h,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _MonthPill(record: record),
                                if (showStatus) _StatusTag(status: status),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Padding(
                              // Keeps the name clear of the trophy
                              padding: EdgeInsets.only(right: 26.w),
                              child: Text(
                                record.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: getTextTheme().titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: ConstColors.textColor,
                                ),
                              ),
                            ),
                            if (record.designation.isNotEmpty)
                              Text(
                                record.designation,
                                style: getTextTheme().bodySmall?.copyWith(
                                  color: ConstColors.textColorLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (record.note != null) ...[
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: ConstColors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '"${record.note}"',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: getTextTheme().bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: ConstColors.textColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card on the admin screen. An editor swipes it left to switch it off (or
/// on again); it never leaves the list. A month that is over cannot be changed.
class EmployeeOfMonthTile extends StatelessWidget {
  final EmployeeOfMonthModel record;
  final bool canEdit;

  const EmployeeOfMonthTile({
    super.key,
    required this.record,
    required this.canEdit,
  });

  Future<void> _toggle(BuildContext context, bool makeActive) async {
    final saved = await context
        .read<CompanyInfoProvider>()
        .setEmployeeOfMonthActive(record.month, makeActive);
    if (!saved) ConstantSnackbar.showError(title: 'Failed to change');
  }

  @override
  Widget build(BuildContext context) {
    final status = record.statusAt(DateTime.now());
    final card = EmployeeOfMonthCard(record: record, showStatus: true);

    final swipeable =
        canEdit && status != EmployeeOfMonthStatus.expired;
    if (!swipeable) {
      return Padding(padding: EdgeInsets.symmetric(vertical: 6.h), child: card);
    }

    final makeActive = status == EmployeeOfMonthStatus.inactive;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Dismissible(
        key: ValueKey('eom_${record.month}'),
        direction: DismissDirection.endToStart,
        // The card is switched on or off but never removed: the swipe does not
        // complete, the list redraws from the saved change
        confirmDismiss: (_) async {
          await _toggle(context, makeActive);
          return false;
        },
        background: const SizedBox.shrink(),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                makeActive
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20.r,
                color: makeActive
                    ? ConstColors.successGreen
                    : ConstColors.errorRed,
              ),
              SizedBox(width: 6.w),
              Text(
                makeActive ? 'Make active' : 'Make inactive',
                style: getTextTheme().labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: makeActive
                      ? ConstColors.successGreen
                      : ConstColors.errorRed,
                ),
              ),
            ],
          ),
        ),
        child: card,
      ),
    );
  }
}

/// Admin Info page: who is employee of the month right now, in one tappable
/// card (picture, name, designation, month). Tapping opens [onTap], the
/// Employee of the Month screen with every month.
class EmployeeOfMonthSummaryCard extends StatelessWidget {
  final VoidCallback onTap;

  const EmployeeOfMonthSummaryCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Consumer<CompanyInfoProvider>(
          builder: (context, info, _) {
            final now = DateTime.now();
            final current = info.months
                .where((m) => m.isShownAt(now))
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: ConstColors.primary,
                      size: 22.r,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Employee of the Month',
                        style: getTextTheme().titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: ConstColors.textColorLight,
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                if (!info.monthsLoaded)
                  Text(
                    'Loading...',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  )
                else if (current.isEmpty)
                  Text(
                    info.months.isEmpty
                        ? 'Not chosen yet. Tap to choose.'
                        : 'No employee of the month right now. Tap to choose.',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Row(
                    children: [
                      EmployeeAvatar(
                        name: current.first.name,
                        imageUrl: current.first.profileImageUrl,
                        radius: 24.r,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              current.first.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: getTextTheme().titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: ConstColors.textColor,
                              ),
                            ),
                            if (current.first.designation.isNotEmpty)
                              Text(
                                current.first.designation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: getTextTheme().bodySmall?.copyWith(
                                  color: ConstColors.textColorLight,
                                ),
                              ),
                            SizedBox(height: 4.h),
                            _MonthPill(record: current.first),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Employee Info page: the employee of the month of this month, or nothing
/// when none is chosen or it was switched off.
class EmployeeOfMonthSection extends StatelessWidget {
  const EmployeeOfMonthSection({super.key});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Consumer<CompanyInfoProvider>(
          builder: (context, info, _) {
            final now = DateTime.now();
            final current = info.months
                .where((m) => m.isShownAt(now))
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: ConstColors.primary,
                      size: 22.r,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Employee of the Month',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                if (!info.monthsLoaded)
                  Text(
                    'Loading...',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  )
                else if (current.isEmpty)
                  Text(
                    'Not chosen yet for this month',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  EmployeeOfMonthCard(record: current.first),
              ],
            );
          },
        ),
      ),
    );
  }
}
