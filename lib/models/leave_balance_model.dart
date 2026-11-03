/// "12" for a whole number, "11.5" for a half day: how leave days are shown.
String leaveCount(num value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toString();

/// A year of leave of one employee (users/{uid}/leaves/annual_{year}) with the
/// days kept as numbers, because a half day moves them by 0.5.
class LeaveBalanceModel {
  final num plTotal;
  final num plUsed;
  final num plBalance;
  final num slTotal;
  final num slUsed;
  final num slBalance;
  final num clTotal;
  final num clUsed;
  final num clBalance;
  final num totalAllocated;
  final num totalUsed;
  final num totalBalance;

  LeaveBalanceModel({
    required this.plTotal,
    required this.plUsed,
    required this.plBalance,
    required this.slTotal,
    required this.slUsed,
    required this.slBalance,
    required this.clTotal,
    required this.clUsed,
    required this.clBalance,
    required this.totalAllocated,
    required this.totalUsed,
    required this.totalBalance,
  });

  static num _num(dynamic v) => v is num ? v : 0;

  factory LeaveBalanceModel.fromFirestore(Map<String, dynamic> data) {
    Map<String, dynamic>? typeOf(String key) {
      final v = data[key];
      return v is Map ? Map<String, dynamic>.from(v) : null;
    }

    final pl = typeOf('privilegeLeaves');
    final sl = typeOf('sickLeaves');
    final cl = typeOf('casualLeaves');

    final plTotal = _num(pl?['allocated']);
    final plUsed = _num(pl?['used']);
    final plBalance = _num(pl?['balance']);
    final slTotal = _num(sl?['allocated']);
    final slUsed = _num(sl?['used']);
    final slBalance = _num(sl?['balance']);
    final clTotal = _num(cl?['allocated']);
    final clUsed = _num(cl?['used']);
    final clBalance = _num(cl?['balance']);

    return LeaveBalanceModel(
      plTotal: plTotal,
      plUsed: plUsed,
      plBalance: plBalance,
      slTotal: slTotal,
      slUsed: slUsed,
      slBalance: slBalance,
      clTotal: clTotal,
      clUsed: clUsed,
      clBalance: clBalance,
      // The stored totals when there, else the sum of the three types
      totalAllocated: data['totalAllocated'] is num
          ? data['totalAllocated'] as num
          : plTotal + slTotal + clTotal,
      totalUsed: data['totalUsed'] is num
          ? data['totalUsed'] as num
          : plUsed + slUsed + clUsed,
      totalBalance: data['totalBalance'] is num
          ? data['totalBalance'] as num
          : plBalance + slBalance + clBalance,
    );
  }

  bool get hasAnyLeaves => totalAllocated > 0;
}
