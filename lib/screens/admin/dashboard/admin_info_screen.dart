import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../constants/app_theme.dart';
import '../../../constants/constant_colors.dart';
import '../../../constants/permissions.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_info_provider.dart';
import '../../../widgets/company_info_sections.dart';
import '../../../widgets/employee_of_month_widgets.dart';
import '../../../widgets/newsletter_widgets.dart';

/// "Info" tab of the admin dashboard: what the admin publishes for everyone,
/// stored in organization_details and shown to the employees on their Info tab.
///
/// - Announcements: a summary card (how many are active, latest post, next end);
///   tapping it opens the Announcements screen with all of them.
/// - Employee of the month: one employee chosen for each month.
/// - Company rules: a numbered list.
///
/// An admin, or a sub admin with the "company info" permission, can add, edit
/// and delete; anyone else sees the same cards read-only.
class AdminInfoScreen extends StatefulWidget {
  const AdminInfoScreen({super.key});

  @override
  State<AdminInfoScreen> createState() => _AdminInfoScreenState();
}

class _AdminInfoScreenState extends State<AdminInfoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyInfoProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.select<AuthProvider, bool>(
      (auth) => auth.can(Permissions.companyInfo),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      backgroundColor: ConstColors.backgroundColor,
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          // A summary; tapping opens the screen with every announcement
          AnnouncementsSummaryCard(
            onTap: () => Get.toNamed('/announcements_screen'),
          ),
          SizedBox(height: 16.h),
          // Who it is this month; tapping opens every month
          EmployeeOfMonthSummaryCard(
            onTap: () => Get.toNamed('/employee_of_month_screen'),
          ),
          SizedBox(height: 16.h),
          // Company news (visits, milestones, achievements...); tapping opens
          // the newsletter, where posts are read, hidden and written
          NewsletterSummaryCard(
            onTap: () => Get.toNamed('/newsletter_screen'),
          ),
          SizedBox(height: 16.h),
          // The rules as written; Add / Edit opens the editor screen
          CompanyRulesSection(
            onEdit: canEdit ? () => Get.toNamed('/company_rules_screen') : null,
          ),
        ],
      ),
    );
  }
}
