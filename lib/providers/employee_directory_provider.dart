import 'package:flutter/material.dart';
import '../models/employee_model.dart';

/// Search, department / role filters and sort of the employee directory table
/// on the Info tab. The employees themselves come from
/// [EmployeeManagementProvider]. Scoped to the screen.
class EmployeeDirectoryProvider with ChangeNotifier {
  String _search = '';
  String? _department;
  String? _role;
  bool _sortAscending = true;

  String get search => _search;
  String? get department => _department;
  String? get role => _role;
  bool get sortAscending => _sortAscending;

  void setSearch(String value) {
    _search = value.trim().toLowerCase();
    notifyListeners();
  }

  void setDepartment(String? value) {
    _department = value;
    // A role belongs to a department, so it is cleared with it
    _role = null;
    notifyListeners();
  }

  void setRole(String? value) {
    _role = value;
    notifyListeners();
  }

  void setSortAscending(bool value) {
    _sortAscending = value;
    notifyListeners();
  }

  void clear() {
    _search = '';
    _department = null;
    _role = null;
    notifyListeners();
  }

  /// Roles that exist among the employees of the chosen department.
  List<String> rolesFor(List<EmployeeModel> employees) {
    final roles = employees
        .where((e) => _department == null || e.department == _department)
        .map((e) => e.jobRole)
        .whereType<String>()
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();
    roles.sort();
    return roles;
  }

  List<EmployeeModel> apply(List<EmployeeModel> employees) {
    final result = employees.where((e) {
      if (_department != null && e.department != _department) return false;
      if (_role != null && e.jobRole != _role) return false;
      if (_search.isEmpty) return true;
      final haystack = [
        e.name,
        e.employeeId ?? '',
        e.department ?? '',
        e.jobRole ?? '',
        e.email,
        e.mobileNumber ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(_search);
    }).toList();

    result.sort(
      (a, b) => _sortAscending
          ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
          : b.name.toLowerCase().compareTo(a.name.toLowerCase()),
    );
    return result;
  }
}
