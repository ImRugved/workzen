import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../providers/company_info_provider.dart';
import '../providers/organization_provider.dart';
import '../widgets/company_info_sections.dart';

/// The company rules in view mode, for everyone (opened from the Profile
/// screen): the company's name and office, then the rules as the admin wrote
/// them, with their formatting. Nothing can be edited here; the admin edits the
/// rules from the Info tab.
class CompanyRulesViewScreen extends StatefulWidget {
  const CompanyRulesViewScreen({super.key});

  @override
  State<CompanyRulesViewScreen> createState() =>
      _CompanyRulesViewScreenState();
}

class _CompanyRulesViewScreenState extends State<CompanyRulesViewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Already running after login; this restarts one that was dropped
      context.read<CompanyInfoProvider>().start();
      context.read<OrganizationProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Company Rules',
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
      ),
      backgroundColor: ConstColors.backgroundColor,
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          const _CompanyCard(),
          SizedBox(height: 16.h),
          // View only: no Add / Edit button
          const CompanyRulesSection(),
          SizedBox(height: 8.h),
          Consumer<CompanyInfoProvider>(
            builder: (context, info, _) {
              final updated = info.rules.updatedAt;
              if (updated == null) return const SizedBox.shrink();
              return Center(
                child: Text(
                  'Last updated ${DateFormat('dd MMM yyyy').format(updated)}',
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The company's name (the app's brand) with its logo, and the office name and
/// address the admin set under Office Location.
class _CompanyCard extends StatelessWidget {
  const _CompanyCard();

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
        child: Consumer<OrganizationProvider>(
          builder: (context, org, _) {
            final office = org.officeLocation;
            return Row(
              children: [
                Image.asset('assets/images/logo.png', width: 72.w),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEENIT',
                        style: getTextTheme().titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ConstColors.textColor,
                        ),
                      ),
                      if (office != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          office.name,
                          style: getTextTheme().bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (office.address != null)
                          Text(
                            office.address!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: getTextTheme().bodySmall?.copyWith(
                              color: ConstColors.textColorLight,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
