import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';
import '../models/leave_balance_model.dart';
import '../models/leave_statistics_model.dart';
import 'employee_management_provider.dart';
import 'onboarding_provider.dart';

/// Admin dashboard data: leave statistics and per-employee leave balances.
/// Organization settings (leave counts, office hours, holidays) live in
/// [OrganizationProvider], not here.
class DashboardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Leave statistics state
  LeaveStatisticsModel _leaveStats = const LeaveStatisticsModel();
  bool _isLoadingLeaveStats = true;

  // Employee leave balances state
  Map<String, LeaveBalanceModel> _employeeLeaves = {};
  bool _isLoadingEmployeeLeaves = true;

  // Onboarded employees that have no leave allocation for the current year yet
  // (for example at the start of a new year); the admin is prompted to assign
  int _missingLeaveCount = 0;
  int get missingLeaveCount => _missingLeaveCount;

  // Expanded employee card
  String? _expandedEmployeeId;

  // Getters
  LeaveStatisticsModel get leaveStats => _leaveStats;
  bool get isLoadingLeaveStats => _isLoadingLeaveStats;
  Map<String, LeaveBalanceModel> get employeeLeaves => _employeeLeaves;
  bool get isLoadingEmployeeLeaves => _isLoadingEmployeeLeaves;
  String? get expandedEmployeeId => _expandedEmployeeId;

  // Toggle expanded employee
  void toggleExpandedEmployee(String employeeId) {
    _expandedEmployeeId =
        _expandedEmployeeId == employeeId ? null : employeeId;
    notifyListeners();
  }

  // Load all dashboard data
  Future<void> loadDashboardData(
    EmployeeManagementProvider empProvider,
    OnboardingProvider onboardingProvider,
  ) async {
    empProvider.fetchAllEmployees();
    empProvider.fetchDepartments();

    await Future.wait([
      _loadLeaveStatistics(onboardingProvider),
      _loadEmployeeLeaves(empProvider, onboardingProvider),
    ]);
  }

  // Load leave statistics
  Future<void> _loadLeaveStatistics(
    OnboardingProvider onboardingProvider,
  ) async {
    _isLoadingLeaveStats = true;
    notifyListeners();

    try {
      final stats = await onboardingProvider.getLeaveStatistics();
      _leaveStats = stats;
    } catch (_) {}

    _isLoadingLeaveStats = false;
    notifyListeners();
  }

  // Load individual employee leave balances
  Future<void> _loadEmployeeLeaves(
    EmployeeManagementProvider empProvider,
    OnboardingProvider onboardingProvider,
  ) async {
    _isLoadingEmployeeLeaves = true;
    notifyListeners();

    final Map<String, LeaveBalanceModel> leaves = {};
    final employees =
        empProvider.employees.where((e) => e.isOnboarded).toList();
    var missing = 0;

    for (final emp in employees) {
      try {
        final data = await onboardingProvider.getUserLeaveAllocation(emp.id);
        if (data != null) {
          leaves[emp.id] = LeaveBalanceModel.fromFirestore(data);
        } else {
          missing++;
        }
      } catch (_) {}
    }

    _missingLeaveCount = missing;
    _employeeLeaves = leaves;
    _isLoadingEmployeeLeaves = false;
    notifyListeners();
  }

  // Update leave allocation for an employee
  Future<void> updateLeaveAllocation(
    String employeeId,
    String leaveType,
    int newTotal,
    EmployeeManagementProvider empProvider,
    OnboardingProvider onboardingProvider,
  ) async {
    try {
      final currentYear = DateTime.now().year;
      final docRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(employeeId)
          .collection(FirestoreSubCollections.leaves)
          .doc(FirestoreDocs.annualLeave(currentYear));

      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data()!;
      String fieldKey;
      switch (leaveType) {
        case 'pl':
          fieldKey = 'privilegeLeaves';
          break;
        case 'sl':
          fieldKey = 'sickLeaves';
          break;
        case 'cl':
          fieldKey = 'casualLeaves';
          break;
        default:
          return;
      }

      final leaveData = data[fieldKey] as Map<String, dynamic>;
      final used = (leaveData['used'] ?? 0) as int;
      final newBalance = newTotal - used;

      await docRef.update({
        '$fieldKey.allocated': newTotal,
        '$fieldKey.balance': newBalance < 0 ? 0 : newBalance,
        'totalAllocated': _recalcTotal(data, fieldKey, 'allocated', newTotal),
        'totalBalance': _recalcTotal(
          data,
          fieldKey,
          'balance',
          newBalance < 0 ? 0 : newBalance,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload data
      await Future.wait([
        _loadLeaveStatistics(onboardingProvider),
        _loadEmployeeLeaves(empProvider, onboardingProvider),
      ]);
    } catch (e) {
      debugPrint('Error updating leave: $e');
    }
  }

  int _recalcTotal(
    Map<String, dynamic> data,
    String changedField,
    String subField,
    int newValue,
  ) {
    int total = 0;
    for (final key in ['privilegeLeaves', 'sickLeaves', 'casualLeaves']) {
      if (key == changedField) {
        total += newValue;
      } else {
        final ld = data[key] as Map<String, dynamic>?;
        total += ((ld?[subField] ?? 0) as num).toInt();
      }
    }
    return total;
  }
}
