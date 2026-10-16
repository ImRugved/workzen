import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/toggle_provider.dart';
import '../constants/apploading_indicator.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_snackbar.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../constants/permissions.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Logging out flag (scoped state, no setState)
  final ToggleProvider _loggingOut = ToggleProvider();

  @override
  void dispose() {
    _loggingOut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isAdmin = authProvider.isAdmin || (authProvider.userModel?.isSubAdmin == true);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.indigo),
            accountName: Text(
              authProvider.userModel?.name ?? "User",
              style: getTextTheme().titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              authProvider.userModel?.email ?? "",
              style: getTextTheme().bodyMedium?.copyWith(color: Colors.white70),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 30.r,
              child:
                  authProvider.userModel?.profileImageUrl != null &&
                      authProvider.userModel!.profileImageUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: authProvider.userModel!.profileImageUrl!,
                        width: 60.w,
                        height: 60.w,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const AppLoadingIndicator(size: 24),
                        errorWidget: (context, url, error) => Text(
                          authProvider.userModel?.name.isNotEmpty == true
                              ? authProvider.userModel!.name[0].toUpperCase()
                              : "U",
                          style: getTextTheme().headlineSmall?.copyWith(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    )
                  : Text(
                      authProvider.userModel?.name.isNotEmpty == true
                          ? authProvider.userModel!.name[0].toUpperCase()
                          : "U",
                      style: getTextTheme().headlineSmall?.copyWith(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
            ),
          ),
          if (isAdmin) ...[
            _buildDrawerItem(
              context,
              'Dashboard',
              Icons.dashboard,
              () => Get.offNamed('/admin_dashboard'),
            ),
            // Admins and sub admins punch in / out like everyone else
            _buildDrawerItem(
              context,
              'My Attendance',
              Icons.fingerprint,
              () => Get.toNamed('/attendance_screen'),
            ),
            _buildDrawerItem(
              context,
              'My Attendance History',
              Icons.access_time,
              () => Get.toNamed('/attendance_history_screen'),
            ),
            // A sub admin only sees what the admin granted
            if (authProvider.can(Permissions.leaveRequests))
              _buildDrawerItem(
                context,
                'Leave Requests',
                Icons.assignment,
                () => Get.toNamed('/leave_requests_screen'),
              ),
            if (authProvider.can(Permissions.viewAttendance))
              _buildDrawerItem(
                context,
                'Employee Attendance',
                Icons.people,
                () => Get.toNamed('/admin_attendance_screen'),
              ),
            if (authProvider.can(Permissions.onboarding))
              _buildDrawerItem(
                context,
                'Employee Onboarding',
                Icons.person_add,
                () => Get.toNamed('/employee_onboarding_screen'),
              ),
            if (authProvider.can(Permissions.manageEmployees) ||
                authProvider.can(Permissions.addEmployee))
              _buildDrawerItem(
                context,
                'Employee Management',
                Icons.manage_accounts,
                () => Get.toNamed('/employee_management_screen'),
              ),
          ] else ...[
            _buildDrawerItem(
              context,
              'Dashboard',
              Icons.dashboard,
              () => Get.offNamed('/user_dashboard'),
            ),
            _buildDrawerItem(
              context,
              'Apply Leave',
              Icons.add_circle_outline,
              () => Get.toNamed('/apply_leave_screen'),
            ),
            _buildDrawerItem(
              context,
              'Leave History',
              Icons.history,
              () => Get.toNamed('/leave_history_screen'),
            ),
            _buildDrawerItem(
              context,
              'Attendance',
              Icons.fingerprint,
              () => Get.toNamed('/attendance_screen'),
            ),
            _buildDrawerItem(
              context,
              'Attendance History',
              Icons.access_time,
              () => Get.toNamed('/attendance_history_screen'),
            ),
          ],
          const Divider(),
          _buildDrawerItem(
            context,
            'Check for Updates',
            Icons.system_update,
            () async {
              Get.toNamed('/update_check_screen');
            },
          ),
          _buildLogoutItem(context, authProvider),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo, size: 22.r),
      title: Text(
        title,
        style: getTextTheme().bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutItem(BuildContext context, AuthProvider authProvider) {
    // The tile shows a spinner while logging out; the flag is scoped to the drawer
    return ChangeNotifierProvider.value(
      value: _loggingOut,
      child: Consumer<ToggleProvider>(
        builder: (context, loggingOut, _) => ListTile(
          leading: Icon(Icons.logout, color: Colors.indigo, size: 22.r),
          title: Text(
            'Logout',
            style: getTextTheme().bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: loggingOut.value
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const AppLoadingIndicator(size: 20),
                )
              : null,
          enabled: !loggingOut.value,
          onTap: () => _confirmAndLogout(context, authProvider),
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ConstantButton(
            text: 'Logout',
            onPressed: () => Navigator.of(dialogContext).pop(true),
            backgroundColor: ConstColors.errorRed,
            isFullWidth: false,
            height: 40.h,
          ),
        ],
      ),
    );

    if (confirm != true || _loggingOut.value) return;

    _loggingOut.set(true);
    try {
      await authProvider.logout();
      Get.offAllNamed('/login_screen');
    } catch (e) {
      _loggingOut.set(false);
      ConstantSnackbar.showError(title: 'Logout failed: $e');
    }
  }
}
