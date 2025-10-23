class AppConstants {
  static const String adminCode = "myadmin";
  static const String userCollection = "users";
  static const String leaveCollection = "leaves";
  static const String attendanceCollection = "attendance";

  // Notification types
  static const String leaveRequestNotification = "LEAVE_REQUEST";
  static const String leaveStatusUpdateNotification = "LEAVE_STATUS_UPDATE";
  static const String punchInNotification = "PUNCH_IN";
  static const String punchOutNotification = "PUNCH_OUT";

  // Leave status
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
}
