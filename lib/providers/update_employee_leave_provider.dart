import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../models/past_request_entry.dart';
import 'request_provider.dart';

/// State of the Update Employee Leaves page: the chosen employee, the records
/// HR has added so far (not saved until Update is pressed) and the saving
/// flag. Scoped to the page.
class UpdateEmployeeLeaveProvider with ChangeNotifier {
  EmployeeModel? _employee;
  final List<PastRequestEntry> _entries = [];
  bool _isSaving = false;

  // Changes when a record is added, so the add form starts empty again
  int _formVersion = 0;

  EmployeeModel? get employee => _employee;
  List<PastRequestEntry> get entries => List.unmodifiable(_entries);
  bool get isSaving => _isSaving;
  int get formVersion => _formVersion;

  /// The records grouped by kind, in the order of [PastRequestKind], leaving
  /// out kinds with no record.
  Map<PastRequestKind, List<PastRequestEntry>> get sections => {
    for (final kind in PastRequestKind.values)
      if (_entries.any((e) => e.kind == kind))
        kind: _entries.where((e) => e.kind == kind).toList(),
  };

  /// Choosing another employee drops the records of the previous one.
  void selectEmployee(EmployeeModel? employee) {
    _employee = employee;
    _entries.clear();
    _formVersion++;
    notifyListeners();
  }

  void addEntry(PastRequestEntry entry) {
    _entries.add(entry);
    _formVersion++;
    notifyListeners();
  }

  void updateEntry(PastRequestEntry entry) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) return;
    _entries[index] = entry;
    notifyListeners();
  }

  void removeEntry(String id) {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Saves every record on the employee. On success the list is cleared.
  Future<PastRequestsResult> save(RequestProvider requests) async {
    final employee = _employee;
    if (employee == null) {
      return const PastRequestsResult.failure('Select an employee');
    }
    if (_entries.isEmpty) {
      return const PastRequestsResult.failure('Add at least one record');
    }

    _isSaving = true;
    notifyListeners();

    final result = await requests.addPastRequests(
      userId: employee.id,
      userName: employee.name,
      entries: List.of(_entries),
    );

    _isSaving = false;
    if (result.isSuccess) {
      _entries.clear();
      _formVersion++;
    }
    notifyListeners();
    return result;
  }
}
