import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';
import '../constants/firestore_constants.dart';
import '../models/request_model.dart';
import '../models/comp_off_balance_model.dart';
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
  // Comp off credit of each employee (not tied to a year)
  Map<String, CompOffBalanceModel> _compOff = {};
  bool _isLoadingEmployeeLeaves = true;

  // The year whose leave documents the Leave Balances tab shows and edits
  int _year = DateTime.now().year;
  int get selectedYear => _year;
  Map<String, CompOffBalanceModel> get compOff => _compOff;

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

  /// Shows (and edits) the leave documents of [year] on the Leave Balances tab.
  Future<void> setYear(
    int year,
    EmployeeManagementProvider empProvider,
    OnboardingProvider onboardingProvider,
  ) async {
    if (year == _year) return;
    _year = year;
    // Another year's numbers: show the loading state, not the old year
    await _loadEmployeeLeaves(
      empProvider,
      onboardingProvider,
      showLoading: true,
    );
  }

  // Load individual employee leave balances. The loading state shows only when
  // there is nothing on screen yet (or [showLoading] asks for it); a reload
  // after an edit, or when the screen opens again, swaps the numbers in without
  // the cards flashing back to the loading placeholder.
  Future<void> _loadEmployeeLeaves(
    EmployeeManagementProvider empProvider,
    OnboardingProvider onboardingProvider, {
    bool? showLoading,
  }) async {
    if (showLoading ?? _employeeLeaves.isEmpty) {
      _isLoadingEmployeeLeaves = true;
      notifyListeners();
    }

    final Map<String, LeaveBalanceModel> leaves = {};
    final Map<String, CompOffBalanceModel> compOff = {};
    final year = _year;
    // Every onboarded employee, whatever search or filter the employee
    // management screen has on
    final employees = empProvider.allEmployees
        .where((e) => e.isOnboarded)
        .toList();
    var missing = 0;
    // Employees whose leave document has no unpaid leave count yet (documents
    // made before unpaid leave existed)
    final needsUnpaid = <String>[];

    // One read per employee, ten at a time. Reading them one after another
    // made the section wait for every round trip in turn.
    for (var i = 0; i < employees.length; i += _parallelReads) {
      final end = i + _parallelReads > employees.length
          ? employees.length
          : i + _parallelReads;
      final batch = employees.sublist(i, end);

      // The year's document and the comp off credit of an employee are read
      // together
      final results = await Future.wait(
        batch.map((emp) async {
          try {
            final reads = await Future.wait([
              onboardingProvider.getUserLeaveAllocation(emp.id, year: year),
              _firestore
                  .collection(FirestoreCollections.users)
                  .doc(emp.id)
                  .collection(FirestoreSubCollections.leaves)
                  .doc(FirestoreDocs.compOffBalance)
                  .get(),
            ]);
            return (
              ok: true,
              data: reads[0] as Map<String, dynamic>?,
              compOff:
                  (reads[1] as DocumentSnapshot<Map<String, dynamic>>).data(),
            );
          } catch (_) {
            return (
              ok: false,
              data: null as Map<String, dynamic>?,
              compOff: null as Map<String, dynamic>?,
            );
          }
        }),
      );

      for (var j = 0; j < batch.length; j++) {
        final result = results[j];
        if (!result.ok) continue;
        compOff[batch[j].id] = result.compOff == null
            ? const CompOffBalanceModel()
            : CompOffBalanceModel.fromFirestore(result.compOff!);
        final data = result.data;
        if (data != null) {
          leaves[batch[j].id] = LeaveBalanceModel.fromFirestore(data);
          if (!data.containsKey('unpaidLeaves')) needsUnpaid.add(batch[j].id);
        } else {
          missing++;
        }
      }
    }

    // The prompt to assign leave is about this year only
    _missingLeaveCount = year == DateTime.now().year ? missing : 0;
    _employeeLeaves = leaves;
    _compOff = compOff;
    _isLoadingEmployeeLeaves = false;
    notifyListeners();

    if (needsUnpaid.isNotEmpty) {
      await _addUnpaidDefault(needsUnpaid, year);
    }
  }

  // Gives each of these employees' leave documents the unpaid leave count 0,
  // once. The screens already show a missing count as 0; this only makes the
  // stored data complete. A person without the right to write leave documents
  // simply skips it (the next admin to open the balances does it).
  Future<void> _addUnpaidDefault(List<String> employeeIds, int year) async {
    try {
      // A batch holds up to 500 writes
      for (var i = 0; i < employeeIds.length; i += 400) {
        final end = i + 400 > employeeIds.length ? employeeIds.length : i + 400;
        final batch = _firestore.batch();
        for (final id in employeeIds.sublist(i, end)) {
          batch.update(
            _firestore
                .collection(FirestoreCollections.users)
                .doc(id)
                .collection(FirestoreSubCollections.leaves)
                .doc(FirestoreDocs.annualLeave(year)),
            {
              'unpaidLeaves': {'used': 0},
            },
          );
        }
        await batch.commit();
      }
      debugPrint('Unpaid leave count 0 added to ${employeeIds.length} documents');
    } catch (e) {
      debugPrint('Could not add the unpaid leave default: $e');
    }
  }

  /// Days of [leaveType] ('pl', 'sl', 'cl', 'ul', 'co') that the employee's
  /// approved leave records add up to, in [year] (all years when null). The
  /// attendance history, calendar and exports follow these records, so the edit
  /// dialog shows this next to the used days. Null when it could not be read.
  Future<num?> recordedLeaveDays(
    String employeeId,
    String leaveType, {
    int? year,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(employeeId)
          .collection(FirestoreSubCollections.requests)
          .where('status', isEqualTo: AppConstants.statusApproved)
          .get();
      num total = 0;
      for (final doc in snapshot.docs) {
        final request = RequestModel.fromJson(doc.data());
        if (!request.isLeaveRequest) continue;
        if (request.leaveType?.toLowerCase() != leaveType) continue;
        final from = request.fromDate;
        if (from == null || (year != null && from.year != year)) continue;
        total += request.requestedDays;
      }
      return total;
    } catch (e) {
      debugPrint('Could not read the leave records: $e');
      return null;
    }
  }

  /// Corrects the comp off credit of an employee: days earned and days used.
  /// The balance is earned minus used (never below 0). Returns false when
  /// nothing was saved.
  Future<bool> updateCompOff(
    String employeeId, {
    required num earned,
    required num used,
    required EmployeeManagementProvider empProvider,
    required OnboardingProvider onboardingProvider,
  }) async {
    try {
      final balance = earned - used;
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(employeeId)
          .collection(FirestoreSubCollections.leaves)
          .doc(FirestoreDocs.compOffBalance)
          .set({
            'earned': earned,
            'used': used,
            'balance': balance < 0 ? 0 : balance,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _loadEmployeeLeaves(empProvider, onboardingProvider);
      return true;
    } catch (e) {
      debugPrint('Error updating comp off: $e');
      return false;
    }
  }

  /// Corrects the allocated and the used days of one leave type of the chosen
  /// year
  /// ('pl', 'sl', 'cl'), or only the days taken for unpaid leave ('ul'). The
  /// balance of the type and every total are worked out again from the saved
  /// document, so nothing is left out of step. PL carry forward stays in the
  /// balance. Returns false when nothing was saved.
  Future<bool> updateLeaveAllocation(
    String employeeId,
    String leaveType, {
    int? allocated,
    required num used,
    required EmployeeManagementProvider empProvider,
    required OnboardingProvider onboardingProvider,
  }) async {
    try {
      // The year chosen on the Leave Balances tab
      final docRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(employeeId)
          .collection(FirestoreSubCollections.leaves)
          .doc(FirestoreDocs.annualLeave(_year));

      const keys = {
        'pl': 'privilegeLeaves',
        'sl': 'sickLeaves',
        'cl': 'casualLeaves',
      };

      final saved = await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(docRef);
        final data = doc.data();
        if (data == null) return false;

        // Unpaid leave has no allocation or balance: only the days taken
        if (leaveType == 'ul') {
          transaction.update(docRef, {
            'unpaidLeaves.used': used,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        }

        final fieldKey = keys[leaveType];
        if (fieldKey == null || allocated == null) return false;

        // The types as they will be saved
        final types = <String, Map<String, num>>{};
        for (final key in keys.values) {
          final map = data[key] is Map
              ? Map<String, dynamic>.from(data[key] as Map)
              : <String, dynamic>{};
          num read(String name) => map[name] is num ? map[name] as num : 0;
          final isEdited = key == fieldKey;
          final typeAllocated = isEdited ? allocated : read('allocated');
          final typeUsed = isEdited ? used : read('used');
          final carryForward = read('carryForward');
          final balance = typeAllocated + carryForward - typeUsed;
          types[key] = {
            'allocated': typeAllocated,
            'used': typeUsed,
            'carryForward': carryForward,
            'balance': balance < 0 ? 0 : balance,
          };
        }

        num sum(String name) =>
            types.values.fold<num>(0, (total, t) => total + t[name]!);

        final edited = types[fieldKey]!;
        transaction.update(docRef, {
          '$fieldKey.allocated': edited['allocated'],
          '$fieldKey.used': edited['used'],
          '$fieldKey.balance': edited['balance'],
          // Carry forward counts in the allocation total, as at onboarding
          'totalAllocated': sum('allocated') + sum('carryForward'),
          'totalUsed': sum('used'),
          'totalBalance': sum('balance'),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });

      if (saved) {
        // Reload data
        await _loadEmployeeLeaves(empProvider, onboardingProvider);
      }
      return saved;
    } catch (e) {
      debugPrint('Error updating leave: $e');
      return false;
    }
  }
}
