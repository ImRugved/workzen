import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants/constant_colors.dart';
import '../providers/notification_feed_provider.dart';

/// The bell in the home screens' app bar. A red badge with a number shows how
/// many new things there are (a new announcement, employee of the month or
/// birthday); opening the Notifications screen clears it.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    // Only the number matters here, so the bell rebuilds only when it changes
    final count = context.select<NotificationFeedProvider, int>(
      (feed) => feed.unreadCount,
    );

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Get.toNamed('/notifications_screen'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 9 ? '9+' : '$count'),
        backgroundColor: ConstColors.errorRed,
        textColor: ConstColors.white,
        child: Icon(Icons.notifications_outlined, size: 26.r),
      ),
    );
  }
}
