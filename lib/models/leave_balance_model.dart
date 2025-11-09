class LeaveBalanceModel {
  final int plTotal;
  final int plUsed;
  final int plBalance;
  final int slTotal;
  final int slUsed;
  final int slBalance;
  final int clTotal;
  final int clUsed;
  final int clBalance;
  final int totalAllocated;
  final int totalUsed;
  final int totalBalance;

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

  factory LeaveBalanceModel.fromFirestore(Map<String, dynamic> data) {
    // Extract privilege leaves
    final plData = data['privilegeLeaves'] as Map<String, dynamic>?;
    final plTotal = (plData?['allocated'] ?? 0) as num;
    final plUsed = (plData?['used'] ?? 0) as num;
    final plBalance = (plData?['balance'] ?? 0) as num;

    // Extract sick leaves
    final slData = data['sickLeaves'] as Map<String, dynamic>?;
    final slTotal = (slData?['allocated'] ?? 0) as num;
    final slUsed = (slData?['used'] ?? 0) as num;
    final slBalance = (slData?['balance'] ?? 0) as num;

    // Extract casual leaves
    final clData = data['casualLeaves'] as Map<String, dynamic>?;
    final clTotal = (clData?['allocated'] ?? 0) as num;
    final clUsed = (clData?['used'] ?? 0) as num;
    final clBalance = (clData?['balance'] ?? 0) as num;

    return LeaveBalanceModel(
      plTotal: plTotal.toInt(),
      plUsed: plUsed.toInt(),
      plBalance: plBalance.toInt(),
      slTotal: slTotal.toInt(),
      slUsed: slUsed.toInt(),
      slBalance: slBalance.toInt(),
      clTotal: clTotal.toInt(),
      clUsed: clUsed.toInt(),
      clBalance: clBalance.toInt(),
      totalAllocated: (data['totalAllocated'] ?? (plTotal + slTotal + clTotal)) as int,
      totalUsed: (data['totalUsed'] ?? (plUsed + slUsed + clUsed)) as int,
      totalBalance: (data['totalBalance'] ?? (plBalance + slBalance + clBalance)) as int,
    );
  }

  bool get hasAnyLeaves => totalAllocated > 0;
}

