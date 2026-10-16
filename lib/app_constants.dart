// Firestore collection / subcollection / document names and the saved shape of
// each document live in constants/firestore_constants.dart, not here.
class AppConstants {
  static const String adminCode = "myadmin";

  // Request types
  static const String requestTypeLeave = "leave";
  static const String requestTypeWFH = "wfh";
  static const String requestTypeBreak = "break";

  // Comp off: an employee asks for credit for a day they worked (holiday /
  // weekly off). On approval the credit is added to their comp off balance.
  static const String requestTypeCompOff = "comp_off";

  // Notification types
  static const String leaveRequestNotification = "LEAVE_REQUEST";
  static const String wfhRequestNotification = "WFH_REQUEST";
  static const String breakRequestNotification = "BREAK_REQUEST";
  static const String leaveStatusUpdateNotification = "LEAVE_STATUS_UPDATE";
  static const String requestStatusUpdateNotification = "REQUEST_STATUS_UPDATE";
  static const String punchInNotification = "PUNCH_IN";
  static const String punchOutNotification = "PUNCH_OUT";

  // Request/Leave status
  static const String statusPending = "pending";
  static const String statusApproved = "approved";
  static const String statusRejected = "rejected";

  // Attendance status
  static const String statusPresent = "present";
  static const String statusAbsent = "absent";
  static const String statusHalfDay = "half-day";
  static const String statusOnLeave = "on-leave";

  // User roles
  static const String adminRole = "admin";
  static const String employeeRole = "employee";
  static const String internRole = "intern";
  static const String freelancerRole = "freelancer";

  /// Roles an admin can give when adding / editing someone (a sub admin is an
  /// employee with isSubAdmin on).
  static const List<String> assignableRoles = [
    employeeRole,
    internRole,
    freelancerRole,
  ];

  /// Leave type filter values and how the dropdowns show them.
  static const Map<String, String> leaveFilterLabels = {
    'All': 'All',
    'PL': 'PL (Privilege Leave)',
    'SL': 'SL (Sick Leave)',
    'CL': 'CL (Casual Leave)',
    'CO': 'CO (Compensatory Off)',
  };

  static String roleLabel(String? role) {
    switch (role) {
      case adminRole:
        return 'Admin';
      case internRole:
        return 'Intern';
      case freelancerRole:
        return 'Freelancer';
      case employeeRole:
        return 'Employee';
      default:
        return role == null || role.isEmpty ? 'Employee' : role;
    }
  }

  // Leave types
  static const String leaveTypePL = "pl"; // Privilege Leave / Paid Leave
  static const String leaveTypeSL = "sl"; // Sick Leave
  static const String leaveTypeCL = "cl"; // Casual Leave
  static const String leaveTypeCO = "co"; // Comp Off (taken from earned credit)

  // Entry in the leave type dropdown that opens the "apply comp off" form.
  // It is never saved as a leave type.
  static const String applyCompOffOption = "apply_comp_off";

  // Notification type for a comp off request
  static const String compOffRequestNotification = "COMP_OFF_REQUEST";
}
