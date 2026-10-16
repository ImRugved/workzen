import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

/// State of the admin's employee attendance screen: the live attendance
/// stream, the date and employee filters, the employee list and the busy
/// flag. Scoped to the screen.
class AdminAttendanceFilterProvider with ChangeNotifier {
  Stream<List<AttendanceModel>>? _stream;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  String? _selectedEmployeeId;
  List<UserModel> _employees = [];

  Stream<List<AttendanceModel>>? get stream => _stream;
  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;
  String? get selectedEmployeeId => _selectedEmployeeId;
  List<UserModel> get employees => _employees;

  void setStream(Stream<List<AttendanceModel>>? stream) {
    _stream = stream;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setSelectedEmployee(String? employeeId) {
    _selectedEmployeeId = employeeId;
    notifyListeners();
  }

  void setEmployees(List<UserModel> employees) {
    _employees = employees;
    notifyListeners();
  }

  /// Attendance of the selected date (and employee, when one is chosen).
  List<AttendanceModel> filter(List<AttendanceModel> attendanceList) {
    return attendanceList.where((attendance) {
      final isSameDate =
          attendance.date.year == _selectedDate.year &&
          attendance.date.month == _selectedDate.month &&
          attendance.date.day == _selectedDate.day;

      final isSelectedEmployee =
          _selectedEmployeeId == null ||
          attendance.userId == _selectedEmployeeId;

      return isSameDate && isSelectedEmployee;
    }).toList();
  }
}
