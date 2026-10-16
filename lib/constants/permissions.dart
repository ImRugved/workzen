/// Access an admin can grant to a sub admin. Stored on the sub admin's user
/// document as `subAdminPermissions` (a list of these keys). Admins always have
/// every permission.
class Permissions {
  Permissions._();

  static const String addEmployee = 'add_employee';
  static const String manageEmployees = 'manage_employees';
  static const String onboarding = 'onboarding';
  static const String leaveRequests = 'leave_requests';
  static const String viewAttendance = 'view_attendance';
  static const String leaveConfig = 'leave_config';
  static const String officeHours = 'office_hours';
  static const String holidays = 'holidays';
  static const String departments = 'departments';

  static const String field = 'subAdminPermissions';

  /// Display order and labels for the permission pickers.
  static const Map<String, String> labels = {
    addEmployee: 'Add employees',
    manageEmployees: 'View and edit employees',
    onboarding: 'Employee onboarding',
    leaveRequests: 'Approve leave requests',
    viewAttendance: 'View employee attendance',
    leaveConfig: 'Leave counts (default leave settings)',
    officeHours: 'Office hours and late rules',
    holidays: 'Holiday calendar',
    departments: 'Departments and roles',
  };

  static List<String> get all => labels.keys.toList();
}
