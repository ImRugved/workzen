import 'package:flutter/material.dart';
import '../models/request_model.dart';
import '../utils/leave_month_utils.dart';

/// Stream and filters (search text, leave type, status, month, employee) of a
/// request list screen: the employee's leave history and the admin's leave
/// requests. Scoped to the screen.
class RequestFilterProvider with ChangeNotifier {
  /// Value of the month and employee filters that matches everything.
  static const String all = 'All';

  Stream<List<RequestModel>>? _stream;
  String _searchQuery = '';
  String _selectedLeaveType = 'All';
  String _selectedStatus = 'All';
  String _selectedMonth = all; // 'yyyy-MM' or all
  String _selectedEmployee = all; // user id or all

  Stream<List<RequestModel>>? get stream => _stream;

  /// Lower-cased and trimmed.
  String get searchQuery => _searchQuery;
  String get selectedLeaveType => _selectedLeaveType;
  String get selectedStatus => _selectedStatus;
  String get selectedMonth => _selectedMonth;
  String get selectedEmployee => _selectedEmployee;

  /// 'yyyy-MM' key of the month a request is counted in.
  static String monthKey(RequestModel r) {
    final day = requestStartDay(r);
    return '${day.year}-${day.month.toString().padLeft(2, '0')}';
  }

  /// Whether a request passes the month and employee filters.
  bool matchesMonthAndEmployee(RequestModel r) =>
      (_selectedMonth == all || monthKey(r) == _selectedMonth) &&
      (_selectedEmployee == all || r.userId == _selectedEmployee);

  void setStream(Stream<List<RequestModel>>? stream) {
    _stream = stream;
    notifyListeners();
  }

  void setSearch(String text) {
    _searchQuery = text.toLowerCase().trim();
    notifyListeners();
  }

  void setLeaveType(String type) {
    _selectedLeaveType = type;
    notifyListeners();
  }

  void setStatus(String status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setMonth(String month) {
    _selectedMonth = month;
    notifyListeners();
  }

  void setEmployee(String userId) {
    _selectedEmployee = userId;
    notifyListeners();
  }
}
