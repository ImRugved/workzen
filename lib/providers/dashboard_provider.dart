import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';
import '../models/leave_balance_model.dart';
import 'employee_management_provider.dart';
import 'onboarding_provider.dart';

class DashboardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Leave statistics state
  Map<String, dynamic> _leaveStats = {};
  bool _isLoadingLeaveStats = true;

  // Employee leave balances state
  Map<String, LeaveBalanceModel> _employeeLeaves = {};
  bool _isLoadingEmployeeLeaves = true;

  // Expanded employee card
  String? _expandedEmployeeId;

  // Leave configuration defaults
  int _defaultPL = 12;
  int _defaultSL = 6;
  int _defaultCL = 5;
  bool _isLoadingLeaveConfig = false;
  bool _isSavingLeaveConfig = false;

  // Getters
  Map<String, dynamic> get leaveStats => _leaveStats;
  bool get isLoadingLeaveStats => _isLoadingLeaveStats;
  Map<String, LeaveBalanceModel> get employeeLeaves => _employeeLeaves;
  bool get isLoadingEmployeeLeaves => _isLoadingEmployeeLeaves;
  String? get expandedEmployeeId => _expandedEmployeeId;
  int get defaultPL => _defaultPL;
  int get defaultSL => _defaultSL;
  int get defaultCL => _defaultCL;
  bool get isLoadingLeaveConfig => _isLoadingLeaveConfig;
  bool get isSavingLeaveConfig => _isSavingLeaveConfig;

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
      loadLeaveDefaults(),
      _loadLeaveStatistics(onboardingProvider),
      _loadEmployeeLeaves(empProvider, onboardingProvider),
    ]);
  }

  // Load leave defaults from Firestore
  Future<void> loadLeaveDefaults() async {
    _isLoadingLeaveConfig = true;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection(AppConstants.settingsCollection)
          .doc(AppConstants.leaveDefaultsDoc)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _defaultPL = (data['privilegeLeaves'] ?? 12) as int;
        _defaultSL = (data['sickLeaves'] ?? 6) as int;
        _defaultCL = (data['casualLeaves'] ?? 5) as int;
      }
    } catch (e) {
      debugPrint('Error loading leave defaults: $e');
    }

    _isLoadingLeaveConfig = false;
    notifyListeners();
  }

  // Save leave defaults to Firestore
  Future<bool> saveLeaveDefaults(int pl, int sl, int cl) async {
    _isSavingLeaveConfig = true;
    notifyListeners();

    try {
      await _firestore
          .collection(AppConstants.settingsCollection)
          .doc(AppConstants.leaveDefaultsDoc)
          .set({
        'privilegeLeaves': pl,
        'sickLeaves': sl,
        'casualLeaves': cl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _defaultPL = pl;
      _defaultSL = sl;
      _defaultCL = cl;

      _isSavingLeaveConfig = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving leave defaults: $e');
      _isSavingLeaveConfig = false;
      notifyListeners();
      return false;
    }
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

    for (final emp in employees) {
      try {
        final data = await onboardingProvider.getUserLeaveAllocation(emp.id);
        if (data != null) {
          leaves[emp.id] = LeaveBalanceModel.fromFirestore(data);
        }
      } catch (_) {}
    }

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
          .collection(AppConstants.usersCollection)
          .doc(employeeId)
          .collection('leaves')
          .doc('annual_$currentYear');

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
