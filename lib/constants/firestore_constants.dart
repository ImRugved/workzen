// =============================================================================
// FIRESTORE STRUCTURE: single source of truth
//
// Every collection, subcollection and fixed document name used in code comes
// from this file. Never type a Firestore path string in a provider, service or
// screen. This file also records what each document looks like when saved.
//
// KEEP IN SYNC: whenever code adds, renames or removes a collection, document
// or field, update this file in the same change (the tree and the JSON below),
// then firestore.rules and firestore.indexes.json if access or queries changed.
// See CLAUDE.md.
// =============================================================================
//
// TREE
//
// users/{uid}
//   ├─ requests/{requestId}            leave / WFH / break requests
//   ├─ leaves/annual_{year}            yearly leave allocation and balances
//   ├─ leaves/comp_off                 comp off credit (earned / used / balance), not reset yearly
//   ├─ security/settings               app-unlock PIN, biometric flag, registered device
//   └─ attendance_summary/{yyyy-MM}    one document per month: day lists, counts, per-day detail
// attendance/{attendanceId}            one punch record per user per day
// departments/{departmentId}           departments and their roles
// organization_details                 org-wide settings, readable by every signed-in user
//   ├─ leave_config                    default PL / SL / CL allocation
//   ├─ office_hours                    start / end time and late / half-day rules
//   ├─ holidays/items/{holidayId}      holiday calendar
//   └─ birthdays/items/{uid}           month and day of each employee's birthday (no year),
//                                      written by the employee when they save their date of birth
// notifications                       reserved, not used yet
//
// =============================================================================
// DOCUMENT SHAPES (JSON as saved)
//
// users/{uid}                                   (UserModel, EmployeeManagementProvider.addEmployee)
// {
//   "id": "uid", "userId": "uid",
//   "name": "Rugved", "email": "a@b.com", "mobileNumber": "9876543210",
//   "fcmToken": "device push token or ''",
//   "isAdmin": false,
//   "isSubAdmin": false,
//   "subAdminPermissions": ["add_employee", "office_hours"],   // see Permissions; only an admin writes it
//   "isFirstLogin": false,                       // false until first login registers the device
//   "profileImageUrl": "https://... or null",
//   "employeeId": "002", "department": "HR", "role": "employee",
//   "jobRole": "Recruiter",                      // position picked from departments/{id}.roles
//                                                // (Mobile Dev, Backend Dev ...)
//                                                // role above is the employment type: "admin",
//                                                // "employee", "intern" or "freelancer"
//                                                // (a sub admin is isSubAdmin: true)
//   "createdAt": Timestamp, "joiningDate": "ISO-8601 string" | Timestamp,
//   "isOnboarded": false,                        // true after leave allocation is created
//   "onboardingDate": Timestamp, "joiningMonth": 2, "joiningYear": 2026,
//   "isPrivilegeLeave": true, "isCasualLeave": true,
//   "isSickLeave": true,                         // leave types enabled at onboarding; a type
//                                                // that is off is not in the apply-leave list
//                                                // (missing means on for sick leave)
//   "totalExperience": "3", "emergencyContactNumber": "98...",
//   "address": "...", "alternateNumber": "...", "bloodGroup": "O+",
//   "dateOfBirth": Timestamp,                    // date only, set by the employee on the profile
//   "gender": "Male" | "Female" | "Other",       // set by the employee; words the birthday greeting
//   "aadharNumber": "...", "panCardNumber": "...",              // admin-only details
//   "officeLatitude": 18.5679456, "officeLongitude": 73.7686132 // punch geofence centre
// }
//
// users/{uid}/requests/{requestId}              (RequestModel)
// {
//   "id": "uuid", "userId": "uid", "userName": "Rugved",
//   "type": "leave" | "wfh" | "break" | "comp_off",
//   "reason": "...", "status": "pending" | "approved" | "rejected",
//   "appliedOn": Timestamp,
//   "fromDate": Timestamp, "toDate": Timestamp,  // leave and wfh
//   "date": Timestamp,                           // break; for comp_off the day worked
//   "shift": "Full Day" | "Half Day" | "First Half" | "Second Half",
//   "adminRemark": "...",
//   "additionalData": { "leaveType": "pl" | "sl" | "cl" | "co" }   // type leave ("co" = taken from comp off)
//   // type comp_off: "additionalData": { "days": 1 | 0.5, "compOffDate": "2026-10-19T00:00:00.000",
//   //   "fromTime": "10:00", "toTime": "14:00" }   (fromTime/toTime only for a half day).
//   //   "date" is the day worked, "compOffDate" the day off asked for in return (after "date").
//   //   Approving it earns and uses "days" in leaves/comp_off (balance unchanged) and the
//   //   calendar shows "Comp off" on compOffDate. Older requests without compOffDate only
//   //   add "days" to the balance.
// }
// An employee creates it as "pending" and cannot change status; only an admin or a
// sub admin with the leave_requests permission decides it (see firestore.rules).
//
// users/{uid}/leaves/annual_{year}              (OnboardingProvider, RequestProvider)
// {
//   "year": 2026, "joiningMonth": 2,
//   "privilegeLeaves": { "allocated": 12, "carryForward": 0, "used": 0, "balance": 12 },
//   "sickLeaves":      { "allocated": 9,  "used": 0, "balance": 9 },
//   "casualLeaves":    { "allocated": 7,  "used": 0, "balance": 7 },
//   "totalAllocated": 28, "totalUsed": 0, "totalBalance": 28,
//   "createdAt": Timestamp, "updatedAt": Timestamp
// }
//
// users/{uid}/leaves/comp_off                   (RequestProvider; written only on approval)
// { "earned": 3.5, "used": 1, "balance": 2.5, "lastResetYear": 2027, "updatedAt": Timestamp }
//   earned += days when a comp_off request is approved;
//   used += days and balance -= days when a leave with leaveType "co" is approved;
//   balance is set to 0 (lastResetYear) when next year's leave is assigned and
//   carryForwardCompOff is off.
//
// Balance shown to the employee when applying (not stored): the "balance" of the
// leave type minus the days of that type held by the user's pending requests.
// Applying lowers it at once, approval keeps it lowered (the balance is deducted),
// rejecting or withdrawing gives it back (the pending request disappears).
//
// users/{uid}/security/settings                 (AuthSecurityService, AuthProvider)
// {
//   "appUnlockPin": "123456", "hasAppUnlockPin": true,
//   "biometricEnabled": false,
//   "deviceInfo": {                              // set on first login
//     "deviceId": "0f17...", "platform": "android",
//     "manufacturer": "samsung", "model": "SM-A546E", "osVersion": "14",
//     "registeredAt": Timestamp
//   },
//   "updatedAt": Timestamp
// }
//
// users/{uid}/attendance_summary/{yyyy-MM}      (MonthlyAttendanceSummary)
// {
//   "year": 2026, "month": 10,
//   "presentDays": [1, 2, 5], "absentDays": [6], "leaveDays": [], "compOffDays": [],
//   "halfDays": [], "lateDays": [3], "wfhDays": [], "holidayDays": [2], "weekendDays": [4, 5],
//   "counts": { "present": 3, "absent": 1, "leave": 0, "compOff": 0, "halfDay": 0, "late": 1, "wfh": 0, "holiday": 1, "weekend": 2 },
//   "days": {
//     "3": { "status": "late", "label": "Late", "punchIn": Timestamp, "punchOut": Timestamp, "punchStatus": "late" }
//   },
//   "builtOn": "2026-10-16",                     // day it was last rebuilt, used to know if it is stale
//   "updatedAt": Timestamp
// }
//
// attendance/{attendanceId}                     (AttendanceModel)
// {
//   "id": "uuid", "userId": "uid", "userName": "Rugved",
//   "date": Timestamp (midnight),
//   "punchInTime": Timestamp | null, "punchOutTime": Timestamp | null,
//   "status": "pending" | "present" | "absent" | "half-day" | "on-leave",
//   // an employee can only write "pending" (punch in) or "present" (punch out);
//   // "absent" is written by an admin
//   "leaveId": null,
//   "location": { "lat": 18.56, "lng": 73.76 }
// }
//
// departments/{departmentId}                    (DepartmentModel)
// { "id": "...", "name": "HR", "roles": ["Manager", "Recruiter"], "createdAt": Timestamp }
//
// organization_details/leave_config             (OrganizationProvider)
// {
//   "privilegeLeaves": 12, "sickLeaves": 10, "casualLeaves": 8,
//   "carryForwardPL": false,          // true: unused PL moves to next year; false: resets to 0
//   "carryForwardCompOff": false,     // true: comp off credit is kept; false: reset to 0
//   "updatedAt": Timestamp            // SL and CL always reset when next year's leave is assigned
// }
//
// organization_details/office_hours             (OfficeHoursModel, OrganizationProvider)
// {
//   "startTime": "10:00", "endTime": "19:00",
//   "lateAfterMinutes": 25 | null,               // punch in later than this is "late"
//   "halfDayAfterMinutes": 40 | null,            // later than this is a half day
//   "updatedAt": Timestamp
// }
//
// organization_details/holidays/items/{holidayId}   (HolidayModel)
// { "id": "uuid", "name": "Independence Day", "date": Timestamp (midnight),
//   "description": "optional", "createdAt": Timestamp }
//
// organization_details/birthdays/items/{uid}        (BirthdayModel)
// { "userId": "uid", "name": "Rugved", "gender": "Male" | "Female" | "Other" | null,
//   "month": 10, "day": 30,
//   "monthDay": "10-30",                       // queried with == to find today's birthdays
//   "updatedAt": Timestamp }
// =============================================================================

/// Top-level collections.
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String attendance = 'attendance';
  static const String departments = 'departments';
  static const String organizationDetails = 'organization_details';
  static const String notifications = 'notifications';
}

/// Subcollection names (nested under a document of a parent collection).
class FirestoreSubCollections {
  FirestoreSubCollections._();

  // users/{uid}/...
  static const String requests = 'requests';
  static const String leaves = 'leaves';
  static const String security = 'security';
  static const String attendanceSummary = 'attendance_summary';

  // organization_details/holidays/...
  static const String holidayItems = 'items';

  // organization_details/birthdays/...
  static const String birthdayItems = 'items';
}

/// Field names used in code on users/{uid} and users/{uid}/security/settings.
class FirestoreFields {
  FirestoreFields._();

  /// false until the user's first login registers their device, then true.
  static const String isFirstLogin = 'isFirstLogin';

  /// Lives in users/{uid}/security/settings next to the PIN and biometric flag.
  /// Map: deviceId, platform, manufacturer, model, osVersion, registeredAt.
  static const String deviceInfo = 'deviceInfo';
  static const String deviceId = 'deviceId';
}

/// Fixed document ids.
class FirestoreDocs {
  FirestoreDocs._();

  // users/{uid}/security/...
  static const String securitySettings = 'settings';

  // organization_details/...
  static const String leaveConfig = 'leave_config';
  static const String officeHours = 'office_hours';
  static const String holidays = 'holidays';
  static const String birthdays = 'birthdays';

  /// users/{uid}/leaves/annual_{year}
  static String annualLeave(int year) => 'annual_$year';

  /// users/{uid}/leaves/comp_off : comp off credit, not reset each year
  static const String compOffBalance = 'comp_off';

  /// users/{uid}/attendance_summary/{yyyy-MM}
  static String monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
}
