/// Leave totals across all onboarded employees for the current year, built from
/// users/{uid}/leaves/annual_{year}.
class LeaveStatisticsModel {
  final int totalUsers;
  final int totalAllocatedLeaves;
  final int totalUsedLeaves;
  final int totalBalanceLeaves;
  final int totalPLAllocated;
  final int totalSLAllocated;
  final int totalCLAllocated;

  const LeaveStatisticsModel({
    this.totalUsers = 0,
    this.totalAllocatedLeaves = 0,
    this.totalUsedLeaves = 0,
    this.totalBalanceLeaves = 0,
    this.totalPLAllocated = 0,
    this.totalSLAllocated = 0,
    this.totalCLAllocated = 0,
  });

  /// Share of the allocated leave that has been used, in percent.
  int get utilizationPercentage => totalAllocatedLeaves > 0
      ? (totalUsedLeaves / totalAllocatedLeaves * 100).round()
      : 0;
}
