import 'package:flutter/material.dart';
import '../models/request_model.dart';

/// Stream and filters (search text, leave type, status) of a request list
/// screen: the employee's leave history and the admin's leave requests.
/// Scoped to the screen.
class RequestFilterProvider with ChangeNotifier {
  Stream<List<RequestModel>>? _stream;
  String _searchQuery = '';
  String _selectedLeaveType = 'All';
  String _selectedStatus = 'All';

  Stream<List<RequestModel>>? get stream => _stream;

  /// Lower-cased and trimmed.
  String get searchQuery => _searchQuery;
  String get selectedLeaveType => _selectedLeaveType;
  String get selectedStatus => _selectedStatus;

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
}
