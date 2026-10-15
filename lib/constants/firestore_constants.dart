/// Single source of truth for the Firestore structure used by the app.
///
/// users/{uid}
///   ├─ requests/{requestId}          leave / WFH / break requests
///   ├─ leaves/annual_{year}          yearly leave allocation + balances
///   └─ security/settings             app-unlock PIN, biometric flag, registered deviceInfo
/// attendance/{attendanceId}
/// departments/{departmentId}
/// organization_details               org-wide data, readable by all employees
///   ├─ leave_config                  default PL / SL / CL allocation
///   └─ holidays/items/{holidayId}    holiday calendar
/// notifications                      reserved, not used yet
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

  // organization_details/holidays/...
  static const String holidayItems = 'items';
}

/// Field names on the users/{uid} document used for device binding.
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
  static const String holidays = 'holidays';

  /// users/{uid}/leaves/annual_{year}
  static String annualLeave(int year) => 'annual_$year';
}
