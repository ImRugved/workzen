import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:workzen/models/user_model.dart';
import 'package:workzen/providers/onboarding_provider.dart';
import 'package:workzen/providers/user_provider.dart';
import 'package:workzen/widgets/app_drawer.dart';
import '../../constants/const_textstyle.dart';

class EmployeeOnboardingScreen extends StatefulWidget {
  const EmployeeOnboardingScreen({super.key});

  @override
  State<EmployeeOnboardingScreen> createState() =>
      _EmployeeOnboardingScreenState();
}

class _EmployeeOnboardingScreenState extends State<EmployeeOnboardingScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final onboardingProvider = Provider.of<OnboardingProvider>(
        context,
        listen: false,
      );
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      onboardingProvider.loadUsers(userProvider);
      // No auto-sync on load - admin manually selects users first
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _editJoiningDate(OnboardingProvider provider, UserModel user) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: user.joiningDate ?? user.createdAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      provider.updateUserJoiningDate(user.userId, pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Onboarding',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: Consumer<OnboardingProvider>(
        builder: (context, onboardingProvider, child) {
          // Disabled auto-sync to prevent overriding default values
          // Reset to default values first, then auto-sync sliders only ONCE when users are first selected
          if (onboardingProvider.selectedUserIds.isNotEmpty &&
              !onboardingProvider.hasAutoSynced) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Reset to defaults first
              onboardingProvider.resetToDefaultLeaves();
              _autoSyncSliders(onboardingProvider);
              onboardingProvider.markAutoSyncComplete();
            });
          }

          return Column(
            children: [
              // Main content area
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(10.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search and Filter Section
                      _buildSearchSection(onboardingProvider),
                      SizedBox(height: 16.h),

                      // Selected Users Display
                      _buildSelectedUsersSection(onboardingProvider),
                      SizedBox(height: 16.h),

                      // Users List - Takes remaining space
                      Expanded(child: _buildUsersList(onboardingProvider)),
                    ],
                  ),
                ),
              ),

              // Fixed bottom button
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: _buildOnboardButton(onboardingProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchSection(OnboardingProvider provider) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search users...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: provider.filterUsers,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: provider.selectAllUsers,
          child: const Text('Select All'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: provider.clearSelection,
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _buildSelectedUsersSection(OnboardingProvider provider) {
    final selectedUsers = provider.getSelectedUsers();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Users (${provider.selectedUserIds.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (selectedUsers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: selectedUsers.map((user) {
                return Chip(
                  label: Text(user.name),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => provider.toggleUserSelection(user.userId),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersList(OnboardingProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.filteredUsers.isEmpty) {
      return const Center(
        child: Text(
          'No users available for onboarding',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.filteredUsers.length,
      itemBuilder: (context, index) {
        final user = provider.filteredUsers[index];
        final isSelected = provider.selectedUserIds.contains(user.userId);

        return Card(
          child: CheckboxListTile(
            title: Text(user.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Joining Date: ${_getDisplayJoiningDate(user)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _editJoiningDate(provider, user),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.blue,
                      ),
                    ),
                    if (user.joiningDate != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.edit_calendar,
                          size: 12,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            value: isSelected,
            onChanged: (bool? value) {
              provider.toggleUserSelection(user.userId);
            },
            secondary: _buildUserAvatar(user),
          ),
        );
      },
    );
  }

  Widget _buildLeaveConfigurationSection(OnboardingProvider provider) {
    final selectedUsers = provider.getSelectedUsers();

    return ExpansionTile(
      title: Text(
        selectedUsers.isEmpty
            ? 'Leave Configuration'
            : 'Leave Configuration (${selectedUsers.length} user${selectedUsers.length > 1 ? 's' : ''})',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              // Leave calculation explanation and preview
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pro-rated Leave Calculation:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• Leaves are calculated based on remaining months in the year',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Text(
                      '• January joining = Full year allocation',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _getCurrentMonthExample(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    // const SizedBox(height: 8),
                    // //    _buildLeavePreview(provider),
                    // const SizedBox(height: 12),
                  ],
                ),
              ),

              // Casual Leave Checkbox
              //   const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Consumer<OnboardingProvider>(
                  builder: (context, provider, child) {
                    return Row(
                      children: [
                        Checkbox(
                          value: provider.enableCasualLeaves,
                          onChanged: (bool? value) {
                            if (value != null) {
                              provider.setEnableCasualLeaves(value);
                            }
                          },
                          activeColor: Colors.blue,
                        ),
                        const Text(
                          'Enable Casual Leave',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardButton(OnboardingProvider provider) {
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: provider.selectedUserIds.isEmpty || provider.isLoading
              ? null
              : () => _showOnboardingBottomSheet(provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: provider.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Onboard Users (${provider.selectedUserIds.length})',
                  style: const TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }

  Widget _buildLeavePreview(OnboardingProvider provider) {
    final selectedUsers = provider.getSelectedUsers();

    if (selectedUsers.isEmpty) {
      // Show current month example when no users selected using default values
      final currentMonth = DateTime.now().month;
      final currentMonthLeaves = provider.calculateProRatedLeaves(
        joiningMonth: currentMonth,
        privilegeLeaves: 12, // Use default values
        sickLeaves: 6,
        casualLeaves: 5,
      );

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Example: Joining in ${_getMonthName(currentMonth)} (Current Month)',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'PL: ${currentMonthLeaves['privilegeLeaves']} | SL: ${currentMonthLeaves['sickLeaves']}${provider.enableCasualLeaves ? ' | CL: ${currentMonthLeaves['casualLeaves']}' : ''}',
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ),
      );
    }

    // Show calculated leaves for selected users based on their createdAt dates using default values
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calculated Leaves for Selected Users:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...selectedUsers.take(3).map((user) {
            // Use edited joining date if available, otherwise use createdAt
            final joiningDate = user.joiningDate ?? user.createdAt;
            if (joiningDate == null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${user.name}: No joining date available',
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              );
            }

            final joiningMonth = joiningDate.month;
            final calculatedLeaves = provider.calculateProRatedLeaves(
              joiningMonth: joiningMonth,
              privilegeLeaves:
                  12, // Use default values for individual calculations
              sickLeaves: 6,
              casualLeaves: 5,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${user.name}: PL: ${calculatedLeaves['privilegeLeaves']} | SL: ${calculatedLeaves['sickLeaves']}${provider.enableCasualLeaves ? ' | CL: ${calculatedLeaves['casualLeaves']}' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            );
          }).toList(),
          if (selectedUsers.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '... and ${selectedUsers.length - 3} more users',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _getDisplayJoiningDate(UserModel user) {
    // Use edited joining date if available, otherwise use createdAt
    final displayDate = user.joiningDate ?? user.createdAt;
    if (displayDate == null) return 'Not set';
    return '${displayDate.day}/${displayDate.month}/${displayDate.year}';
  }

  void _showOnboardingBottomSheet(OnboardingProvider provider) {
    // Calculate leaves for all selected users
    provider.calculateLeavesForSelectedUsers();

    // Debug prints for selected employees' joining dates and calculated leaves
    final selectedUsers = provider.getSelectedUsers();
    for (final user in selectedUsers) {
      final joiningDate = user.joiningDate != null
          ? DateFormat('dd/MM/yyyy').format(user.joiningDate!)
          : "Not set";

      // Get calculated leaves for this user
      final userLeaves = provider.getIndividualUserLeaves(user.userId);
      final privilegeLeaves = userLeaves['privilegeLeaves'];
      final sickLeaves = userLeaves['sickLeaves'];
      final casualLeaves = userLeaves['casualLeaves'];

      print('EMPLOYEE ONBOARDING - User: ${user.name}');
      print('EMPLOYEE ONBOARDING - Joining Date: ${user.createdAt}');
      print(
        'EMPLOYEE ONBOARDING - Calculated Leaves: PL=$privilegeLeaves, SL=$sickLeaves, CL=$casualLeaves',
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height, // Use full screen height
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.all(10),
              child: const Text(
                'Confirm Onboarding',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    // Header text
                    Text(
                      'Selected Users for Onboarding',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Leave Configuration Section
                    Consumer<OnboardingProvider>(
                      builder: (context, provider, child) {
                        return _buildLeaveConfigurationSection(provider);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Selected users list with checkboxes and edit buttons
                    Consumer<OnboardingProvider>(
                      builder: (context, provider, child) {
                        final selectedUsers = provider.getSelectedUsers();

                        return Column(
                          children: selectedUsers.map((user) {
                            final joiningDate =
                                user.joiningDate ?? DateTime.now();
                            // Calculate leaves for this user without notifying during build
                            provider.calculateLeaves(
                              user.userId,
                              notify: false,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // User Header
                                  Row(
                                    children: [
                                      // Checkbox
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),

                                      // User avatar
                                      _buildUserAvatar(user, radius: 20),
                                      const SizedBox(width: 12),

                                      // User info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              user.email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              'Joining: ${_getDisplayJoiningDate(user)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Leave Information Section
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Leave Allocation (${provider.calculatedLeaves[user.userId]?['remainingMonths'] ?? 0} months)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                final isCurrentlyEditing =
                                                    provider.editingUserId ==
                                                    user.userId;
                                                if (isCurrentlyEditing) {
                                                  // Stop editing
                                                  provider.setEditingUserId(
                                                    null,
                                                  );
                                                } else {
                                                  // Start editing
                                                  provider.setEditingUserId(
                                                    user.userId,
                                                  );
                                                }
                                              },
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 4,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: Text(
                                                provider.editingUserId ==
                                                        user.userId
                                                    ? 'Done'
                                                    : 'Edit',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      provider.editingUserId ==
                                                          user.userId
                                                      ? Colors.green.shade700
                                                      : Colors.blue.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Individual user leave preview with edit functionality
                                        _buildUserLeavePreview(user, provider),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // Confirm button
                    Consumer<OnboardingProvider>(
                      builder: (context, provider, child) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: provider.isLoading
                                  ? null
                                  : () => _confirmOnboarding(provider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: provider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Confirm Onboarding',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOnboarding(OnboardingProvider provider) async {
    final selectedUsers = provider.getSelectedUsers();

    // Apply custom leave overrides to the provider before onboarding
    for (final user in selectedUsers) {
      final overrides = _userLeaveOverrides[user.userId];
      if (overrides != null) {
        provider.setIndividualUserPrivilegeLeaves(
          user.userId,
          overrides['privilegeLeaves']!,
        );
        provider.setIndividualUserSickLeaves(
          user.userId,
          overrides['sickLeaves']!,
        );
        provider.setIndividualUserCasualLeaves(
          user.userId,
          overrides['casualLeaves']!,
        );
      }
    }

    final success = await provider.onboardUsers();

    if (mounted) {
      Navigator.pop(context); // Close bottom sheet

      if (success) {
        // Clear the overrides after successful onboarding
        _userLeaveOverrides.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully onboarded ${selectedUsers.length} user(s)',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Reload users
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        provider.loadUsers(userProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to onboard users. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCompleteUserSection(
    UserModel user,
    OnboardingProvider provider,
  ) {
    // Only calculate leaves if this user doesn't have individual leaves set yet
    // This prevents overriding manual slider changes during edit mode
    final hasIndividualLeaves = provider.hasIndividualUserLeaves(user.userId);

    if (!hasIndividualLeaves) {
      provider.calculateLeaves(user.userId, notify: false);
    }

    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Section
          Row(
            children: [
              _buildUserAvatar(user, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Joining Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Joining: ${_getDisplayJoiningDate(user)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),

          // Pro-rated Calculation Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pro-rated Leave Calculation:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildUserLeavePreview(user, provider),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Individual Configuration Section
          const Text(
            'Individual Configuration:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          // Individual counters
          _buildIndividualLeaveCounter(
            'Privilege Leave (PL)',
            user.userId,
            'privilegeLeaves',
            (int value) =>
                provider.setIndividualUserPrivilegeLeaves(user.userId, value),
            provider,
          ),
          const SizedBox(height: 12),

          _buildIndividualLeaveCounter(
            'Sick Leave (SL)',
            user.userId,
            'sickLeaves',
            (int value) =>
                provider.setIndividualUserSickLeaves(user.userId, value),
            provider,
          ),
          const SizedBox(height: 12),

          if (provider.enableCasualLeaves) ...[
            _buildIndividualLeaveCounter(
              'Casual Leave (CL)',
              user.userId,
              'casualLeaves',
              (int value) =>
                  provider.setIndividualUserCasualLeaves(user.userId, value),
              provider,
            ),
            const SizedBox(height: 12),
          ],

          // Final Calculated leaves preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Final Leave Allocation:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildFinalUserLeaveAllocation(user, provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserLeavePreview(UserModel user, OnboardingProvider provider) {
    // Check if this specific user is in edit mode
    final isEditingThisUser = provider.editingUserId == user.userId;

    // Only calculate leaves if:
    // 1. User is NOT in edit mode (to prevent overriding manual changes)
    // 2. AND user doesn't have individual leaves set yet
    if (!isEditingThisUser && !provider.hasIndividualUserLeaves(user.userId)) {
      // Use addPostFrameCallback to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.calculateLeaves(user.userId, notify: false);
      });
    }

    // Get calculated leaves from individual user leaves (which contains the calculated values)
    final userLeaves = provider.getIndividualUserLeaves(user.userId);
    final calculatedLeaves = provider.calculatedLeaves[user.userId];
    final remainingMonths = calculatedLeaves?['remainingMonths'] ?? 0;
    final finalPL = userLeaves['privilegeLeaves'] ?? 0;
    final finalSL = userLeaves['sickLeaves'] ?? 0;
    final finalCL = userLeaves['casualLeaves'] ?? 0;

    // Get default leaves for comparison
    final privilegeLeaves = provider.privilegeLeaves;
    final sickLeaves = provider.sickLeaves;
    final casualLeaves = provider.casualLeaves;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Remaining months:', style: TextStyle(fontSize: 12)),
            Row(
              children: [
                Text(
                  '$remainingMonths months',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Show either the editable sliders or the regular text display
        if (isEditingThisUser)
          _buildEditableLeaves(user, provider)
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildLeaveTextDisplay(
              user,
              provider,
              privilegeLeaves,
              sickLeaves,
              casualLeaves,
              finalPL,
              finalSL,
              finalCL,
            ),
          ),
      ],
    );
  }

  // Display regular text view of leaves
  Widget _buildLeaveTextDisplay(
    UserModel user,
    OnboardingProvider provider,
    int privilegeLeaves,
    int sickLeaves,
    int casualLeaves,
    int finalPL,
    int finalSL,
    int finalCL,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('PL:', style: TextStyle(fontSize: 12)),
            Text(
              '$finalPL days',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('SL:', style: TextStyle(fontSize: 12)),
            Text(
              '$finalSL days',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (provider.enableCasualLeaves)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CL:', style: TextStyle(fontSize: 12)),
              Text(
                '$finalCL days',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // Replace the _buildEditableLeaves method with this fixed version:

  // Replace the _buildEditableLeaves method with this fixed version:

  Widget _buildEditableLeaves(UserModel user, OnboardingProvider provider) {
    // IMPORTANT: Don't call calculateLeaves here - it will override slider changes
    // The values are already initialized when user is selected or edit button is clicked

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Leave Allocation:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          _buildIndividualLeaveCounter(
            'Privilege Leave (PL)',
            user.userId,
            'privilegeLeaves',
            (int value) {
              provider.setIndividualUserPrivilegeLeaves(user.userId, value);
            },
            provider,
          ),
          const SizedBox(height: 4),
          _buildIndividualLeaveCounter(
            'Sick Leave (SL)',
            user.userId,
            'sickLeaves',
            (int value) {
              provider.setIndividualUserSickLeaves(user.userId, value);
            },
            provider,
          ),
          if (provider.enableCasualLeaves) ...[
            const SizedBox(height: 4),
            _buildIndividualLeaveCounter(
              'Casual Leave (CL)',
              user.userId,
              'casualLeaves',
              (int value) {
                provider.setIndividualUserCasualLeaves(user.userId, value);
              },
              provider,
            ),
          ],
        ],
      ),
    );
  }

  // Individual leave counter with buttons and text field for editing
  Widget _buildIndividualLeaveCounter(
    String label,
    String userId,
    String leaveType,
    Function(int) onChanged,
    OnboardingProvider provider,
  ) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, child) {
        final userLeaves = provider.getIndividualUserLeaves(userId);
        final value = userLeaves[leaveType] ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Counter Row with buttons and text field
              Row(
                children: [
                  // Decrease button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: IconButton(
                      onPressed: value > 0
                          ? () {
                              final newValue = value - 1;
                              onChanged(newValue);
                              print(
                                'DEBUG: Decreased $leaveType for user $userId to $newValue',
                              );
                            }
                          : null,
                      icon: Icon(
                        Icons.remove,
                        color: value > 0 ? Colors.red.shade600 : Colors.grey,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Text field for direct input
                  Expanded(
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: TextFormField(
                        key: ValueKey(
                          '${userId}_${leaveType}_$value',
                        ), // Force rebuild when value changes
                        initialValue: value.toString(),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          hintText: '0',
                          suffix: Text(
                            'days',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        onFieldSubmitted: (String textValue) {
                          final newValue = int.tryParse(textValue) ?? 0;
                          final clampedValue = newValue.clamp(0, 30);
                          onChanged(clampedValue);
                          print(
                            'DEBUG: Text field submitted $leaveType for user $userId to $clampedValue',
                          );
                        },
                        validator: (String? textValue) {
                          if (textValue == null || textValue.isEmpty)
                            return null;
                          final newValue = int.tryParse(textValue);
                          if (newValue == null) return 'Invalid number';
                          if (newValue < 0 || newValue > 30)
                            return 'Must be 0-30';
                          return null;
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Increase button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: IconButton(
                      onPressed: value < 30
                          ? () {
                              final newValue = value + 1;
                              onChanged(newValue);
                              print(
                                'DEBUG: Increased $leaveType for user $userId to $newValue',
                              );
                            }
                          : null,
                      icon: Icon(
                        Icons.add,
                        color: value < 30 ? Colors.green.shade600 : Colors.grey,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Current value display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Current: $value days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinalUserLeaveAllocation(
    UserModel user,
    OnboardingProvider provider,
  ) {
    // Only calculate leaves if this user doesn't have individual leaves set yet
    // This prevents overriding manual slider changes during edit mode
    final hasIndividualLeaves = provider.hasIndividualUserLeaves(user.userId);

    if (!hasIndividualLeaves) {
      // Ensure leaves are calculated without triggering notifyListeners during build
      provider.calculateLeaves(user.userId, notify: false);
    }

    // Get calculated leaves from individual user leaves (which contains the calculated values)
    final userLeaves = provider.getIndividualUserLeaves(user.userId);
    final finalPL = userLeaves['privilegeLeaves'] ?? 0;
    final finalSL = userLeaves['sickLeaves'] ?? 0;
    final finalCL = userLeaves['casualLeaves'] ?? 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Privilege Leave:', style: TextStyle(fontSize: 12)),
            Text(
              '$finalPL days',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sick Leave:', style: TextStyle(fontSize: 12)),
            Text(
              '$finalSL days',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        if (provider.enableCasualLeaves)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Casual Leave:', style: TextStyle(fontSize: 12)),
              Text(
                '$finalCL days',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _getCurrentMonthExample() {
    final now = DateTime.now();
    final currentMonth = DateFormat('MMMM').format(now);
    final remainingMonths = 12 - now.month + 1;

    if (now.month == 1) {
      return '• January joining = Full year allocation';
    }

    final monthsFromCurrent = List.generate(remainingMonths, (index) {
      final month = DateTime(now.year, now.month + index);
      return DateFormat('MMM').format(month);
    }).join(', ');

    return '• $currentMonth joining = $remainingMonths months allocation ($monthsFromCurrent)';
  }

  // Individual user leave configuration storage
  final Map<String, Map<String, int>> _userLeaveOverrides = {};

  /// Auto-sync sliders with average calculated values from selected users
  void _autoSyncSliders(OnboardingProvider provider) {
    final selectedUsers = provider.getSelectedUsers();
    if (selectedUsers.isEmpty) return;

    // Calculate average from actual calculated individual user leaves
    int totalPL = 0;
    int totalSL = 0;
    int totalCL = 0;
    int validUserCount = 0;

    for (final user in selectedUsers) {
      // Use the actual calculated individual user leaves instead of recalculating
      final userLeaves = provider.getIndividualUserLeaves(user.userId);

      totalPL += userLeaves['privilegeLeaves']!;
      totalSL += userLeaves['sickLeaves']!;
      totalCL += userLeaves['casualLeaves']!;
      validUserCount++;
    }

    if (validUserCount > 0) {
      // Calculate averages and sync sliders
      final avgPL = (totalPL / validUserCount).round();
      final avgSL = (totalSL / validUserCount).round();
      final avgCL = (totalCL / validUserCount).round();

      // Sync the main sliders with calculated averages
      provider.setPrivilegeLeaves(avgPL);
      provider.setSickLeaves(avgSL);
      provider.setCasualLeaves(avgCL);

      print(
        'EMPLOYEE ONBOARDING - Auto-synced sliders: PL=$avgPL, SL=$avgSL, CL=$avgCL',
      );
    }
  }

  /// Builds a user avatar with error handling for network images
  Widget _buildUserAvatar(UserModel user, {double radius = 20}) {
    final hasProfileImage =
        user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty;

    if (!hasProfileImage) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.blue.shade100,
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue.shade100,
      child: ClipOval(
        child: Image.network(
          user.profileImageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: Colors.blue.shade100,
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: radius * 0.8,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
