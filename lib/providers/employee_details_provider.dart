import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_constants.dart';
import '../constants/firestore_constants.dart';
import '../constants/permissions.dart';
import '../models/security_settings_model.dart';
import '../models/user_model.dart';
import '../services/auth_security_service.dart';
import '../utils/logger.dart';

/// State of the employee details screen (one employee at a time): the loaded
/// user and security settings, whether the admin is editing, the values being
/// edited and the sub admin access being changed. Scoped to the screen.
class EmployeeDetailsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthSecurityService _securityService = AuthSecurityService();

  UserModel? _user;
  SecuritySettingsModel? _security;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSavingPermissions = false;

  // Values being edited (copied from the user when editing starts)
  DateTime? _joiningDate;
  String _department = '';
  String _role = '';
  String _employmentRole =
      AppConstants.employeeRole; // employee / intern / freelancer

  Set<String> _permissions = {};

  UserModel? get user => _user;
  SecuritySettingsModel? get security => _security;
  DeviceInfoModel? get device => _security?.deviceInfo;
  bool get isLoading => _isLoading;
  bool get isEditing => _isEditing;
  bool get isSavingPermissions => _isSavingPermissions;
  DateTime? get joiningDate => _joiningDate;
  String get department => _department;
  String get role => _role;
  String get employmentRole => _employmentRole;

  void setEmploymentRole(String? value) {
    if (value == null) return;
    _employmentRole = value;
    notifyListeners();
  }

  Set<String> get permissions => _permissions;

  Future<void> load(String employeeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(employeeId)
          .get();
      final data = doc.data();
      _user = data == null ? null : UserModel.fromJson(data);
      _security = await _securityService.getSecuritySettings(employeeId);

      final granted = data?[Permissions.field];
      _permissions = granted is List ? Set<String>.from(granted) : {};
      _syncDraftFromUser();
    } catch (e) {
      logDebug('Error loading employee details: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void _syncDraftFromUser() {
    _joiningDate = _user?.joiningDate;
    _department = _user?.department ?? '';
    _role = _user?.jobRole ?? '';
    _employmentRole = AppConstants.assignableRoles.contains(_user?.role)
        ? _user!.role!
        : AppConstants.employeeRole;
  }

  // --- Editing ---

  void startEditing() {
    _syncDraftFromUser();
    _isEditing = true;
    notifyListeners();
  }

  /// Leaves edit mode and discards the edited values.
  void stopEditing() {
    _syncDraftFromUser();
    _isEditing = false;
    notifyListeners();
  }

  void setJoiningDate(DateTime date) {
    _joiningDate = date;
    notifyListeners();
  }

  /// Changing the department clears the role, which belongs to it.
  void setDepartment(String? value) {
    _department = value ?? '';
    _role = '';
    notifyListeners();
  }

  void setRole(String? value) {
    _role = value ?? '';
    notifyListeners();
  }

  // --- Sub admin access ---

  void setPermission(String permission, bool granted) {
    if (granted) {
      _permissions.add(permission);
    } else {
      _permissions.remove(permission);
    }
    notifyListeners();
  }

  void setAllPermissions(bool all) {
    _permissions = all ? Permissions.all.toSet() : <String>{};
    notifyListeners();
  }

  Future<bool> savePermissions(String employeeId) async {
    _isSavingPermissions = true;
    notifyListeners();

    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(employeeId)
          .update({Permissions.field: _permissions.toList()});
      return true;
    } catch (e) {
      logDebug('Error saving sub admin access: $e');
      return false;
    } finally {
      _isSavingPermissions = false;
      notifyListeners();
    }
  }

  // --- Device binding ---

  /// Clears the binding so the employee's next login registers a new device.
  Future<bool> resetDevice(String employeeId) async {
    try {
      final userRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(employeeId);
      final batch = _firestore.batch();
      batch.update(userRef, {FirestoreFields.isFirstLogin: false});
      batch.set(
        userRef
            .collection(FirestoreSubCollections.security)
            .doc(FirestoreDocs.securitySettings),
        {FirestoreFields.deviceInfo: FieldValue.delete()},
        SetOptions(merge: true),
      );
      await batch.commit();
      await load(employeeId);
      return true;
    } catch (e) {
      logDebug('Error resetting device: $e');
      return false;
    }
  }
}
