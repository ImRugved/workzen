import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee_model.dart';
import '../app_constants.dart';

class EmployeeManagementProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<EmployeeModel> _employees = [];
  List<EmployeeModel> _filteredEmployees = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _errorMessage;

  // Getters
  List<EmployeeModel> get employees => _filteredEmployees;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;

  // Fetch all employees (non-admin users)
  Future<void> fetchAllEmployees() async {
    try {
      _setLoading(true);
      _errorMessage = null;

      QuerySnapshot querySnapshot;

      try {
        // Try the optimized query with ordering first
        querySnapshot = await _firestore
            .collection(AppConstants.userCollection)
            .where('isAdmin', isEqualTo: false)
            .orderBy('name')
            .get();
      } catch (indexError) {
        // If index error occurs, fall back to simple query without ordering
        if (indexError.toString().contains('failed-precondition') ||
            indexError.toString().contains('index')) {
          print('Index not available, using fallback query');
          querySnapshot = await _firestore
              .collection(AppConstants.userCollection)
              .where('isAdmin', isEqualTo: false)
              .get();
        } else {
          // Re-throw if it's not an index error
          rethrow;
        }
      }

      _employees = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID
        return EmployeeModel.fromJson(data);
      }).toList();

      // Sort manually if we used the fallback query
      _employees.sort((a, b) => a.name.compareTo(b.name));

      _filteredEmployees = List.from(_employees);
      notifyListeners();
    } catch (e) {
      _errorMessage = _getUserFriendlyErrorMessage(e);
      print('Error fetching employees: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Search employees by name or email
  void searchEmployees(String query) {
    _searchQuery = query.toLowerCase();

    if (_searchQuery.isEmpty) {
      _filteredEmployees = List.from(_employees);
    } else {
      _filteredEmployees = _employees.where((employee) {
        return employee.name.toLowerCase().contains(_searchQuery) ||
            employee.email.toLowerCase().contains(_searchQuery) ||
            (employee.employeeId?.toLowerCase().contains(_searchQuery) ??
                false);
      }).toList();
    }

    notifyListeners();
  }

  // Update employee information
  Future<bool> updateEmployee({
    required String employeeId,
    String? employeeIdValue,
    String? department,
    DateTime? joiningDate,
    String? address,
    String? mobileNumber,
    String? alternateNumber,
    String? bloodGroup,
    String? aadharNumber,
    String? panCardNumber,
  }) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      Map<String, dynamic> updateData = {};

      if (employeeIdValue != null) {
        updateData['employeeId'] = employeeIdValue;
      }

      if (department != null) {
        updateData['department'] = department;
      }

      if (joiningDate != null) {
        updateData['joiningDate'] = joiningDate.toIso8601String();
      }

      // Personal and Contact info - only update if provided (user manages these)
      // Admin cannot edit these fields, so they should always be null from admin screen
      if (address != null && address.isNotEmpty) {
        updateData['address'] = address;
      }
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        updateData['mobileNumber'] = mobileNumber;
      }
      if (alternateNumber != null && alternateNumber.isNotEmpty) {
        updateData['alternateNumber'] = alternateNumber;
      }
      if (bloodGroup != null && bloodGroup.isNotEmpty) {
        updateData['bloodGroup'] = bloodGroup;
      }

      // Admin-only fields - always update even if empty
      if (aadharNumber != null) {
        updateData['aadharNumber'] = aadharNumber;
      }
      if (panCardNumber != null) {
        updateData['panCardNumber'] = panCardNumber;
      }

      if (updateData.isNotEmpty) {
        await _firestore
            .collection(AppConstants.userCollection)
            .doc(employeeId)
            .update(updateData);

        // Update local data
        final employeeIndex = _employees.indexWhere(
          (emp) => emp.id == employeeId,
        );
        if (employeeIndex != -1) {
          _employees[employeeIndex] = _employees[employeeIndex].copyWith(
            employeeId: employeeIdValue ?? _employees[employeeIndex].employeeId,
            department: department ?? _employees[employeeIndex].department,
            joiningDate: joiningDate ?? _employees[employeeIndex].joiningDate,
          );

          // Update filtered list as well
          searchEmployees(_searchQuery);
        }

        return true;
      }

      return false;
    } catch (e) {
      _errorMessage = _getUserFriendlyErrorMessage(e);
      print('Error updating employee: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get employee by ID
  EmployeeModel? getEmployeeById(String id) {
    try {
      return _employees.firstWhere((employee) => employee.id == id);
    } catch (e) {
      return null;
    }
  }

  // Filter employees by onboarding status
  void filterByOnboardingStatus(bool? isOnboarded) {
    if (isOnboarded == null) {
      _filteredEmployees = List.from(_employees);
    } else {
      _filteredEmployees = _employees.where((employee) {
        return employee.isOnboarded == isOnboarded;
      }).toList();
    }
    notifyListeners();
  }

  // Filter employees by department
  void filterByDepartment(String? department) {
    if (department == null || department.isEmpty) {
      _filteredEmployees = List.from(_employees);
    } else {
      _filteredEmployees = _employees.where((employee) {
        return employee.department?.toLowerCase() == department.toLowerCase();
      }).toList();
    }
    notifyListeners();
  }

  // Clear all filters and search
  void clearFilters() {
    _searchQuery = '';
    _filteredEmployees = List.from(_employees);
    notifyListeners();
  }

  // Refresh employee list
  Future<void> refreshEmployees() async {
    await fetchAllEmployees();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Convert Firebase errors to user-friendly messages
  String _getUserFriendlyErrorMessage(dynamic error) {
    String errorString = error.toString().toLowerCase();

    if (errorString.contains('failed-precondition') ||
        errorString.contains('index')) {
      return 'Unable to load employees. Please try again later.';
    } else if (errorString.contains('permission-denied')) {
      return 'You don\'t have permission to access employee data.';
    } else if (errorString.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorString.contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorString.contains('not-found')) {
      return 'Employee data not found.';
    } else if (errorString.contains('already-exists')) {
      return 'Employee ID already exists. Please use a different ID.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  // Get employees count by status
  int get totalEmployees => _employees.length;
  int get onboardedEmployees =>
      _employees.where((emp) => emp.isOnboarded).length;
  int get pendingEmployees =>
      _employees.where((emp) => !emp.isOnboarded).length;
  // Assuming separated employees have a field 'isSeparated' or similar
  // For now, we'll return 0 - you can add this field later
  int get separatedEmployees => 0;

  @override
  void dispose() {
    _employees.clear();
    _filteredEmployees.clear();
    super.dispose();
  }
}
