/// One leave type inside users/{uid}/leaves/annual_{year}.
/// Values are doubles because half-day leave moves the numbers by 0.5.
class LeaveTypeBalance {
  final double allocated;
  final double carryForward;
  final double used;
  final double balance;

  const LeaveTypeBalance({
    required this.allocated,
    required this.carryForward,
    required this.used,
    required this.balance,
  });

  static double _num(dynamic v) => v is num ? v.toDouble() : 0;

  factory LeaveTypeBalance.fromJson(Map<String, dynamic> json) {
    return LeaveTypeBalance(
      allocated: _num(json['allocated']),
      carryForward: _num(json['carryForward']),
      used: _num(json['used']),
      balance: _num(json['balance']),
    );
  }
}

/// users/{uid}/leaves/annual_{year}: what an employee has for one year.
class LeaveAllocationModel {
  final int year;
  final LeaveTypeBalance? privilege;
  final LeaveTypeBalance? sick;
  final LeaveTypeBalance? casual;

  const LeaveAllocationModel({
    required this.year,
    this.privilege,
    this.sick,
    this.casual,
  });

  static LeaveTypeBalance? _type(dynamic v) =>
      v is Map ? LeaveTypeBalance.fromJson(Map<String, dynamic>.from(v)) : null;

  /// Returns null when the document does not exist.
  static LeaveAllocationModel? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return LeaveAllocationModel(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      privilege: _type(json['privilegeLeaves']),
      sick: _type(json['sickLeaves']),
      casual: _type(json['casualLeaves']),
    );
  }
}
