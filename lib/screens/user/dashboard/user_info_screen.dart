import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../models/leave_config_model.dart';
import '../../../models/office_hours_model.dart';
import '../../../providers/company_info_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/company_info_sections.dart';
import '../../../widgets/employee_of_month_widgets.dart';
import '../../../widgets/newsletter_widgets.dart';
import '../../../constants/const_textstyle.dart';
import '../../../constants/constant_button.dart';
import '../../../constants/constant_colors.dart';
import '../../../constants/app_theme.dart';

/// "Info" tab: the organization's yearly leave and office timings, a place for
/// the company rules, and a button to the employee directory page.
class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Live leave counts and office hours set by the admin
      context.read<OrganizationProvider>().start();
      // Announcements, employee of the month and company rules
      context.read<CompanyInfoProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      backgroundColor: ConstColors.backgroundColor,
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          // What the admin published (read-only here)
          const AnnouncementsSection(),
          SizedBox(height: 16.h),
          const EmployeeOfMonthSection(),
          SizedBox(height: 16.h),
          // Company news, latest posts; tapping opens all of them
          NewsletterSection(onTap: () => Get.toNamed('/newsletter_screen')),
          SizedBox(height: 16.h),
          const _OrganizationCard(),
          SizedBox(height: 16.h),
          const CompanyRulesSection(),
          SizedBox(height: 16.h),
          const _EmployeeDirectoryCard(),
        ],
      ),
    );
  }
}

/// Opens the employee directory page.
class _EmployeeDirectoryCard extends StatelessWidget {
  const _EmployeeDirectoryCard();

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outline, color: ConstColors.primary),
                SizedBox(width: 8.w),
                Text(
                  'Employee Directory',
                  style: getTextTheme().titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              'Find a colleague by name, ID, department or role.',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ConstantButton(
                text: 'Open Employee Directory',
                icon: Icon(
                  Icons.arrow_forward,
                  size: 20.r,
                  color: ConstColors.textColor,
                ),
                onPressed: () => Get.toNamed('/employee_directory_screen'),
                backgroundColor: ConstColors.primary,
                textColor: ConstColors.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yearly leave counts and office timings set by the admin.
class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard();

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Consumer<OrganizationProvider>(
          builder: (context, org, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heading(Icons.beach_access_outlined, 'Yearly Leave'),
              SizedBox(height: 10.h),
              _leaveRow(org.leaveConfigLoaded, org.leaveConfig),
              SizedBox(height: 16.h),
              _heading(Icons.access_time, 'Office Timings'),
              SizedBox(height: 10.h),
              _officeRows(context, org.officeHoursLoaded, org.officeHours),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: ConstColors.primary, size: 22.r),
        SizedBox(width: 8.w),
        Text(
          title,
          style: getTextTheme().titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _muted(String text) => Text(
    text,
    style: getTextTheme().bodySmall?.copyWith(
      color: ConstColors.textColorLight,
    ),
  );

  Widget _leaveRow(bool loaded, LeaveConfigModel? config) {
    if (!loaded) return _muted('Loading...');
    if (config == null) return _muted('Not set by the admin yet');

    final total =
        config.privilegeLeaves + config.sickLeaves + config.casualLeaves;
    return Row(
      children: [
        _stat('PL', config.privilegeLeaves, ConstColors.infoBlue),
        SizedBox(width: 8.w),
        _stat('SL', config.sickLeaves, ConstColors.successGreen),
        SizedBox(width: 8.w),
        _stat('CL', config.casualLeaves, ConstColors.inProgressOrange),
        SizedBox(width: 8.w),
        _stat('Total', total, ConstColors.primary),
      ],
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: getTextTheme().titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: getTextTheme().labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _officeRows(
    BuildContext context,
    bool loaded,
    OfficeHoursModel? hours,
  ) {
    if (!loaded) return _muted('Loading...');
    if (hours == null) return _muted('Not set by the admin yet');

    final lines = <MapEntry<String, String>>[
      MapEntry(
        'Working hours',
        '${hours.startTime.format(context)} - ${hours.endTime.format(context)}',
      ),
      if (hours.lateAfterMinutes != null)
        MapEntry(
          'Late after',
          '${hours.startPlus(hours.lateAfterMinutes!).format(context)} '
              '(${hours.lateAfterMinutes} min)',
        ),
      if (hours.halfDayAfterMinutes != null)
        MapEntry(
          'Half day after',
          '${hours.startPlus(hours.halfDayAfterMinutes!).format(context)} '
              '(${hours.halfDayAfterMinutes} min)',
        ),
    ];

    return Column(
      children: lines
          .map(
            (line) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    line.key,
                    style: getTextTheme().bodyMedium?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                  Text(
                    line.value,
                    style: getTextTheme().bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
