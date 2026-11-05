import 'announcement_model.dart';
import 'birthday_model.dart';
import 'employee_of_month_model.dart';
import 'newsletter_model.dart';

/// What a card on the Notifications screen is about.
enum NotificationFeedType {
  birthday,
  employeeOfMonth,
  announcement,
  newsletter,
}

/// One card on the Notifications screen: today's birthdays, an employee of the
/// month, or an announcement. It is [isActive] while it is current and expired
/// once its time is over; expired cards stay in the list.
class NotificationFeedItem {
  /// Stable key, used to remember that the user has seen it.
  final String id;
  final NotificationFeedType type;
  final bool isActive;

  /// Orders the list (newest first).
  final DateTime time;

  /// The user who made it (not news to them), or null.
  final String? createdById;

  final List<BirthdayModel>? birthdays;
  final EmployeeOfMonthModel? employeeOfMonth;
  final AnnouncementModel? announcement;
  final NewsletterModel? newsletter;

  const NotificationFeedItem({
    required this.id,
    required this.type,
    required this.isActive,
    required this.time,
    this.createdById,
    this.birthdays,
    this.employeeOfMonth,
    this.announcement,
    this.newsletter,
  });
}
