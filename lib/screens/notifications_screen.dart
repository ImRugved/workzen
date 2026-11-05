import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../models/notification_feed_item.dart';
import '../providers/notification_feed_provider.dart';
import '../widgets/birthday_banner.dart';
import '../widgets/company_info_sections.dart';
import '../widgets/employee_of_month_widgets.dart';
import '../widgets/newsletter_widgets.dart';

/// Everything that was announced, for the admin and the employees alike, in
/// four tabs: Birthdays, Announcements, Employee of the Month and Newsletter.
/// Each tab
/// shows its current cards and keeps the expired ones in a collapsed
/// "Expired" group, so a long history never makes the page long. A red number
/// on a tab says how many cards in it are new, and the screen opens on the
/// first tab that has something new.
///
/// Opening this screen reads what is new, which clears the red badge on the
/// bell; the cards that were new are tagged "NEW" while it is open.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // What was new when the screen opened (kept so "NEW" stays visible after the
  // badge has been cleared)
  Set<String> _newIds = const {};

  // The tabs, in the order they are shown
  static const List<NotificationFeedType> _tabs = [
    NotificationFeedType.birthday,
    NotificationFeedType.announcement,
    NotificationFeedType.employeeOfMonth,
    NotificationFeedType.newsletter,
  ];

  late final int _initialTab;

  @override
  void initState() {
    super.initState();
    final feed = context.read<NotificationFeedProvider>();
    // Start on the first tab that has something new
    _newIds = feed.newIds;
    final items = feed.items;
    final firstNew = _tabs.indexWhere(
      (type) => items.any((i) => i.type == type && _newIds.contains(i.id)),
    );
    _initialTab = firstNew < 0 ? 0 : firstNew;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Seeing the screen is reading it
      context.read<NotificationFeedProvider>().markAllSeen();
    });
  }

  static (IconData, String) _tabInfo(NotificationFeedType type) =>
      switch (type) {
        NotificationFeedType.birthday => (Icons.cake_outlined, 'Birthdays'),
        NotificationFeedType.announcement => (
          Icons.campaign_outlined,
          'Announcements',
        ),
        NotificationFeedType.employeeOfMonth => (
          Icons.emoji_events_outlined,
          'Employee of the Month',
        ),
        NotificationFeedType.newsletter => (
          Icons.newspaper_outlined,
          'Newsletter',
        ),
      };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: _initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Notifications',
            style: getTextTheme().titleLarge?.copyWith(
              color: ConstColors.textColor,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48.h),
            child: Consumer<NotificationFeedProvider>(
              builder: (context, feed, _) {
                final items = feed.items;
                return TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  labelColor: ConstColors.textColor,
                  unselectedLabelColor: ConstColors.textColorLight,
                  indicatorColor: ConstColors.primaryDeep,
                  tabs: [
                    for (final type in _tabs)
                      Tab(
                        child: Badge(
                          // How many in this tab are new
                          isLabelVisible: _newCount(items, type) > 0,
                          label: Text('${_newCount(items, type)}'),
                          backgroundColor: ConstColors.errorRed,
                          textColor: ConstColors.white,
                          alignment: AlignmentDirectional.topEnd,
                          offset: const Offset(10, -6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_tabInfo(type).$1, size: 18.r),
                              SizedBox(width: 6.w),
                              Text(_tabInfo(type).$2),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        backgroundColor: ConstColors.backgroundColor,
        body: Consumer<NotificationFeedProvider>(
          builder: (context, feed, _) {
            final items = feed.items;
            return TabBarView(
              children: [
                for (final type in _tabs)
                  _TabPage(
                    type: type,
                    items: items.where((i) => i.type == type).toList(),
                    newIds: _newIds,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  int _newCount(List<NotificationFeedItem> items, NotificationFeedType type) =>
      items.where((i) => i.type == type && _newIds.contains(i.id)).length;
}

/// One tab: its current cards, then the expired ones folded away.
class _TabPage extends StatelessWidget {
  final NotificationFeedType type;
  final List<NotificationFeedItem> items;
  final Set<String> newIds;

  const _TabPage({
    required this.type,
    required this.items,
    required this.newIds,
  });

  String get _emptyText => switch (type) {
    NotificationFeedType.birthday => 'No birthdays today',
    NotificationFeedType.announcement => 'No announcements',
    NotificationFeedType.employeeOfMonth => 'No employee of the month yet',
    NotificationFeedType.newsletter => 'No company news yet',
  };

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Text(
            _emptyText,
            style: getTextTheme().bodyMedium?.copyWith(
              color: ConstColors.textColorLight,
            ),
          ),
        ),
      );
    }

    final current = items.where((i) => i.isActive).toList();
    final expired = items.where((i) => !i.isActive).toList();

    return ListView(
      padding: AppSpacing.screen,
      children: [
        for (final item in current) ...[
          _FeedEntry(item: item, isNew: newIds.contains(item.id)),
          SizedBox(height: 14.h),
        ],
        if (current.isEmpty && expired.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Text(
              'Nothing current right now',
              style: getTextTheme().bodySmall?.copyWith(
                color: ConstColors.textColorLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        // Past ones stay available, folded so they do not make the page long
        if (expired.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              initiallyExpanded: false,
              title: Text(
                'Expired (${expired.length})',
                style: getTextTheme().titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColorLight,
                ),
              ),
              children: [
                for (final item in expired) ...[
                  _FeedEntry(item: item, isNew: false),
                  SizedBox(height: 14.h),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One card, with a small "NEW" tag above it when it was new on opening.
class _FeedEntry extends StatelessWidget {
  final NotificationFeedItem item;
  final bool isNew;

  const _FeedEntry({required this.item, required this.isNew});

  @override
  Widget build(BuildContext context) {
    final card = switch (item.type) {
      NotificationFeedType.birthday => BirthdayCard(
        birthdays: item.birthdays ?? const [],
      ),
      NotificationFeedType.employeeOfMonth => EmployeeOfMonthCard(
        record: item.employeeOfMonth!,
        showStatus: true,
      ),
      // Read-only; the tag shows whether it is current or expired
      NotificationFeedType.announcement => AnnouncementTile(
        announcement: item.announcement!,
        canEdit: false,
        showStatus: true,
      ),
      // Read-only; posts do not expire
      NotificationFeedType.newsletter => NewsletterCard(
        post: item.newsletter!,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNew)
          Padding(
            padding: EdgeInsets.only(bottom: 6.h, left: 4.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: ConstColors.errorRed,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'NEW',
                style: getTextTheme().labelSmall?.copyWith(
                  color: ConstColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        card,
      ],
    );
  }
}
