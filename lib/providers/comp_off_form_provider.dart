import 'package:flutter/material.dart';

/// State of the comp off request form: the day worked, full or half day, and
/// for a half day the time worked. Scoped to the form.
class CompOffFormProvider with ChangeNotifier {
  DateTime _workedDate = DateTime.now();
  // The day off asked for in return; defaults to the day after the day worked
  DateTime _compOffDate = DateTime.now().add(const Duration(days: 1));
  bool _isHalfDay = false;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  bool _isSubmitting = false;

  DateTime get workedDate => _workedDate;
  bool get isHalfDay => _isHalfDay;
  TimeOfDay? get fromTime => _fromTime;
  TimeOfDay? get toTime => _toTime;
  bool get isSubmitting => _isSubmitting;

  DateTime get compOffDate => _compOffDate;

  void setWorkedDate(DateTime date) {
    _workedDate = date;
    // The day off has to come after the day worked
    if (!_compOffDate.isAfter(date)) {
      _compOffDate = date.add(const Duration(days: 1));
    }
    notifyListeners();
  }

  void setCompOffDate(DateTime date) {
    _compOffDate = date;
    notifyListeners();
  }

  void setHalfDay(bool value) {
    _isHalfDay = value;
    notifyListeners();
  }

  void setFromTime(TimeOfDay time) {
    _fromTime = time;
    notifyListeners();
  }

  void setToTime(TimeOfDay time) {
    _toTime = time;
    notifyListeners();
  }

  void setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Error message for the half day times, or null when they are valid.
  String? get timeError {
    if (!_isHalfDay) return null;
    if (_fromTime == null || _toTime == null) {
      return 'Select the time you worked';
    }
    if (_minutes(_toTime!) <= _minutes(_fromTime!)) {
      return 'End time must be after start time';
    }
    return null;
  }
}
