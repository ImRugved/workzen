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
  State<EmployeeOnboardingScreen> createState() => _EmployeeOnboardingScreenState();
}

class _EmployeeOnboardingScreenState extends State<EmployeeOnboardingScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final onboardingProvider = Provider.of<OnboardingProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      onboardingProvider.loadUsers(userProvider);
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
      initialDate: user.joiningDate ?? DateTime.now(),
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
                      Expanded(
                        child: _buildUsersList(onboardingProvider),
                      ),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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
                 if (user.joiningDate != null)
                   Row(
                     children: [
                       Text(
                         'Joined: ${user.joiningDate!.day}/${user.joiningDate!.month}/${user.joiningDate!.year}',
                         style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                     ],
                   ),
               ],
             ),
             value: isSelected,
             onChanged: (bool? value) {
               provider.toggleUserSelection(user.userId);
             },
             secondary: CircleAvatar(
               backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                   ? NetworkImage(user.profileImageUrl!)
                   : null,
               child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                   ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U')
                   : null,
             ),
           ),
         );
      },
    );
  }

  Widget _buildLeaveConfigurationSection(OnboardingProvider provider) {
    return ExpansionTile(
      title: const Text(
        'Leave Configuration',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Leave calculation explanation
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  ],
                ),
              ),

              // Privilege Leave
              _buildLeaveSlider(
                'Privilege Leave (PL)',
                provider.privilegeLeaves,
                0,
                12,
                provider.setPrivilegeLeaves,
              ),
              const SizedBox(height: 16),

              // Sick Leave
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
          onChanged: enabled ? (double newValue) => onChanged(newValue.round()) : null,
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
            Text('Are you sure you want to onboard ${selectedUsers.length} user(s)?'),
            const SizedBox(height: 16),
            const Text('Leave Configuration:', style: TextStyle(fontWeight: FontWeight.bold)),
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
              content: Text('Successfully onboarded ${selectedUsers.length} user(s)'),
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
  }

  Widget _buildLeavePreview(OnboardingProvider provider) {
    final currentMonth = DateTime.now().month;
    final currentMonthLeaves = provider.calculateProRatedLeaves(
      joiningMonth: currentMonth,
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

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  void _showOnboardingBottomSheet(OnboardingProvider provider) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Confirm Onboarding',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Selected users info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Are you sure you want to onboard ${provider.selectedUserIds.length} user(s)?',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              
              const SizedBox(height: 20),

              // Leave Configuration Section
              Consumer<OnboardingProvider>(
                builder: (context, provider, child) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      isScrollControlled: true,
      enableDrag: true,
    );
  }

  Future<void> _confirmOnboarding(OnboardingProvider provider) async {
    final selectedUsers = provider.getSelectedUsers();
    final success = await provider.onboardUsers();
    
    if (mounted) {
      Get.back(); // Close bottom sheet
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully onboarded ${selectedUsers.length} user(s)'),
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
}