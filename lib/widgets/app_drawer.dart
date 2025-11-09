import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../constants/const_textstyle.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isAdmin = authProvider.isAdmin;

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
                            const CircularProgressIndicator(),
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
            _buildDrawerItem(
              context,
              'Leave Requests',
              Icons.assignment,
              () => Get.toNamed('/leave_requests_screen'),
            ),
            _buildDrawerItem(
              context,
              'Employee Attendance',
              Icons.people,
              () => Get.toNamed('/admin_attendance_screen'),
            ),
            _buildDrawerItem(
              context,
              'Employee Onboarding',
              Icons.person_add,
              () => Get.toNamed('/employee_onboarding_screen'),
            ),
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
          _buildDrawerItem(context, 'Logout', Icons.logout, () async {
            // Show confirmation dialog
            bool? confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await authProvider.logout();
              if (context.mounted) {
                Get.offAllNamed('/login_screen');
              }
            }
          }),
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
}
