import 'package:cloud_firestore/cloud_firestore.dart';

/// Where an announcement stands right now.
enum AnnouncementStatus { active, inactive, expired }

/// A message the admin posts for everyone, with an optional picture.
/// Stored in organization_details/announcements/items/{id}.
///
/// It is shown to employees only while it is active: switched on and before its
/// end time. An admin can switch it off by hand; nothing is ever deleted.
class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final String? imageUrl;
  final String postedBy;
  final DateTime createdAt;

  /// When it stops being shown. Null (older announcements) means never.
  final DateTime? endsAt;

  /// Switched off by the admin when false.
  final bool isActive;

  /// User id of whoever posted it (null on older announcements), so their own
  /// post is not counted as news for them.
  final String? createdById;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.postedBy,
    required this.createdAt,
    this.imageUrl,
    this.endsAt,
    this.isActive = true,
    this.createdById,
  });

  /// Active, inactive (switched off by the admin) or expired (past its end).
  AnnouncementStatus statusAt(DateTime now) {
    if (!isActive) return AnnouncementStatus.inactive;
    final end = endsAt;
    if (end != null && !now.isBefore(end)) return AnnouncementStatus.expired;
    return AnnouncementStatus.active;
  }

  /// True when employees should see it at [now].
  bool isShownAt(DateTime now) => statusAt(now) == AnnouncementStatus.active;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    final ends = json['endsAt'];
    final image = json['imageUrl']?.toString().trim();
    return AnnouncementModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      imageUrl: image == null || image.isEmpty ? null : image,
      postedBy: json['postedBy']?.toString() ?? '',
      // A just-written document has no server time yet: treat it as now
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      endsAt: ends is Timestamp ? ends.toDate() : null,
      isActive: json['isActive'] != false,
      createdById: json['createdById']?.toString(),
    );
  }

  /// The saved fields. createdAt is added by the writer as a server time.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'imageUrl': imageUrl,
    'postedBy': postedBy,
    'endsAt': endsAt == null ? null : Timestamp.fromDate(endsAt!),
    'isActive': isActive,
    'createdById': createdById,
  };
}
