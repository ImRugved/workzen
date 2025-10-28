import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:workzen/models/user_model.dart';
import 'package:workzen/providers/onboarding_provider.dart';
import 'package:workzen/providers/user_provider.dart';
import 'package:workzen/widgets/app_drawer.dart';

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
        title: const Text('Employee Onboarding'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: Consumer<OnboardingProvider>(
        builder: (context, onboardingProvider, child) {
          // Auto-sync sliders only when users are selected
          if (onboardingProvider.selectedUserIds.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _autoSyncSliders(onboardingProvider);
            });
          }

          return Column(
            children: [
              // Main content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search and Filter Section
                      _buildSearchSection(onboardingProvider),
                      const SizedBox(height: 16),

                      // Selected Users Display
                      _buildSelectedUsersSection(onboardingProvider),
                      const SizedBox(height: 16),

                      // Users List - Takes remaining space
                      Expanded(child: _buildUsersList(onboardingProvider)),
                    ],
                  ),
                ),
              ),

              // Fixed bottom button
              Container(
                padding: const EdgeInsets.all(16.0),
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
            secondary: CircleAvatar(
              backgroundImage:
                  (user.profileImageUrl != null &&
                      user.profileImageUrl!.isNotEmpty)
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child:
                  (user.profileImageUrl == null ||
                      user.profileImageUrl!.isEmpty)
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    )
                  : null,
            ),
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
                    const Text(
                      '• October joining = 3 months allocation (Oct, Nov, Dec)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    _buildLeavePreview(provider),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Show individual user cards for multiple users
              if (selectedUsers.length > 1) ...[
                Row(
                  children: [
                    const Text(
                      'Individual Leave Configurations:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.swipe_left,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const Text(
                      'Swipe to see all users',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 480,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: selectedUsers.length,
                    itemBuilder: (context, index) {
                      final user = selectedUsers[index];
                      return _buildIndividualUserCard(user, provider);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Privilege Leave Slider
              _buildLeaveSlider(
                'Privilege Leave (PL)',
                provider.privilegeLeaves,
                0,
                12,
                provider.setPrivilegeLeaves,
              ),
              const SizedBox(height: 16),

              // Sick Leave Slider
              _buildLeaveSlider(
                'Sick Leave (SL)',
                provider.sickLeaves,
                0,
                7,
                provider.setSickLeaves,
              ),
              const SizedBox(height: 16),

              // Casual Leave with Checkbox
              Row(
                children: [
                  Consumer<OnboardingProvider>(
                    builder: (context, provider, child) {
                      return Checkbox(
                        value: provider.enableCasualLeaves,
                        onChanged: (bool? value) {
                          if (value != null) {
                            provider.setEnableCasualLeaves(value);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLeaveSlider(
                      'Casual Leave (CL)',
                      provider.casualLeaves,
                      0,
                      5,
                      provider.setCasualLeaves,
                      enabled: provider.enableCasualLeaves,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveSlider(
    String title,
    int value,
    int min,
    int max,
    Function(int) onChanged, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title: $value',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: enabled ? Colors.black : Colors.grey,
          ),
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: value.toString(),
          onChanged: enabled
              ? (double newValue) => onChanged(newValue.round())
              : null,
        ),
      ],
    );
  }

  Widget _buildOnboardButton(OnboardingProvider provider) {
    return SizedBox(
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
    );
  }

  Future<void> _onboardSelectedUsers(OnboardingProvider provider) async {
    final selectedUsers = provider.getSelectedUsers();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Onboarding'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to onboard ${selectedUsers.length} user(s)?',
            ),
            const SizedBox(height: 16),
            const Text(
              'Leave Configuration:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• Privilege Leave: ${provider.privilegeLeaves}'),
            Text('• Sick Leave: ${provider.sickLeaves}'),
            if (provider.enableCasualLeaves)
              Text('• Casual Leave: ${provider.casualLeaves}')
            else
              const Text('• Casual Leave: Disabled'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.onboardUsers();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully onboarded ${selectedUsers.length} user(s)',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Reload users
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
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
  }

  Widget _buildLeavePreview(OnboardingProvider provider) {
    final selectedUsers = provider.getSelectedUsers();

    if (selectedUsers.isEmpty) {
      // Show current month example when no users selected using default values
      final currentMonth = DateTime.now().month;
      final currentMonthLeaves = provider.calculateProRatedLeaves(
        joiningMonth: currentMonth,
        privilegeLeaves: 12, // Use default values
        sickLeaves: 7,
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
              sickLeaves: 7,
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
              child: Text(
                'Confirm Onboarding',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Selected users info
                    Text(
                      'Are you sure you want to onboard ${provider.selectedUserIds.length} user(s)?',
                      style: const TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 16),

                    // Selected users list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        width: double.infinity,
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
                              'Selected Users:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...provider
                                .getSelectedUsers()
                                .map(
                                  (user) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.blue.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${user.name} (${user.email})',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Leave Configuration Section
                    Consumer<OnboardingProvider>(
                      builder: (context, provider, child) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _buildLeaveConfigurationSection(provider),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // Confirm button
                    Padding(
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: provider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
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
    final success = await provider.onboardUsers();

    if (mounted) {
      Navigator.pop(context); // Close bottom sheet

      if (success) {
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

  /// Calculate suggested leave values based on selected users' joining dates
  Map<String, int> _calculateSuggestedLeaves(OnboardingProvider provider) {
    final selectedUsers = provider.getSelectedUsers();

    if (selectedUsers.isEmpty) {
      // Use current month as default with default leave values
      final currentMonth = DateTime.now().month;
      return provider.calculateProRatedLeaves(
        joiningMonth: currentMonth,
        privilegeLeaves: 12, // Use default values
        sickLeaves: 7,
        casualLeaves: 5,
      );
    }

    // Calculate average leaves for selected users using default values
    int totalPL = 0, totalSL = 0, totalCL = 0;
    int validUsers = 0;

    for (final user in selectedUsers) {
      final joiningDate = user.joiningDate ?? user.createdAt;
      if (joiningDate != null) {
        final joiningMonth = joiningDate.month;
        final calculatedLeaves = provider.calculateProRatedLeaves(
          joiningMonth: joiningMonth,
          privilegeLeaves: 12, // Use default values for calculation
          sickLeaves: 7,
          casualLeaves: 5,
        );

        totalPL += calculatedLeaves['privilegeLeaves'] ?? 0;
        totalSL += calculatedLeaves['sickLeaves'] ?? 0;
        totalCL += calculatedLeaves['casualLeaves'] ?? 0;
        validUsers++;
      }
    }

    if (validUsers == 0) {
      // Fallback to current month with default values
      final currentMonth = DateTime.now().month;
      return provider.calculateProRatedLeaves(
        joiningMonth: currentMonth,
        privilegeLeaves: 12, // Use default values
        sickLeaves: 7,
        casualLeaves: 5,
      );
    }

    // Return average values (rounded)
    return {
      'privilegeLeaves': (totalPL / validUsers).round(),
      'sickLeaves': (totalSL / validUsers).round(),
      'casualLeaves': (totalCL / validUsers).round(),
    };
  }

  /// Automatically sync sliders with calculated leave values
  void _autoSyncSliders(OnboardingProvider provider) {
    final suggestedLeaves = _calculateSuggestedLeaves(provider);

    provider.setPrivilegeLeaves(suggestedLeaves['privilegeLeaves'] ?? 12);
    provider.setSickLeaves(suggestedLeaves['sickLeaves'] ?? 7);
    provider.setCasualLeaves(suggestedLeaves['casualLeaves'] ?? 5);
  }

  /// Build individual user card with sliders for leave customization
  Widget _buildIndividualUserCard(UserModel user, OnboardingProvider provider) {
    final joiningDate = user.joiningDate ?? user.createdAt ?? DateTime.now();
    final userLeaves = provider.getIndividualUserLeaves(user.userId);
    final calculatedLeaves = provider.calculateProRatedLeaves(
      joiningMonth: joiningDate.month,
      privilegeLeaves: userLeaves['privilegeLeaves']!,
      sickLeaves: userLeaves['sickLeaves']!,
      casualLeaves: userLeaves['casualLeaves']!,
    );

    return Container(
      width: 320,

      padding: const EdgeInsets.all(10),
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
          // User header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage:
                    (user.profileImageUrl != null &&
                        user.profileImageUrl!.isNotEmpty)
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child:
                    (user.profileImageUrl == null ||
                        user.profileImageUrl!.isEmpty)
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Joining date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Joining: ${_getDisplayJoiningDate(user)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),

          // Individual sliders
          _buildIndividualLeaveSlider(
            'Privilege Leave (PL)',
            userLeaves['privilegeLeaves']!,
            0,
            20,
            (value) =>
                provider.setIndividualUserPrivilegeLeaves(user.userId, value),
          ),
          const SizedBox(height: 8),

          _buildIndividualLeaveSlider(
            'Sick Leave (SL)',
            userLeaves['sickLeaves']!,
            0,
            15,
            (value) => provider.setIndividualUserSickLeaves(user.userId, value),
          ),
          const SizedBox(height: 8),

          if (provider.enableCasualLeaves) ...[
            _buildIndividualLeaveSlider(
              'Casual Leave (CL)',
              userLeaves['casualLeaves']!,
              0,
              10,
              (value) =>
                  provider.setIndividualUserCasualLeaves(user.userId, value),
            ),
            const SizedBox(height: 8),
          ],

          // Calculated leaves preview
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pro-rated Leaves (Based on Joining Month):',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PL: ${calculatedLeaves['privilegeLeaves']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'SL: ${calculatedLeaves['sickLeaves']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (provider.enableCasualLeaves)
                      Text(
                        'CL: ${calculatedLeaves['casualLeaves']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Total: ${(calculatedLeaves['privilegeLeaves'] ?? 0) + (calculatedLeaves['sickLeaves'] ?? 0) + (calculatedLeaves['casualLeaves'] ?? 0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual leave slider for a specific user
  Widget _buildIndividualLeaveSlider(
    String title,
    int currentValue,
    int min,
    int max,
    Function(int) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$currentValue',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.grey.shade300,
            thumbColor: Colors.blue,
            overlayColor: Colors.blue.withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: currentValue.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (value) => onChanged(value.round()),
          ),
        ),
      ],
    );
  }
}
