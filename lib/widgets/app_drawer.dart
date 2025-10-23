import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/admin_attendance_screen.dart';
import '../screens/admin/leave_requests_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/user/apply_leave_screen.dart';
import '../screens/user/attendance_screen.dart';
import '../screens/user/attendance_history_screen.dart';
import '../screens/user/leave_history_screen.dart';
import '../screens/user/user_dashboard.dart';
import '../screens/update_check_screen.dart';

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
            decoration: const BoxDecoration(
              color: Colors.indigo,
            ),
            accountName: Text(
              authProvider.userModel?.name ?? "User",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(authProvider.userModel?.email ?? ""),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
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
          if (isAdmin) ...[
            _buildDrawerItem(
              context,
              'Dashboard',
              Icons.dashboard,
              () => _navigateTo(context, const AdminDashboard()),
            ),
            _buildDrawerItem(
              context,
              'Leave Requests',
              Icons.assignment,
              () => _navigateTo(context, const LeaveRequestsScreen()),
            ),
            _buildDrawerItem(
              context,
              'Employee Attendance',
              Icons.people,
              () => _navigateTo(context, const AdminAttendanceScreen()),
            ),
          ] else ...[
            _buildDrawerItem(
              context,
              'Dashboard',
              Icons.dashboard,
              () => _navigateTo(context, const UserDashboard()),
            ),
            _buildDrawerItem(
              context,
              'Apply Leave',
              Icons.add_circle_outline,
              () => _navigateTo(context, const ApplyLeaveScreen()),
            ),
            _buildDrawerItem(
              context,
              'Leave History',
              Icons.history,
              () => _navigateTo(context, const LeaveHistoryScreen()),
            ),
            _buildDrawerItem(
              context,
              'Attendance',
              Icons.fingerprint,
              () => _navigateTo(context, const AttendanceScreen()),
            ),
            _buildDrawerItem(
              context,
              'Attendance History',
              Icons.access_time,
              () => _navigateTo(context, const AttendanceHistoryScreen()),
            ),
          ],
          const Divider(),
          _buildDrawerItem(
            context,
            'Check for Updates',
            Icons.system_update,
            () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UpdateCheckScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            context,
            'Logout',
            Icons.logout,
            () async {
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
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
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
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    // Close the drawer first
    Navigator.pop(context);

    // Get the current route name
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    final String targetRoute = screen.runtimeType.toString();

    // If we're already on this screen, don't navigate
    if (currentRoute == targetRoute) {
      return;
    }

    // Check if this is a dashboard screen
    bool isDashboard = screen is AdminDashboard || screen is UserDashboard;

    if (isDashboard) {
      // For dashboard screens, use pushReplacement to clear the stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => screen,
          settings: RouteSettings(name: targetRoute),
        ),
      );
    } else {
      // For all other screens (LeaveRequestsScreen, ApplyLeaveScreen, LeaveHistoryScreen),
      // use push to maintain the back stack
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => screen,
          settings: RouteSettings(name: targetRoute),
        ),
      );
    }
  }
}
