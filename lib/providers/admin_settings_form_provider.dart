import 'package:flutter/material.dart';
import '../models/leave_config_model.dart';
import '../models/office_hours_model.dart';

/// Form state of the admin page's settings sections (leave defaults, office
/// hours, new year leave assignment). The saved values live in
/// [OrganizationProvider]; this holds what the admin is editing. Scoped to the
/// admin page.
class AdminSettingsFormProvider with ChangeNotifier {
  // Leave configuration form
  bool _carryForwardPL = false;
  bool _carryForwardCompOff = false;
  bool _leaveConfigInitialized = false;

  // Office hours form
  TimeOfDay? _officeStart;
  TimeOfDay? _officeEnd;
  int? _lateAfter;
  int? _halfDayAfter;
  bool _officeHoursInitialized = false;

  bool _isAssigningLeaves = false;

  bool get carryForwardPL => _carryForwardPL;
  bool get carryForwardCompOff => _carryForwardCompOff;
  bool get leaveConfigInitialized => _leaveConfigInitialized;
  TimeOfDay? get officeStart => _officeStart;
  TimeOfDay? get officeEnd => _officeEnd;
  int? get lateAfter => _lateAfter;
  int? get halfDayAfter => _halfDayAfter;
  bool get officeHoursInitialized => _officeHoursInitialized;
  bool get isAssigningLeaves => _isAssigningLeaves;

  /// Fills the leave form once from the saved config; no notification because
  /// it runs while the section is being built.
  void initLeaveConfig(LeaveConfigModel? config) {
    if (_leaveConfigInitialized) return;
    _carryForwardPL = config?.carryForwardPL ?? false;
    _carryForwardCompOff = config?.carryForwardCompOff ?? false;
    _leaveConfigInitialized = true;
  }

  /// Fills the office hours form once from the saved values (silent, see above).
  void initOfficeHours(OfficeHoursModel? saved) {
    if (_officeHoursInitialized) return;
    _officeStart = saved?.startTime;
    _officeEnd = saved?.endTime;
    _lateAfter = saved?.lateAfterMinutes;
    _halfDayAfter = saved?.halfDayAfterMinutes;
    _officeHoursInitialized = true;
  }

  void setCarryForwardPL(bool value) {
    _carryForwardPL = value;
    notifyListeners();
  }

  void setCarryForwardCompOff(bool value) {
    _carryForwardCompOff = value;
    notifyListeners();
  }

  void setOfficeStart(TimeOfDay time) {
    _officeStart = time;
    notifyListeners();
  }

  void setOfficeEnd(TimeOfDay time) {
    _officeEnd = time;
    notifyListeners();
  }

  /// Minutes typed in the "late after" / "half day after" boxes, for the
  /// preview line. Blank or invalid text means the rule is not used.
  void setLateAfterText(String text) {
    _lateAfter = int.tryParse(text.trim());
    notifyListeners();
  }

  void setHalfDayAfterText(String text) {
    _halfDayAfter = int.tryParse(text.trim());
    notifyListeners();
  }

  void setAssigningLeaves(bool value) {
    _isAssigningLeaves = value;
    notifyListeners();
  }
}
