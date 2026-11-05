import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_colors.dart';
import '../../constants/permissions.dart';
import '../../models/announcement_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_info_provider.dart';
import '../../providers/value_provider.dart';
import '../../widgets/company_info_forms.dart';
import '../../widgets/company_info_sections.dart';

/// Every announcement, newest first: active, inactive (switched off by hand) and
/// expired (past their end time). A chip row filters by state and shows how
/// many there are of each. An admin, or a sub admin with the company info
/// permission, can post, switch on or off, and change the end time.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  // The chosen state filter, null for all (scoped state, no setState)
  final ValueProvider<AnnouncementStatus?> _filter =
      ValueProvider<AnnouncementStatus?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyInfoProvider>().start();
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  String _label(AnnouncementStatus? status) => switch (status) {
    null => 'All',
    AnnouncementStatus.active => 'Active',
    AnnouncementStatus.inactive => 'Inactive',
    AnnouncementStatus.expired => 'Expired',
  };

  @override
  Widget build(BuildContext context) {
    final canEdit = context.select<AuthProvider, bool>(
      (auth) => auth.can(Permissions.companyInfo),
    );

    return ChangeNotifierProvider.value(
      value: _filter,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Announcements',
            style: getTextTheme().titleLarge?.copyWith(
              color: ConstColors.textColor,
            ),
          ),
        ),
        backgroundColor: ConstColors.backgroundColor,
        floatingActionButton: canEdit
            ? FloatingActionButton.extended(
                onPressed: () => CompanyInfoForms.addAnnouncement(context),
                icon: Icon(
                  Icons.add,
                  size: 20.r,
                  color: ConstColors.textColor,
                ),
                label: Text(
                  'Post',
                  style: getTextTheme().labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                backgroundColor: ConstColors.primary,
                foregroundColor: ConstColors.textColor,
              )
            : null,
        body: Consumer2<CompanyInfoProvider, ValueProvider<AnnouncementStatus?>>(
          builder: (context, info, filter, _) {
            if (!info.announcementsLoaded) {
              return const Center(child: AppLoadingIndicator(size: 40));
            }

            final now = DateTime.now();
            int count(AnnouncementStatus? status) => status == null
                ? info.announcements.length
                : info.announcements.where((a) => a.statusAt(now) == status).length;

            final shown = filter.value == null
                ? info.announcements
                : info.announcements
                      .where((a) => a.statusAt(now) == filter.value)
                      .toList();

            return ListView(
              padding: AppSpacing.screen,
              children: [
                // State filter with a count on each chip
                Wrap(
                  spacing: 8.w,
                  children: [
                    for (final status in <AnnouncementStatus?>[
                      null,
                      AnnouncementStatus.active,
                      AnnouncementStatus.inactive,
                      AnnouncementStatus.expired,
                    ])
                      ChoiceChip(
                        label: Text('${_label(status)} (${count(status)})'),
                        selected: filter.value == status,
                        onSelected: (_) => filter.value = status,
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (shown.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Center(
                      child: Text(
                        info.announcements.isEmpty
                            ? 'No announcements yet'
                            : 'No ${_label(filter.value).toLowerCase()} announcements',
                        style: getTextTheme().bodyMedium?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                      ),
                    ),
                  )
                else
                  for (final item in shown)
                    AnnouncementTile(announcement: item, canEdit: canEdit),
                // Room so the Post button never covers the last card
                SizedBox(height: 70.h),
              ],
            );
          },
        ),
      ),
    );
  }
}
