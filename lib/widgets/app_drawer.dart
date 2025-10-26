import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';

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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(authProvider.userModel?.email ?? ""),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 30,
              child:
                  authProvider.userModel?.profileImageUrl != null &&
                      authProvider.userModel!.profileImageUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: authProvider.userModel!.profileImageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => Text(
                          authProvider.userModel?.name.isNotEmpty == true
                              ? authProvider.userModel!.name[0].toUpperCase()
                              : "U",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      authProvider.userModel?.name.isNotEmpty == true
                          ? authProvider.userModel!.name[0].toUpperCase()
                          : "U",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
            ),
          ),
          _buildDrawerItem(
            context,
            'Profile',
            Icons.person,
            () => Get.toNamed('/profile_screen'),
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
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
