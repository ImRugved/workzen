class AppConstants {
  static const String adminCode = "myadmin";
  static const String userCollection = "users";
  static const String userRequestsCollection =
      "requests"; // Subcollection under users
  static const String attendanceCollection = "attendance";

  // Request types
  static const String requestTypeLeave = "leave";
  static const String requestTypeWFH = "wfh";
  static const String requestTypeBreak = "break";

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

  // Collections
  static const String usersCollection = "users";
  static const String notificationsCollection = "notifications";
  static const String leavesCollection = "leaves";
  static const String departmentsCollection = "departments";
  static const String settingsCollection = "settings";
  static const String leaveDefaultsDoc = "leave_defaults";

  // Leave types
  static const String leaveTypePL = "pl"; // Privilege Leave / Paid Leave
  static const String leaveTypeSL = "sl"; // Sick Leave
  static const String leaveTypeCL = "cl"; // Casual Leave
}
