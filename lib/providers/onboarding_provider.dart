import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';
import '../services/fcm_service.dart';
import '../models/user_model.dart';
import 'user_provider.dart';

class OnboardingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  // State variables
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  List<String> _selectedUserIds = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Leave configuration
  int _privilegeLeaves = 12;
  int _sickLeaves = 7;
  int _casualLeaves = 5;
  bool _enableCasualLeaves = false;

  // Individual user leave configurations
  Map<String, Map<String, int>> _individualUserLeaves = {};

  // Getters
  List<UserModel> get allUsers => _allUsers;
  List<UserModel> get filteredUsers => _filteredUsers;
  List<String> get selectedUserIds => _selectedUserIds;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  int get privilegeLeaves => _privilegeLeaves;
  int get sickLeaves => _sickLeaves;
  int get casualLeaves => _casualLeaves;
  bool get enableCasualLeaves => _enableCasualLeaves;

  // Setters
  void setPrivilegeLeaves(int value) {
    _privilegeLeaves = value;
    notifyListeners();
  }

  void setSickLeaves(int value) {
    _sickLeaves = value;
    notifyListeners();
  }

  void setCasualLeaves(int value) {
    _casualLeaves = value;
    notifyListeners();
  }

  void setEnableCasualLeaves(bool value) {
    _enableCasualLeaves = value;
    notifyListeners();
  }

  // Individual user leave management
  Map<String, int> getIndividualUserLeaves(String userId) {
    return _individualUserLeaves[userId] ??
        {
          'privilegeLeaves': _privilegeLeaves,
          'sickLeaves': _sickLeaves,
          'casualLeaves': _casualLeaves,
        };
  }

  void setIndividualUserPrivilegeLeaves(String userId, int value) {
    _individualUserLeaves[userId] ??= {
      'privilegeLeaves': _privilegeLeaves,
      'sickLeaves': _sickLeaves,
      'casualLeaves': _casualLeaves,
    };
    _individualUserLeaves[userId]!['privilegeLeaves'] = value;
    notifyListeners();
  }

  void setIndividualUserSickLeaves(String userId, int value) {
    _individualUserLeaves[userId] ??= {
      'privilegeLeaves': _privilegeLeaves,
      'sickLeaves': _sickLeaves,
      'casualLeaves': _casualLeaves,
    };
    _individualUserLeaves[userId]!['sickLeaves'] = value;
    notifyListeners();
  }

  void setIndividualUserCasualLeaves(String userId, int value) {
    _individualUserLeaves[userId] ??= {
      'privilegeLeaves': _privilegeLeaves,
      'sickLeaves': _sickLeaves,
      'casualLeaves': _casualLeaves,
    };
    _individualUserLeaves[userId]!['casualLeaves'] = value;
    notifyListeners();
  }

  void clearIndividualUserLeaves() {
    _individualUserLeaves.clear();
    notifyListeners();
  }

  // Update joining date for a specific user
  void updateUserJoiningDate(String userId, DateTime newDate) {
    final userIndex = _allUsers.indexWhere((user) => user.userId == userId);
    if (userIndex != -1) {
      final user = _allUsers[userIndex];
      _allUsers[userIndex] = UserModel(
        id: user.id,
        name: user.name,
        email: user.email,
        fcmToken: user.fcmToken,
        isAdmin: user.isAdmin,
        profileImageUrl: user.profileImageUrl,
        employeeId: user.employeeId,
        department: user.department,
        createdAt: user.createdAt,
        joiningDate: newDate,
      );

      // Update filtered users as well
      final filteredIndex = _filteredUsers.indexWhere(
        (user) => user.userId == userId,
      );
      if (filteredIndex != -1) {
        _filteredUsers[filteredIndex] = _allUsers[userIndex];
      }

      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Load users method
  Future<void> loadUsers(UserProvider userProvider) async {
    try {
      _isLoading = true;
      notifyListeners();

      final allUsers = await userProvider.getAllUsers();
      _allUsers = [];

      for (final user in allUsers) {
        final isOnboarded = await userProvider.isUserOnboarded(user.userId);
        // Exclude users who are:
        // 1. Already onboarded
        // 2. Have admin role
        // 3. Have isAdmin flag set to true
        if (!isOnboarded &&
            user.role != AppConstants.adminRole &&
            !user.isAdmin) {
          _allUsers.add(user);
        }
      }

      _filteredUsers = List.from(_allUsers);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading users: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filter users method
  void filterUsers(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredUsers = List.from(_allUsers);
    } else {
      _filteredUsers = _allUsers.where((user) {
        return user.name.toLowerCase().contains(query.toLowerCase()) ||
            user.email.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  // Toggle user selection
  void toggleUserSelection(String userId) {
    if (_selectedUserIds.contains(userId)) {
      _selectedUserIds.remove(userId);
    } else {
      _selectedUserIds.add(userId);
    }
    notifyListeners();
  }

  // Select all users
  void selectAllUsers() {
    _selectedUserIds = _filteredUsers.map((user) => user.userId).toList();
    notifyListeners();
  }

  // Clear selection
  void clearSelection() {
    _selectedUserIds.clear();
    clearIndividualUserLeaves();
    notifyListeners();
  }

  // Get selected users
  List<UserModel> getSelectedUsers() {
    return _allUsers
        .where((user) => _selectedUserIds.contains(user.userId))
        .toList();
  }

  /// Calculate pro-rated leaves based on joining month (from edited joining date or createdAt)
  Map<String, int> calculateProRatedLeaves({
    required int joiningMonth,
    int? privilegeLeaves,
    int? sickLeaves,
    int? casualLeaves,
  }) {
    // Use instance variables if not provided
    final pl = privilegeLeaves ?? _privilegeLeaves;
    final sl = sickLeaves ?? _sickLeaves;
    final cl = casualLeaves ?? _casualLeaves;

    final currentMonth = DateTime.now().month;

    // Calculate remaining months in the year from joining month to December
    // Exclude current month if joining in the same month
    int remainingMonths;
    if (joiningMonth == currentMonth) {
      // If joining in current month, exclude current month from calculation
      // Start from next month to December
      remainingMonths = 12 - joiningMonth;
    } else {
      // If joining in future or past month, include all months from joining to December
      remainingMonths = 12 - joiningMonth + 1;
    }

    // Ensure minimum 0 months (in case joining in December and it's December)
    remainingMonths = remainingMonths < 0 ? 0 : remainingMonths;

    // Calculate pro-rated leaves based on remaining months
    // Example: If annual PL is 12 and joining in October (current month), remainingMonths = 2 (Nov, Dec)
    // Pro-rated PL = (12 / 12) * 2 = 2 leaves
    return {
      'privilegeLeaves': remainingMonths > 0
          ? ((pl / 12) * remainingMonths).round()
          : 0,
      'sickLeaves': remainingMonths > 0
          ? ((sl / 12) * remainingMonths).round()
          : 0,
      'casualLeaves': _enableCasualLeaves && cl > 0 && remainingMonths > 0
          ? ((cl / 12) * remainingMonths).round()
          : 0,
    };
  }

  /// Onboard selected users with leave allocation
  Future<bool> onboardUsers() async {
    if (_selectedUserIds.isEmpty) return false;

    try {
      _setLoading(true);

      final batch = _firestore.batch();
      final currentDate = DateTime.now();

      for (final userId in _selectedUserIds) {
        final user = _allUsers.firstWhere((u) => u.userId == userId);
        // Use edited joining date if available, otherwise use createdAt (signup date)
        final joiningDate = user.joiningDate ?? user.createdAt ?? currentDate;
        final joiningMonth = joiningDate.month;

        // Generate employee ID if user doesn't have one
        String? employeeId = user.employeeId;
        if (employeeId == null || employeeId.isEmpty) {
          final userProvider = UserProvider();
          employeeId = await userProvider.generateNextEmployeeId();
        }

        // Get individual user leave values or use defaults
        final userLeaves = getIndividualUserLeaves(userId);
        
        // Use the individual user leaves directly instead of recalculating
        // This ensures the values shown in the UI are the same ones saved to Firestore
        final leavesToSave = {
          'privilegeLeaves': userLeaves['privilegeLeaves']!,
          'sickLeaves': userLeaves['sickLeaves']!,
          'casualLeaves': userLeaves['casualLeaves']!,
        };

        // Update user document with onboarding status
        final userRef = _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId);
        batch.update(userRef, {
          'isOnboarded': true,
          'onboardingDate': FieldValue.serverTimestamp(),
          'joiningDate': joiningDate, // Add/update joiningDate
          'joiningMonth': joiningMonth,
          'joiningYear': joiningDate.year,
          'employeeId': employeeId, // Add/update employeeId
          'role': user.role ?? 'employee', // Set role if not already set
          'isCasualLeave': _enableCasualLeaves, // Set casual leave preference
        });

        // Create leaves subcollection for the user
        final leavesRef = userRef
            .collection('leaves')
            .doc('annual_${currentDate.year}');

        final leaveData = {
          'year': currentDate.year,
          'joiningMonth': joiningMonth,
          'privilegeLeaves': {
            'allocated': leavesToSave['privilegeLeaves'],
            'used': 0,
            'balance': leavesToSave['privilegeLeaves'],
          },
          'sickLeaves': {
            'allocated': leavesToSave['sickLeaves'],
            'used': 0,
            'balance': leavesToSave['sickLeaves'],
          },
          'casualLeaves': {
            'allocated': leavesToSave['casualLeaves'],
            'used': 0,
            'balance': leavesToSave['casualLeaves'],
          },
          'totalAllocated':
              leavesToSave['privilegeLeaves']! +
              leavesToSave['sickLeaves']! +
              leavesToSave['casualLeaves']!,
          'totalUsed': 0,
          'totalBalance':
              leavesToSave['privilegeLeaves']! +
              leavesToSave['sickLeaves']! +
              leavesToSave['casualLeaves']!,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(leavesRef, leaveData);

        // Send notification
        await _sendOnboardingNotification(user, leavesToSave);
      }

      // Commit the batch
      await batch.commit();

      // Clear selection and reload users
      _selectedUserIds.clear();
      _setLoading(false);

      return true;
    } catch (e) {
      _setLoading(false);
      debugPrint('Error onboarding users: $e');
      return false;
    }
  }

  /// Send onboarding notification to a user
  Future<void> _sendOnboardingNotification(
    UserModel user,
    Map<String, int> calculatedLeaves,
  ) async {
    try {
      final title = 'Welcome to the Team! 🎉';
      final body =
          'You have been successfully onboarded. Your leave allocation: '
          'PL: ${calculatedLeaves['privilegeLeaves']}, '
          'SL: ${calculatedLeaves['sickLeaves']}'
          '${calculatedLeaves['casualLeaves']! > 0 ? ', CL: ${calculatedLeaves['casualLeaves']}' : ''}';

      await _fcmService.sendNotificationToUser(
        userId: user.userId,
        title: title,
        body: body,
        data: {
          'type': 'onboarding',
          'privilegeLeaves': calculatedLeaves['privilegeLeaves'].toString(),
          'sickLeaves': calculatedLeaves['sickLeaves'].toString(),
          'casualLeaves': calculatedLeaves['casualLeaves'].toString(),
          'onboardingDate': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error sending onboarding notification: $e');
      // Don't throw error for notification failures
    }
  }

  /// Get user's current year leave allocation
  Future<Map<String, dynamic>?> getUserLeaveAllocation(String userId) async {
    try {
      final currentYear = DateTime.now().year;
      final leaveDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('leaves')
          .doc('annual_$currentYear')
          .get();

      if (leaveDoc.exists) {
        return leaveDoc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user leave allocation: $e');
      return null;
    }
  }

  /// Update leave balance when leave is approved/rejected
  Future<void> updateLeaveBalance({
    required String userId,
    required String leaveType,
    required int days,
    required bool isApproved,
  }) async {
    try {
      final currentYear = DateTime.now().year;
      final leaveRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('leaves')
          .doc('annual_$currentYear');

      await _firestore.runTransaction((transaction) async {
        final leaveDoc = await transaction.get(leaveRef);

        if (!leaveDoc.exists) {
          throw Exception('Leave allocation not found for user');
        }

        final data = leaveDoc.data()!;
        final leaveTypeData = data[leaveType] as Map<String, dynamic>;

        if (isApproved) {
          // Deduct from balance and add to used
          final newUsed = (leaveTypeData['used'] as int) + days;
          final newBalance = (leaveTypeData['balance'] as int) - days;

          if (newBalance < 0) {
            throw Exception('Insufficient leave balance');
          }

          transaction.update(leaveRef, {
            '$leaveType.used': newUsed,
            '$leaveType.balance': newBalance,
            'totalUsed': FieldValue.increment(days),
            'totalBalance': FieldValue.increment(-days),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to update leave balance: $e');
    }
  }

  /// Get leave statistics for admin dashboard
  Future<Map<String, dynamic>> getLeaveStatistics() async {
    try {
      final currentYear = DateTime.now().year;
      final usersSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('isOnboarded', isEqualTo: true)
          .get();

      int totalUsers = 0;
      int totalAllocatedLeaves = 0;
      int totalUsedLeaves = 0;
      int totalBalanceLeaves = 0;
      int totalPLAllocated = 0;
      int totalSLAllocated = 0;
      int totalCLAllocated = 0;

      for (final userDoc in usersSnapshot.docs) {
        final leaveDoc = await userDoc.reference
            .collection('leaves')
            .doc('annual_$currentYear')
            .get();

        if (leaveDoc.exists) {
          final data = leaveDoc.data()!;
          totalUsers++;
          totalAllocatedLeaves += data['totalAllocated'] as int;
          totalUsedLeaves += data['totalUsed'] as int;
          totalBalanceLeaves += data['totalBalance'] as int;

          final plData = data['privilegeLeaves'] as Map<String, dynamic>;
          final slData = data['sickLeaves'] as Map<String, dynamic>;
          final clData = data['casualLeaves'] as Map<String, dynamic>;

          totalPLAllocated += plData['allocated'] as int;
          totalSLAllocated += slData['allocated'] as int;
          totalCLAllocated += clData['allocated'] as int;
        }
      }

      return {
        'totalUsers': totalUsers,
        'totalAllocatedLeaves': totalAllocatedLeaves,
        'totalUsedLeaves': totalUsedLeaves,
        'totalBalanceLeaves': totalBalanceLeaves,
        'totalPLAllocated': totalPLAllocated,
        'totalSLAllocated': totalSLAllocated,
        'totalCLAllocated': totalCLAllocated,
        'utilizationPercentage': totalAllocatedLeaves > 0
            ? (totalUsedLeaves / totalAllocatedLeaves * 100).round()
            : 0,
      };
    } catch (e) {
      debugPrint('Error getting leave statistics: $e');
      return {
        'totalUsers': 0,
        'totalAllocatedLeaves': 0,
        'totalUsedLeaves': 0,
        'totalBalanceLeaves': 0,
        'totalPLAllocated': 0,
        'totalSLAllocated': 0,
        'totalCLAllocated': 0,
        'utilizationPercentage': 0,
      };
    }
  }
}
