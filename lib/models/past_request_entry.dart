import 'package:intl/intl.dart';
import '../app_constants.dart';

/// The kinds of record HR can add for days an employee already took.
enum PastRequestKind {
  pl('Privilege Leave (PL)', 'Privilege Leave', 'PL'),
  sl('Sick Leave (SL)', 'Sick Leave', 'SL'),
  cl('Casual Leave (CL)', 'Casual Leave', 'CL'),
  ul('Unpaid Leave (UL)', 'Unpaid Leave', 'UL'),
  co('Comp Off Leave (CO)', 'Comp Off Leave', 'CO'),
  wfh('Work From Home (WFH)', 'Work From Home', 'WFH'),
  compOff('Comp Off (worked on a day off)', 'Comp Off', '+CO');

  /// Name in the type dropdown.
  final String label;

  /// Title of its section in the list of added records.
  final String sectionTitle;

  /// Short badge text.
  final String code;

  const PastRequestKind(this.label, this.sectionTitle, this.code);

  /// Leave that is taken from a balance (PL, SL, CL), from comp off credit (CO)
  /// or that has no balance at all (UL, unpaid: only its days taken are
  /// counted).
  bool get isLeave =>
      this == pl || this == sl || this == cl || this == ul || this == co;

  /// Whether a half day can be chosen (everything except work from home).
  bool get supportsHalfDay => this != wfh;

  /// Leave type code stored on the request ("pl", "sl", "cl", "ul", "co"), or null
  /// when this kind is not a leave.
  String? get leaveCode {
    switch (this) {
      case PastRequestKind.pl:
        return AppConstants.leaveTypePL;
      case PastRequestKind.sl:
        return AppConstants.leaveTypeSL;
      case PastRequestKind.cl:
        return AppConstants.leaveTypeCL;
      case PastRequestKind.ul:
        return AppConstants.leaveTypeUL;
      case PastRequestKind.co:
        return AppConstants.leaveTypeCO;
      case PastRequestKind.wfh:
      case PastRequestKind.compOff:
        return null;
    }
  }
}

/// What saving the records gave: an [error] (nothing saved), or success with
/// optional [notes] to tell HR, for example a balance that could not change.
class PastRequestsResult {
  final String? error;
  final List<String> notes;

  const PastRequestsResult.failure(String message)
    : error = message,
      notes = const [];
  const PastRequestsResult.success([this.notes = const []]) : error = null;

  bool get isSuccess => error == null;
}

/// One record HR has added on the Update Employee Leaves page, before it is
/// saved. Saving turns it into an approved request on the employee.
class PastRequestEntry {
  static const String firstHalf = 'First Half';
  static const String secondHalf = 'Second Half';

  final String id;
  final PastRequestKind kind;
  final bool isHalfDay;

  /// "First Half" or "Second Half" for a half day leave, otherwise null.
  final String? half;

  /// First day (for a comp off: the day worked).
  final DateTime from;

  /// Last day; equal to [from] for one day.
  final DateTime to;

  /// Comp off only: the day off taken in return.
  final DateTime? compOffDate;
  final String reason;

  const PastRequestEntry({
    required this.id,
    required this.kind,
    required this.isHalfDay,
    required this.from,
    required this.to,
    this.half,
    this.compOffDate,
    this.reason = '',
  });

  /// Days this record counts for.
  double get days {
    if (isHalfDay) return 0.5;
    if (kind == PastRequestKind.compOff) return 1;
    return (to.difference(from).inDays + 1).toDouble();
  }

  bool get isSingleDay => from == to;

  /// The dates (and half) as shown on the card.
  String get dateText {
    final day = DateFormat('dd MMM yyyy');
    final short = DateFormat('dd MMM');

    if (kind == PastRequestKind.compOff) {
      final off = compOffDate == null ? '' : ' • Off ${day.format(compOffDate!)}';
      return 'Worked ${short.format(from)}$off';
    }

    final dates = isSingleDay
        ? day.format(from)
        : '${short.format(from)} - ${day.format(to)}';
    final halfText = isHalfDay
        ? ' • ${half == secondHalf ? 'Second half' : 'First half'}'
        : '';
    return '$dates$halfText';
  }

  /// "1 day", "0.5 day", "3 days".
  String get daysText {
    final d = days;
    final number = d % 1 == 0 ? d.toInt().toString() : d.toString();
    return '$number ${d == 1 ? 'day' : 'days'}';
  }

  PastRequestEntry copyWith({
    PastRequestKind? kind,
    bool? isHalfDay,
    String? half,
    DateTime? from,
    DateTime? to,
    DateTime? compOffDate,
    String? reason,
  }) {
    return PastRequestEntry(
      id: id,
      kind: kind ?? this.kind,
      isHalfDay: isHalfDay ?? this.isHalfDay,
      half: half ?? this.half,
      from: from ?? this.from,
      to: to ?? this.to,
      compOffDate: compOffDate ?? this.compOffDate,
      reason: reason ?? this.reason,
    );
  }
}
