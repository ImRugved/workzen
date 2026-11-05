/// Where an employee of the month entry stands right now.
enum EmployeeOfMonthStatus { active, inactive, expired }

/// The employee chosen for a month. Stored in
/// organization_details/employee_of_month/items/{yyyy-MM}, so there is one per
/// month; choosing again for the same month replaces it.
///
/// It is shown to everyone only during its own month. When the month is over it
/// is expired and stays in the history. The admin can also switch it off by
/// hand during the month; nothing is ever deleted.
class EmployeeOfMonthModel {
  /// "2026-10": also the document id.
  final String month;
  final String userId;
  final String name;
  final String? department;
  final String? jobRole;
  final String? profileImageUrl;
  final String? note;

  /// Switched off by the admin when false.
  final bool isActive;

  /// User id of whoever chose them (null on older entries), so their own
  /// choice is not counted as news for them.
  final String? createdById;

  const EmployeeOfMonthModel({
    required this.month,
    required this.userId,
    required this.name,
    this.department,
    this.jobRole,
    this.profileImageUrl,
    this.note,
    this.isActive = true,
    this.createdById,
  });

  /// Expired once its month is over, else inactive when switched off, else
  /// active.
  EmployeeOfMonthStatus statusAt(DateTime now) {
    if (monthDate.isBefore(DateTime(now.year, now.month))) {
      return EmployeeOfMonthStatus.expired;
    }
    return isActive
        ? EmployeeOfMonthStatus.active
        : EmployeeOfMonthStatus.inactive;
  }

  /// True when everyone should see it at [now].
  bool isShownAt(DateTime now) =>
      statusAt(now) == EmployeeOfMonthStatus.active;

  /// "Software Engineer • Engineering": the designation line of the card.
  String get designation =>
      [jobRole, department].whereType<String>().join(' • ');

  /// The key of [date]'s month, for example "2026-10".
  static String keyFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  /// The first day of this record's month.
  DateTime get monthDate {
    final parts = month.split('-');
    final year = int.tryParse(parts.first) ?? DateTime.now().year;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    return DateTime(year, m);
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  factory EmployeeOfMonthModel.fromJson(Map<String, dynamic> json) {
    return EmployeeOfMonthModel(
      month: json['month']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      department: _text(json['department']),
      jobRole: _text(json['jobRole']),
      profileImageUrl: _text(json['profileImageUrl']),
      note: _text(json['note']),
      isActive: json['isActive'] != false,
      createdById: _text(json['createdById']),
    );
  }

  /// The saved fields. updatedAt is added by the writer as a server time.
  Map<String, dynamic> toJson() => {
    'month': month,
    'userId': userId,
    'name': name,
    'department': department,
    'jobRole': jobRole,
    'profileImageUrl': profileImageUrl,
    'note': note,
    'isActive': isActive,
    'createdById': createdById,
  };
}
