import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../app_constants.dart';
import '../constants/firestore_constants.dart';
import '../models/achievement_model.dart';
import '../models/announcement_model.dart';
import '../models/company_rules_model.dart';
import '../models/employee_model.dart';
import '../models/employee_of_month_model.dart';
import '../models/newsletter_model.dart';
import '../services/fcm_service.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';

/// What the admin publishes on the Info page for everyone: announcements,
/// the employee of the month and the company rules. All of it lives in
/// organization_details.
///
/// One live listener each, started when someone first opens an Info tab and
/// stopped on logout, so an admin's change reaches every phone by itself.
/// The lists are bounded (20 announcements, 12 months), so the reads stay small.
class CompanyInfoProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _announcementLimit = 20;
  static const int _monthLimit = 12;
  static const int _newsletterLimit = 30;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _announcementsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _monthsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _newsletterSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rulesSub;

  List<AnnouncementModel> _announcements = [];
  List<EmployeeOfMonthModel> _months = [];
  List<NewsletterModel> _newsletter = [];
  CompanyRulesModel _rules = const CompanyRulesModel();

  bool _announcementsLoaded = false;
  bool _monthsLoaded = false;
  bool _newsletterLoaded = false;
  bool _rulesLoaded = false;

  bool _isSaving = false;

  List<AnnouncementModel> get announcements => _announcements;

  /// Employees of the month, latest month first.
  List<EmployeeOfMonthModel> get months => _months;

  /// Newsletter posts, newest first (hidden ones included).
  List<NewsletterModel> get newsletter => _newsletter;


  /// The company rules: one formatted document (empty until the admin writes it).
  CompanyRulesModel get rules => _rules;

  bool get announcementsLoaded => _announcementsLoaded;
  bool get monthsLoaded => _monthsLoaded;
  bool get newsletterLoaded => _newsletterLoaded;
  bool get rulesLoaded => _rulesLoaded;

  /// True while something is being saved or uploaded.
  bool get isSaving => _isSaving;

  DocumentReference<Map<String, dynamic>> get _announcementsDoc => _firestore
      .collection(FirestoreCollections.organizationDetails)
      .doc(FirestoreDocs.announcements);
  DocumentReference<Map<String, dynamic>> get _monthsDoc => _firestore
      .collection(FirestoreCollections.organizationDetails)
      .doc(FirestoreDocs.employeeOfMonth);
  DocumentReference<Map<String, dynamic>> get _rulesDoc => _firestore
      .collection(FirestoreCollections.organizationDetails)
      .doc(FirestoreDocs.companyRules);

  CollectionReference<Map<String, dynamic>> get _announcementItems =>
      _announcementsDoc.collection(FirestoreSubCollections.announcementItems);
  CollectionReference<Map<String, dynamic>> get _monthItems =>
      _monthsDoc.collection(FirestoreSubCollections.employeeOfMonthItems);
  CollectionReference<Map<String, dynamic>> get _newsletterItems => _firestore
      .collection(FirestoreCollections.organizationDetails)
      .doc(FirestoreDocs.newsletter)
      .collection(FirestoreSubCollections.newsletterItems);

  /// Starts the listeners. Safe to call repeatedly: each one subscribes once,
  /// and again only if it was dropped (for example after an error).
  void start() {
    _announcementsSub ??= _announcementItems
        .orderBy('createdAt', descending: true)
        .limit(_announcementLimit)
        .snapshots()
        .listen(
          (snapshot) {
            _announcements = snapshot.docs
                .map((doc) => AnnouncementModel.fromJson(doc.data()))
                .toList();
            _announcementsLoaded = true;
            notifyListeners();
          },
          onError: (Object e) {
            logDebug('Announcements listener stopped: $e');
            _announcementsSub?.cancel();
            _announcementsSub = null;
          },
        );

    _newsletterSub ??= _newsletterItems
        .orderBy('createdAt', descending: true)
        .limit(_newsletterLimit)
        .snapshots()
        .listen(
          (snapshot) {
            _newsletter = snapshot.docs
                .map((doc) => NewsletterModel.fromJson(doc.data()))
                .toList();
            _newsletterLoaded = true;
            notifyListeners();
          },
          onError: (Object e) {
            logDebug('Newsletter listener stopped: $e');
            _newsletterSub?.cancel();
            _newsletterSub = null;
          },
        );

    _monthsSub ??= _monthItems
        .orderBy('month', descending: true)
        .limit(_monthLimit)
        .snapshots()
        .listen(
          (snapshot) {
            _months = snapshot.docs
                .map((doc) => EmployeeOfMonthModel.fromJson(doc.data()))
                .toList();
            _monthsLoaded = true;
            notifyListeners();
          },
          onError: (Object e) {
            logDebug('Employee of the month listener stopped: $e');
            _monthsSub?.cancel();
            _monthsSub = null;
          },
        );

    _rulesSub ??= _rulesDoc.snapshots().listen(
      (doc) {
        _rules = CompanyRulesModel.fromJson(doc.data());
        _rulesLoaded = true;
        notifyListeners();
      },
      onError: (Object e) {
        logDebug('Company rules listener stopped: $e');
        _rulesSub?.cancel();
        _rulesSub = null;
      },
    );
  }

  /// Cancels the listeners and clears the data (called on logout).
  void stop() {
    final wasRunning =
        _announcementsSub != null ||
        _monthsSub != null ||
        _newsletterSub != null ||
        _rulesSub != null ||
        _announcementsLoaded ||
        _monthsLoaded ||
        _newsletterLoaded ||
        _rulesLoaded;
    if (!wasRunning) return;

    _announcementsSub?.cancel();
    _monthsSub?.cancel();
    _newsletterSub?.cancel();
    _rulesSub?.cancel();
    _announcementsSub = null;
    _monthsSub = null;
    _newsletterSub = null;
    _rulesSub = null;

    _announcements = [];
    _months = [];
    _newsletter = [];
    _rules = const CompanyRulesModel();
    _announcementsLoaded = false;
    _monthsLoaded = false;
    _newsletterLoaded = false;
    _rulesLoaded = false;

    // Called while the provider tree is updating, so notify afterwards
    Future.microtask(notifyListeners);
  }

  Future<bool> _guard(Future<void> Function() write, String what) async {
    start();
    _isSaving = true;
    notifyListeners();
    try {
      await write();
      return true;
    } catch (e) {
      logDebug('Error $what: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // --- Newsletter ---

  /// Posts a newsletter item. [imageBytes] is uploaded to Supabase first.
  Future<bool> addNewsletter({
    required String title,
    required String bodyJson,
    required String postedBy,
    required String posterId,
    DateTime? eventDate,
    Uint8List? imageBytes,
  }) {
    return _guard(() async {
      final id = const Uuid().v4();
      final imageUrl = imageBytes == null
          ? null
          : await SupabaseService.uploadNewsletterImage(id, imageBytes);

      final post = NewsletterModel(
        id: id,
        title: title,
        bodyJson: bodyJson,
        imageUrl: imageUrl,
        eventDate: eventDate,
        postedBy: postedBy,
        createdById: posterId,
        createdAt: DateTime.now(),
      );
      await _newsletterItems.doc(id).set({
        ...post.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }, 'posting newsletter');
  }

  /// Hides a post from everyone or shows it again. Nothing is deleted.
  Future<bool> setNewsletterActive(String id, bool isActive) {
    return _guard(
      () => _newsletterItems.doc(id).update({'isActive': isActive}),
      'changing newsletter',
    );
  }

  // --- Announcements ---

  /// Posts an announcement that stays active until [endsAt], and tells every
  /// user about it (admins and sub admins too, but not [posterId]).
  /// [imageBytes] is uploaded to Supabase first.
  Future<bool> addAnnouncement({
    required String title,
    required String message,
    required String postedBy,
    required String posterId,
    required DateTime endsAt,
    Uint8List? imageBytes,
  }) async {
    final saved = await _guard(() async {
      final id = const Uuid().v4();
      final imageUrl = imageBytes == null
          ? null
          : await SupabaseService.uploadAnnouncementImage(id, imageBytes);

      final announcement = AnnouncementModel(
        id: id,
        title: title,
        message: message,
        imageUrl: imageUrl,
        postedBy: postedBy,
        createdAt: DateTime.now(),
        endsAt: endsAt,
        createdById: posterId,
      );
      await _announcementItems.doc(id).set({
        ...announcement.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }, 'posting announcement');

    // The notification never decides whether the post worked
    if (saved) {
      unawaited(
        FCMService()
            .sendNotificationToAll(
              title: 'New announcement',
              body: title,
              data: {
                'type': AppConstants.announcementNotification,
                'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
              },
              excludeUserId: posterId,
            )
            .catchError((Object e) {
              logDebug('Announcement notification failed: $e');
              return 0;
            }),
      );
    }
    return saved;
  }

  /// Switches an announcement on or off by hand. Nothing is deleted: an
  /// inactive one is only hidden from employees.
  Future<bool> setAnnouncementActive(String id, bool isActive) {
    return _guard(
      () => _announcementItems.doc(id).update({'isActive': isActive}),
      'changing announcement',
    );
  }

  /// Gives an announcement a new end time and switches it on again.
  Future<bool> extendAnnouncement(String id, DateTime endsAt) {
    return _guard(
      () => _announcementItems.doc(id).update({
        'endsAt': Timestamp.fromDate(endsAt),
        'isActive': true,
      }),
      'extending announcement',
    );
  }

  // --- Employee of the month ---

  // users/{uid}/achievements/{id}
  DocumentReference<Map<String, dynamic>> _achievementRef(
    String userId,
    String month,
  ) => _firestore
      .collection(FirestoreCollections.users)
      .doc(userId)
      .collection(FirestoreSubCollections.achievements)
      .doc(AchievementModel.employeeOfMonthId(month));

  /// Chooses [employee] for [month] (replaces the one already chosen for it).
  /// The choice is also written on the employee's own record as an
  /// achievement, so their screens can show it. All of it is one batch.
  ///
  /// When it is the current month and a different person than before, everyone
  /// is told (admins and sub admins too, but not [posterId]). An earlier month
  /// is only a record, so it is not announced.
  Future<bool> setEmployeeOfMonth({
    required DateTime month,
    required EmployeeModel employee,
    required String posterId,
    String? note,
  }) async {
    final key = EmployeeOfMonthModel.keyFor(month);
    final isCurrentMonth = key == EmployeeOfMonthModel.keyFor(DateTime.now());
    final alreadyThem = _months.any(
      (m) => m.month == key && m.userId == employee.id && m.isActive,
    );

    final saved = await _guard(() async {
      final cleanNote = note == null || note.trim().isEmpty
          ? null
          : note.trim();
      final record = EmployeeOfMonthModel(
        month: key,
        userId: employee.id,
        name: employee.name,
        department: employee.department,
        jobRole: employee.jobRole,
        profileImageUrl: employee.profileImageUrl,
        note: cleanNote,
        createdById: posterId,
      );
      final achievement = AchievementModel(
        id: AchievementModel.employeeOfMonthId(key),
        type: AchievementModel.employeeOfMonthType,
        month: key,
        title: 'Employee of the Month',
        note: cleanNote,
        awardedAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(_monthItems.doc(key), {
        ...record.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_achievementRef(employee.id, key), {
        ...achievement.toJson(),
        'awardedAt': FieldValue.serverTimestamp(),
      });

      // Someone else was chosen for this month before: it is no longer theirs
      for (final previous in _months) {
        if (previous.month == key && previous.userId != employee.id) {
          batch.delete(_achievementRef(previous.userId, key));
        }
      }
      await batch.commit();
    }, 'saving employee of the month');

    // The notification never decides whether the choice was saved
    if (saved && isCurrentMonth && !alreadyThem) {
      final monthName = DateFormat('MMMM yyyy').format(month);
      unawaited(
        FCMService()
            .sendNotificationToAll(
              title: 'Employee of the Month 🏆',
              body:
                  'Congratulations ${employee.name}! '
                  'Employee of the Month for $monthName.',
              data: {
                'type': AppConstants.employeeOfMonthNotification,
                'userId': employee.id,
                'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
              },
              excludeUserId: posterId,
            )
            .catchError((Object e) {
              logDebug('Employee of the month notification failed: $e');
              return 0;
            }),
      );
    }
    return saved;
  }

  /// Switches a month's choice on or off by hand. Nothing is deleted: an
  /// inactive one is only hidden, and the employee keeps the achievement.
  Future<bool> setEmployeeOfMonthActive(String month, bool isActive) {
    return _guard(
      () => _monthItems.doc(month).update({'isActive': isActive}),
      'changing employee of the month',
    );
  }

  // --- Company rules ---

  /// Saves the rules document ([contentJson] is the editor's Delta as JSON).
  /// An empty editor clears the rules.
  Future<bool> saveRules(String contentJson) {
    return _guard(() async {
      await _rulesDoc.set({
        'content': CompanyRulesModel.hasContent(contentJson) ? contentJson : '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }, 'saving company rules');
  }

  @override
  void dispose() {
    _announcementsSub?.cancel();
    _monthsSub?.cancel();
    _newsletterSub?.cancel();
    _rulesSub?.cancel();
    super.dispose();
  }
}
