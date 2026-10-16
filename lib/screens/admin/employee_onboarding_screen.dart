import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:workzen/models/user_model.dart';
import 'package:workzen/providers/onboarding_provider.dart';
import 'package:workzen/providers/user_provider.dart';
import 'package:workzen/widgets/app_drawer.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_button.dart';
import '../../constants/app_theme.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_date_time_picker.dart';
import '../../constants/constant_snackbar.dart';
import '../../utils/validators.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final onboardingProvider = Provider.of<OnboardingProvider>(
        context,
        listen: false,
      );
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      // Each onboarding starts with sick and casual leave on
      onboardingProvider.resetLeaveToggles();
      // Leave defaults arrive live from OrganizationProvider; nothing to fetch
      onboardingProvider.loadUsers(userProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _editJoiningDate(OnboardingProvider provider, UserModel user) async {
    final DateTime? pickedDate = await ConstantDatePicker.pick(
      context,
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
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
        backgroundColor: ConstColors.backgroundColor,
        foregroundColor: ConstColors.textColor,
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
                  padding: AppSpacing.screen,
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
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: ConstColors.cardBackground,
                  boxShadow: [
                    BoxShadow(
                      color: ConstColors.neuShadowDark,
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, -2.h),
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
            ),
            onChanged: provider.filterUsers,
          ),
        ),
        SizedBox(width: 8.w),
        ConstantButton(
          text: 'Select All',
          onPressed: provider.selectAllUsers,
          isFullWidth: false,
          height: 40.h,
        ),
        SizedBox(width: 8.w),
        ConstantButton(
          text: 'Clear',
          onPressed: provider.clearSelection,
          isFullWidth: false,
          height: 40.h,
        ),
      ],
    );
  }

  Widget _buildSelectedUsersSection(OnboardingProvider provider) {
    final selectedUsers = provider.getSelectedUsers();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: ConstColors.lightShade,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: ConstColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Users (${provider.selectedUserIds.length})',
            style: getTextTheme().bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (selectedUsers.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: selectedUsers.map((user) {
                return Chip(
                  label: Text(user.name),
                  deleteIcon: Icon(Icons.close, size: 18.r),
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
      return const Center(child: AppLoadingIndicator(size: 40));
    }

    if (provider.filteredUsers.isEmpty) {
      return Center(
        child: Text(
          'No users available for onboarding',
          style: getTextTheme().bodyLarge?.copyWith(
            fontWeight: FontWeight.normal,
            color: ConstColors.textColorLight,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.filteredUsers.length,
      itemBuilder: (context, index) {
        final user = provider.filteredUsers[index];
        final isSelected = provider.selectedUserIds.contains(user.userId);

        return NeuCard(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                        style: getTextTheme().bodySmall?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () => _editJoiningDate(provider, user),
                      child: Icon(
                        Icons.edit,
                        size: 16.r,
                        color: ConstColors.primaryDeep,
                      ),
                    ),
                    if (user.joiningDate != null)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Icon(
                          Icons.edit_calendar,
                          size: 12.r,
                          color: ConstColors.inProgressOrange,
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
        style: getTextTheme().bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
          child: Column(
            children: [
              // Leave calculation explanation and preview
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                margin: EdgeInsets.symmetric(vertical: 16.h),
                decoration: BoxDecoration(
                  color: ConstColors.lightShade,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: ConstColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pro-rated Leave Calculation:',
                      style: getTextTheme().bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '• Leaves are calculated based on remaining months in the year',
                      style: getTextTheme().bodySmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                    Text(
                      '• January joining = Full year allocation',
                      style: getTextTheme().bodySmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                    Text(
                      _getCurrentMonthExample(),
                      style: getTextTheme().bodySmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                    // const SizedBox(height: 8),
                    // //    _buildLeavePreview(provider),
                    // const SizedBox(height: 12),
                  ],
                ),
              ),

              // Leave Type Checkboxes
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  border: Border.all(color: ConstColors.borderColor),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Consumer<OnboardingProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: provider.enablePrivilegeLeaves,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  provider.setEnablePrivilegeLeaves(value);
                                }
                              },
                              activeColor: ConstColors.primary,
                            ),
                            Text(
                              'Enable Privilege Leave',
                              style: getTextTheme().bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: provider.enableSickLeaves,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  provider.setEnableSickLeaves(value);
                                }
                              },
                              activeColor: ConstColors.primary,
                            ),
                            Text(
                              'Enable Sick Leave',
                              style: getTextTheme().bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: provider.enableCasualLeaves,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  provider.setEnableCasualLeaves(value);
                                }
                              },
                              activeColor: ConstColors.primary,
                            ),
                            Text(
                              'Enable Casual Leave',
                              style: getTextTheme().bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
        child: ConstantButton(
          text: 'Onboard Users (${provider.selectedUserIds.length})',
          onPressed: provider.selectedUserIds.isEmpty || provider.isLoading
              ? null
              : () => _showOnboardingBottomSheet(provider),
          backgroundColor: ConstColors.primary,
          isLoading: provider.isLoading,
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
        privilegeLeaves: provider.privilegeLeaves,
        sickLeaves: provider.sickLeaves,
        casualLeaves: provider.casualLeaves,
      );

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: ConstColors.cardBackground,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: ConstColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Example: Joining in ${_getMonthName(currentMonth)} (Current Month)',
              style: getTextTheme().bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'PL: ${currentMonthLeaves['privilegeLeaves']} | SL: ${currentMonthLeaves['sickLeaves']}${provider.enableCasualLeaves ? ' | CL: ${currentMonthLeaves['casualLeaves']}' : ''}',
              style: getTextTheme().labelSmall?.copyWith(
                fontSize: 11.sp,
                color: ConstColors.textColor,
              ),
            ),
          ],
        ),
      );
    }

    // Show calculated leaves for selected users based on their createdAt dates using default values
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: ConstColors.cardBackground,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: ConstColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calculated Leaves for Selected Users:',
            style: getTextTheme().bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          ...selectedUsers.take(3).map((user) {
            // Use edited joining date if available, otherwise use createdAt
            final joiningDate = user.joiningDate ?? user.createdAt;
            if (joiningDate == null) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Text(
                  '${user.name}: No joining date available',
                  style: getTextTheme().labelSmall?.copyWith(
                    fontSize: 11.sp,
                    color: ConstColors.errorRed,
                  ),
                ),
              );
            }

            final joiningMonth = joiningDate.month;
            final calculatedLeaves = provider.calculateProRatedLeaves(
              joiningMonth: joiningMonth,
              privilegeLeaves: provider.privilegeLeaves,
              sickLeaves: provider.sickLeaves,
              casualLeaves: provider.casualLeaves,
            );

            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Text(
                '${user.name}: PL: ${calculatedLeaves['privilegeLeaves']} | SL: ${calculatedLeaves['sickLeaves']}${provider.enableCasualLeaves ? ' | CL: ${calculatedLeaves['casualLeaves']}' : ''}',
                style: getTextTheme().labelSmall?.copyWith(
                  fontSize: 11.sp,
                  color: ConstColors.textColor,
                ),
              ),
            );
          }).toList(),
          if (selectedUsers.length > 3)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Text(
                '... and ${selectedUsers.length - 3} more users',
                style: getTextTheme().labelSmall?.copyWith(
                  color: ConstColors.textColorLight,
                ),
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
    // Leave counts come from organization_details/leave_config
    if (!provider.isLeaveConfigured) {
      ConstantSnackbar.show(
        title:
            'Set the default leave counts first: Admin Dashboard > Leave Configuration',
        backgroundColor: ConstColors.inProgressOrange,
      );
      return;
    }

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
        decoration: BoxDecoration(
          color: ConstColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.symmetric(vertical: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: ConstColors.borderColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                child: Text(
                  'Confirm Onboarding',
                  style: getTextTheme().titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: Column(
                    children: [
                      // Header text
                      Text(
                        'Selected Users for Onboarding',
                        style: getTextTheme().titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // Leave Configuration Section
                      Consumer<OnboardingProvider>(
                        builder: (context, provider, child) {
                          return _buildLeaveConfigurationSection(provider);
                        },
                      ),

                      SizedBox(height: 16.h),

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
                                margin: EdgeInsets.symmetric(vertical: 16.h),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 16.h,
                                ),
                                decoration: BoxDecoration(
                                  color: ConstColors.lightShade,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: ConstColors.borderColor,
                                  ),
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
                                          color: ConstColors.successGreen,
                                          size: 24.r,
                                        ),
                                        SizedBox(width: 12.w),

                                        // User avatar
                                        _buildUserAvatar(user, radius: 20.r),
                                        SizedBox(width: 12.w),

                                        // User info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name,
                                                style: getTextTheme().bodyLarge,
                                              ),
                                              Text(
                                                user.email,
                                                style: getTextTheme().bodySmall
                                                    ?.copyWith(
                                                      color: ConstColors
                                                          .textColorLight,
                                                    ),
                                              ),
                                              Text(
                                                'Joining: ${_getDisplayJoiningDate(user)}',
                                                style: getTextTheme().bodySmall
                                                    ?.copyWith(
                                                      color: ConstColors
                                                          .primaryDeep,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 16.h),

                                    // Leave Information Section
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 12.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ConstColors.cardBackground,
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                        border: Border.all(
                                          color: ConstColors.borderColor,
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
                                                style: getTextTheme().bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: ConstColors
                                                          .primaryDeep,
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
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 5.w,
                                                    vertical: 4.h,
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
                                                  style: getTextTheme()
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            provider.editingUserId ==
                                                                user.userId
                                                            ? ConstColors
                                                                  .successGreen
                                                            : ConstColors
                                                                  .primaryDeep,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12.h),

                                          // Individual user leave preview with edit functionality
                                          _buildUserLeavePreview(
                                            user,
                                            provider,
                                          ),
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

                      SizedBox(height: 30.h),

                      // Confirm button
                      Consumer<OnboardingProvider>(
                        builder: (context, provider, child) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 20.h,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ConstantButton(
                                text: 'Confirm Onboarding',
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _confirmOnboarding(provider),
                                backgroundColor: ConstColors.primary,
                                isLoading: provider.isLoading,
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

        ConstantSnackbar.showSuccess(
          title: selectedUsers.length == 1
              ? '${selectedUsers.first.name} is onboarded and their leave is ready'
              : '${selectedUsers.length} employees are onboarded and their leave is ready',
        );

        // Reload users
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        provider.loadUsers(userProvider);
      } else {
        ConstantSnackbar.showError(
          title: 'Could not onboard the employees. Please try again.',
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
      width: 320.w,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: ConstColors.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: ConstColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: ConstColors.neuShadowDark,
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Section
          Row(
            children: [
              _buildUserAvatar(user, radius: 24.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email,
                      style: getTextTheme().bodyMedium?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Joining Date
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: ConstColors.backgroundColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              'Joining: ${_getDisplayJoiningDate(user)}',
              style: getTextTheme().bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Pro-rated Calculation Section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: ConstColors.lightShade,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: ConstColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro-rated Leave Calculation:',
                  style: getTextTheme().bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                _buildUserLeavePreview(user, provider),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Individual Configuration Section
          Text(
            'Individual Configuration:',
            style: getTextTheme().bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          // Individual counters
          if (provider.enablePrivilegeLeaves) ...[
            _buildIndividualLeaveCounter(
              'Privilege Leave (PL)',
              user.userId,
              'privilegeLeaves',
              (int value) =>
                  provider.setIndividualUserPrivilegeLeaves(user.userId, value),
              provider,
            ),
            SizedBox(height: 12.h),
          ],

          if (provider.enableSickLeaves) ...[
            _buildIndividualLeaveCounter(
              'Sick Leave (SL)',
              user.userId,
              'sickLeaves',
              (int value) =>
                  provider.setIndividualUserSickLeaves(user.userId, value),
              provider,
            ),
            SizedBox(height: 12.h),
          ],

          if (provider.enableCasualLeaves) ...[
            _buildIndividualLeaveCounter(
              'Casual Leave (CL)',
              user.userId,
              'casualLeaves',
              (int value) =>
                  provider.setIndividualUserCasualLeaves(user.userId, value),
              provider,
            ),
            SizedBox(height: 12.h),
          ],

          // Final Calculated leaves preview
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: ConstColors.successGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: ConstColors.successGreen.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Final Leave Allocation:',
                  style: getTextTheme().bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
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
            Text('Remaining months:', style: getTextTheme().bodySmall),
            Row(
              children: [
                Text(
                  '$remainingMonths months',
                  style: getTextTheme().bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8.h),

        // Show either the editable sliders or the regular text display
        if (isEditingThisUser)
          _buildEditableLeaves(user, provider)
        else
          Container(
            padding: EdgeInsets.symmetric(vertical: 4.h),
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
        if (provider.enablePrivilegeLeaves)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PL:', style: getTextTheme().bodySmall),
              Text(
                '$finalPL days',
                style: getTextTheme().bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        if (provider.enableSickLeaves)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SL:', style: getTextTheme().bodySmall),
              Text(
                '$finalSL days',
                style: getTextTheme().bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        if (provider.enableCasualLeaves)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CL:', style: getTextTheme().bodySmall),
              Text(
                '$finalCL days',
                style: getTextTheme().bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildEditableLeaves(UserModel user, OnboardingProvider provider) {
    // IMPORTANT: Don't call calculateLeaves here - it will override slider changes
    // The values are already initialized when user is selected or edit button is clicked

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: ConstColors.lightShade,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: ConstColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Leave Allocation:',
            style: getTextTheme().bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: ConstColors.primaryDeep,
            ),
          ),
          SizedBox(height: 8.h),
          if (provider.enablePrivilegeLeaves) ...[
            _buildIndividualLeaveCounter(
              'Privilege Leave (PL)',
              user.userId,
              'privilegeLeaves',
              (int value) {
                provider.setIndividualUserPrivilegeLeaves(user.userId, value);
              },
              provider,
            ),
            SizedBox(height: 4.h),
          ],
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
            SizedBox(height: 4.h),
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
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(
                label,
                style: getTextTheme().bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8.h),

              // Counter Row with buttons and text field
              Row(
                children: [
                  // Decrease button
                  Container(
                    decoration: BoxDecoration(
                      color: ConstColors.errorRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: ConstColors.errorRed.withValues(alpha: 0.35),
                      ),
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
                        color: value > 0
                            ? ConstColors.errorRed
                            : ConstColors.textColorLight,
                        size: 20.r,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 40.w,
                        minHeight: 40.h,
                      ),
                    ),
                  ),

                  SizedBox(width: 12.w),

                  // Text field for direct input
                  Expanded(
                    child: Container(
                      height: 45.h,
                      decoration: BoxDecoration(
                        color: ConstColors.lightShade,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: ConstColors.borderColor),
                      ),
                      child: TextFormField(
                        key: ValueKey(
                          '${userId}_${leaveType}_$value',
                        ), // Force rebuild when value changes
                        initialValue: value.toString(),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: getTextTheme().bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 12.h,
                          ),
                          hintText: '0',
                          suffix: Text(
                            'days',
                            style: getTextTheme().bodySmall?.copyWith(
                              color: ConstColors.primaryDeep,
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
                        validator: Validators.intInRange(0, 30),
                      ),
                    ),
                  ),

                  SizedBox(width: 12.w),

                  // Increase button
                  Container(
                    decoration: BoxDecoration(
                      color: ConstColors.successGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: ConstColors.successGreen.withValues(alpha: 0.35),
                      ),
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
                        color: value < 30
                            ? ConstColors.successGreen
                            : ConstColors.textColorLight,
                        size: 20.r,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 40.w,
                        minHeight: 40.h,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 4.h),

              // Current value display
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: ConstColors.primary,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'Current: $value days',
                  style: getTextTheme().bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
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
        if (provider.enablePrivilegeLeaves)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Privilege Leave:', style: getTextTheme().bodySmall),
              Text(
                '$finalPL days',
                style: getTextTheme().bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.successGreen,
                ),
              ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sick Leave:', style: getTextTheme().bodySmall),
            Text(
              '$finalSL days',
              style: getTextTheme().bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.successGreen,
              ),
            ),
          ],
        ),
        if (provider.enableCasualLeaves)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Casual Leave:', style: getTextTheme().bodySmall),
              Text(
                '$finalCL days',
                style: getTextTheme().bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.successGreen,
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

  /// Builds a user avatar with error handling for network images.
  /// [radius] is expected to be already scaled (e.g. `20.r`); defaults to 20.r.
  Widget _buildUserAvatar(UserModel user, {double? radius}) {
    final double avatarRadius = radius ?? 20.r;
    final hasProfileImage =
        user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty;

    if (!hasProfileImage) {
      return CircleAvatar(
        radius: avatarRadius,
        backgroundColor: ConstColors.primary,
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
          style: getTextTheme().bodyLarge?.copyWith(
            fontSize: avatarRadius * 0.8,
            fontWeight: FontWeight.bold,
            color: ConstColors.textColor,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: avatarRadius,
      backgroundColor: ConstColors.primary,
      child: ClipOval(
        child: Image.network(
          user.profileImageUrl!,
          width: avatarRadius * 2,
          height: avatarRadius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: avatarRadius,
                height: avatarRadius,
                child: AppLoadingIndicator(size: avatarRadius),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: avatarRadius * 2,
              height: avatarRadius * 2,
              color: ConstColors.primary,
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: getTextTheme().bodyLarge?.copyWith(
                    fontSize: avatarRadius * 0.8,
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
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
