import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_colors.dart';
import '../../constants/permissions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../providers/onboarding_provider.dart';
import 'leave_balances_tab.dart';
import 'update_leaves_tab.dart';

/// Manage Employee Leaves: the Leave Balances tab (every employee's leave left,
/// with the allocation editable) and the Update Leaves tab (adding leave an
/// employee already took). The Update Leaves tab is for admins and for sub
/// admins who may approve leave requests; without that permission only the
/// balances show.
class ManageEmployeeLeaveScreen extends StatefulWidget {
  const ManageEmployeeLeaveScreen({super.key});

  @override
  State<ManageEmployeeLeaveScreen> createState() =>
      _ManageEmployeeLeaveScreenState();
}

class _ManageEmployeeLeaveScreenState extends State<ManageEmployeeLeaveScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh employees and balances every time the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DashboardProvider>().loadDashboardData(
        context.read<EmployeeManagementProvider>(),
        context.read<OnboardingProvider>(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final canUpdate = context.read<AuthProvider>().can(
      Permissions.leaveRequests,
    );

    return DefaultTabController(
      length: canUpdate ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Manage Employee Leaves',
            style: getTextTheme().titleLarge?.copyWith(
              color: ConstColors.textColor,
            ),
          ),
          bottom: canUpdate
              ? TabBar(
                  indicatorColor: ConstColors.primaryDeep,
                  labelColor: ConstColors.textColor,
                  unselectedLabelColor: ConstColors.textColorLight,
                  labelStyle: getTextTheme().labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(text: 'Leave Balances'),
                    Tab(text: 'Update Leaves'),
                  ],
                )
              : null,
        ),
        body: canUpdate
            ? const TabBarView(children: [LeaveBalancesTab(), UpdateLeavesTab()])
            : const LeaveBalancesTab(),
      ),
    );
  }
}
