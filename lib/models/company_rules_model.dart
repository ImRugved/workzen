import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// The company rules: one formatted document written by the admin (pasted from
/// ChatGPT or typed, with bold, italic, headings, lists...). Stored in
/// organization_details/company_rules.
///
/// The formatting is kept as a Quill Delta, saved as a JSON string in
/// `content`; the rules screen edits it and the Info pages show it.
class CompanyRulesModel {
  /// The Delta as JSON text, or null when there are no rules.
  final String? contentJson;
  final DateTime? updatedAt;

  const CompanyRulesModel({this.contentJson, this.updatedAt});

  bool get isEmpty => contentJson == null;

  /// Reads the saved document. A first version saved the rules as a list of
  /// {title, description}; those are turned into the same kind of document
  /// (bold title, then the text) so nothing written earlier is lost.
  factory CompanyRulesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CompanyRulesModel();

    final updated = json['updatedAt'];
    final updatedAt = updated is Timestamp ? updated.toDate() : null;

    final content = json['content'];
    if (content is String && _hasText(content)) {
      return CompanyRulesModel(contentJson: content, updatedAt: updatedAt);
    }

    final legacy = json['rules'];
    if (legacy is List && legacy.isNotEmpty) {
      final ops = <Map<String, dynamic>>[];
      for (final rule in legacy.whereType<Map>()) {
        ops.add({
          'insert': rule['title']?.toString() ?? '',
          'attributes': {'bold': true},
        });
        ops.add({'insert': '\n'});
        ops.add({'insert': '${rule['description'] ?? ''}\n\n'});
      }
      return CompanyRulesModel(
        contentJson: jsonEncode(ops),
        updatedAt: updatedAt,
      );
    }

    return CompanyRulesModel(updatedAt: updatedAt);
  }

  // True when the Delta JSON has something other than the final newline
  static bool _hasText(String contentJson) {
    try {
      final ops = jsonDecode(contentJson);
      if (ops is! List) return false;
      return ops.whereType<Map>().any((op) {
        final insert = op['insert'];
        return insert is! String || insert.trim().isNotEmpty;
      });
    } catch (_) {
      return false;
    }
  }

  /// True when [contentJson] has real content (not just an empty editor).
  static bool hasContent(String contentJson) => _hasText(contentJson);
}
