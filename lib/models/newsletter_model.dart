import 'package:cloud_firestore/cloud_firestore.dart';

/// A piece of company news: a visit, a milestone, an achievement, an update or
/// anything else worth sharing, with formatted text and an optional picture.
/// Stored in organization_details/newsletter/items/{id}; it stays until an admin
/// hides it (nothing is deleted).
class NewsletterModel {
  final String id;
  final String title;

  /// The text as a Quill Delta in JSON, or null.
  final String? bodyJson;
  final String? imageUrl;

  /// When the visit or milestone happened, if the author said.
  final DateTime? eventDate;
  final String postedBy;
  final String? createdById;
  final DateTime createdAt;

  /// Hidden by an admin when false.
  final bool isActive;

  const NewsletterModel({
    required this.id,
    required this.title,
    required this.postedBy,
    required this.createdAt,
    this.bodyJson,
    this.imageUrl,
    this.eventDate,
    this.createdById,
    this.isActive = true,
  });

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  factory NewsletterModel.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    final event = json['eventDate'];
    return NewsletterModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      bodyJson: _text(json['body']),
      imageUrl: _text(json['imageUrl']),
      eventDate: event is Timestamp ? event.toDate() : null,
      postedBy: json['postedBy']?.toString() ?? '',
      createdById: _text(json['createdById']),
      // A just-written document has no server time yet: treat it as now
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      isActive: json['isActive'] != false,
    );
  }

  /// The saved fields. createdAt is added by the writer as a server time.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': bodyJson,
    'imageUrl': imageUrl,
    'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate!),
    'postedBy': postedBy,
    'createdById': createdById,
    'isActive': isActive,
  };
}
