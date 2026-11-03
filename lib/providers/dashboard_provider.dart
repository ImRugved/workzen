import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_constants.dart';
import '../models/leave_balance_model.dart';
import 'employee_management_provider.dart';
import 'onboarding_provider.dart';

/// Admin dashboard data: the per-employee leave balances.
/// Organization settings (leave counts, office hours, holidays) live in
/// [OrganizationProvider], not here.
class DashboardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // How many employees' leave documents are read at the same time
  static const int _parallelReads = 10;

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
  Map<String, LeaveBalanceModel> get employeeLeaves => _employeeLeaves;
  bool get isLoadingEmployeeLeaves => _isLoadingEmployeeLeaves;
  String? get expandedEmployeeId => _expandedEmployeeId;

  // Toggle expanded employee
  void toggleExpandedEmployee(String employeeId) {
    _expandedEmployeeId = _expandedEmployeeId == employeeId ? null : employeeId;
    notifyListeners();
  }

  // Load all dashboard data
  Future<void> loadDashboardData(
    EmployeeManagementProvider empProvider,
    OnboardingProvider onboardingProvider,
  ) async {
    // Who is onboarded comes from the employee list, so wait for it; the
    // leave documents are read only after that
    await Future.wait([
      empProvider.fetchAllEmployees(),
      empProvider.fetchDepartments(),
    ]);
    await _loadEmployeeLeaves(empProvider, onboardingProvider);
  }

  // Load individual employee leave balances
  Future<void> _loadEmployeeLeaves(
    EmployeeManagementProvider empProvider,
    OnboardingProvider onboardingProvider,
  ) async {
    _isLoadingEmployeeLeaves = true;
    notifyListeners();

    final Map<String, LeaveBalanceModel> leaves = {};
    // Every onboarded employee, whatever search or filter the employee
    // management screen has on
    final employees = empProvider.allEmployees
        .where((e) => e.isOnboarded)
        .toList();
    var missing = 0;

    // One read per employee, ten at a time. Reading them one after another
    // made the section wait for every round trip in turn.
    for (var i = 0; i < employees.length; i += _parallelReads) {
      final end = i + _parallelReads > employees.length
          ? employees.length
          : i + _parallelReads;
      final batch = employees.sublist(i, end);

      final results = await Future.wait(
        batch.map((emp) async {
          try {
            return (ok: true, data: await onboardingProvider
                .getUserLeaveAllocation(emp.id));
          } catch (_) {
            return (ok: false, data: null as Map<String, dynamic>?);
          }
        }),
      );

      for (var j = 0; j < batch.length; j++) {
        final result = results[j];
        if (!result.ok) continue;
        final data = result.data;
        if (data != null) {
          leaves[batch[j].id] = LeaveBalanceModel.fromFirestore(data);
        } else {
          missing++;
        }
      }
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
      // Half days make these decimals
      final used = (leaveData['used'] ?? 0) as num;
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
      await _loadEmployeeLeaves(empProvider, onboardingProvider);
    } catch (e) {
      debugPrint('Error updating leave: $e');
    }
  }

  num _recalcTotal(
    Map<String, dynamic> data,
    String changedField,
    String subField,
    num newValue,
  ) {
    num total = 0;
    for (final key in ['privilegeLeaves', 'sickLeaves', 'casualLeaves']) {
      if (key == changedField) {
        total += newValue;
      } else {
        final ld = data[key] as Map<String, dynamic>?;
        total += (ld?[subField] ?? 0) as num;
      }
    }
    return total;
  }
}
