import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/announcement_model.dart';
import '../models/birthday_model.dart';
import '../models/employee_of_month_model.dart';
import '../models/notification_feed_item.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'company_info_provider.dart';
import 'organization_provider.dart';

/// What the Notifications screen shows, and what the bell on the home screens
/// counts: today's birthdays, the employee of the month, the announcements and
/// the newsletter posts.
///
/// Everything comes from data that is already live (the announcements and
/// employee of the month in [CompanyInfoProvider], one small listener for
/// today's birthdays), so this adds almost no reads. Which cards the user has
/// already seen is remembered on the phone, per user. A card counts as new
/// until the Notifications screen has been opened while it was active; later
/// additions raise the number again. Expired cards stay in the list but never
/// count.
class NotificationFeedProvider with ChangeNotifier {
  final GetStorage _storage = GetStorage();

  CompanyInfoProvider? _info;
  OrganizationProvider? _org;
  String? _uid;

  StreamSubscription<List<BirthdayModel>>? _birthdaySub;
  List<BirthdayModel> _birthdays = [];
  // The day the birthday listener was made for (it is a query for one day)
  String? _birthdayDay;

  Set<String> _seen = {};

  static const int _keepSeen = 300;

  String get _storageKey => 'notifications_seen_$_uid';

  /// Called by the provider tree whenever the data it depends on changes.
  void update({
    required CompanyInfoProvider info,
    required AuthProvider auth,
    required OrganizationProvider org,
  }) {
    _info = info;
    _org = org;

    final uid = auth.user?.uid;
    if (uid != _uid) {
      _stopBirthdays();
      _uid = uid;
      _seen = uid == null ? {} : _readSeen();
    }

    if (uid != null) {
      _startBirthdays();
    }

    // Runs while the provider tree is updating, so notify afterwards
    Future.microtask(notifyListeners);
  }

  Set<String> _readSeen() {
    try {
      final stored = _storage.read<List<dynamic>>(_storageKey);
      return stored?.map((e) => e.toString()).toSet() ?? {};
    } catch (e) {
      logDebug('Could not read the seen notifications: $e');
      return {};
    }
  }

  void _startBirthdays() {
    final today = BirthdayModel.keyFor(DateTime.now());
    // A new day: the listener is asked for the new day's birthdays
    if (_birthdaySub != null && _birthdayDay != today) _stopBirthdays();
    if (_birthdaySub != null) return;

    final org = _org;
    if (org == null) return;
    _birthdayDay = today;
    _birthdaySub = org.todaysBirthdaysStream().listen(
      (list) {
        _birthdays = list;
        notifyListeners();
      },
      onError: (Object e) {
        logDebug('Birthdays listener stopped: $e');
        _stopBirthdays();
      },
    );
  }

  void _stopBirthdays() {
    _birthdaySub?.cancel();
    _birthdaySub = null;
    _birthdays = [];
    _birthdayDay = null;
  }

  /// Every card for the Notifications screen: current ones first, then expired
  /// ones, each newest first. An announcement or employee of the month the
  /// admin switched off is not listed.
  List<NotificationFeedItem> get items {
    final info = _info;
    final now = DateTime.now();
    final list = <NotificationFeedItem>[];

    if (_birthdays.isNotEmpty) {
      list.add(
        NotificationFeedItem(
          id:
              'birthday_${BirthdayModel.keyFor(now)}_'
              '${(_birthdays.map((b) => b.userId).toList()..sort()).join(',')}',
          type: NotificationFeedType.birthday,
          isActive: true,
          time: now,
          birthdays: _birthdays,
        ),
      );
    }

    if (info != null) {
      for (final month in info.months) {
        final status = month.statusAt(now);
        if (status == EmployeeOfMonthStatus.inactive) continue;
        list.add(
          NotificationFeedItem(
            id: 'eom_${month.month}_${month.userId}',
            type: NotificationFeedType.employeeOfMonth,
            isActive: status == EmployeeOfMonthStatus.active,
            time: month.monthDate,
            createdById: month.createdById,
            employeeOfMonth: month,
          ),
        );
      }

      // Newsletter posts do not expire: every post that is not hidden is current
      for (final post in info.newsletter) {
        if (!post.isActive) continue;
        list.add(
          NotificationFeedItem(
            id: 'newsletter_${post.id}',
            type: NotificationFeedType.newsletter,
            isActive: true,
            time: post.createdAt,
            createdById: post.createdById,
            newsletter: post,
          ),
        );
      }

      for (final announcement in info.announcements) {
        final status = announcement.statusAt(now);
        if (status == AnnouncementStatus.inactive) continue;
        list.add(
          NotificationFeedItem(
            id: 'announcement_${announcement.id}',
            type: NotificationFeedType.announcement,
            isActive: status == AnnouncementStatus.active,
            time: announcement.createdAt,
            createdById: announcement.createdById,
            announcement: announcement,
          ),
        );
      }
    }

    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.time.compareTo(a.time);
    });
    return list;
  }

  bool _isNew(NotificationFeedItem item) =>
      item.isActive &&
      !_seen.contains(item.id) &&
      // What the user made themselves is not news to them
      item.createdById != _uid;

  /// Ids of the current cards the user has not seen yet.
  Set<String> get newIds => items.where(_isNew).map((i) => i.id).toSet();

  /// The number on the red badge.
  int get unreadCount => items.where(_isNew).length;

  /// The user has opened the Notifications screen: everything current is read.
  void markAllSeen() {
    if (_uid == null) return;
    final unseen = items.where((i) => i.isActive).map((i) => i.id);
    final before = _seen.length;
    _seen.addAll(unseen);
    if (_seen.length == before) return;

    // Only the newest ids are kept, so the list never grows without limit
    final kept = _seen.toList();
    if (kept.length > _keepSeen) {
      _seen = kept.sublist(kept.length - _keepSeen).toSet();
    }
    _storage.write(_storageKey, _seen.toList());
    notifyListeners();
  }

  @override
  void dispose() {
    _birthdaySub?.cancel();
    super.dispose();
  }
}
