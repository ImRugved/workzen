import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_colors.dart';
import '../../constants/permissions.dart';
import '../../models/employee_of_month_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_info_provider.dart';
import '../../providers/value_provider.dart';
import '../../widgets/company_info_forms.dart';
import '../../widgets/employee_of_month_widgets.dart';

/// Every month's employee of the month, latest first: the one of this month
/// (active), ones switched off by hand (inactive) and earlier months (ended),
/// which stay here as history. A chip row filters by state and counts each.
/// An editor swipes a card left to switch it off or on again; nothing is
/// deleted. Choosing someone for a month is the button in the corner.
class EmployeeOfMonthScreen extends StatefulWidget {
  const EmployeeOfMonthScreen({super.key});

  @override
  State<EmployeeOfMonthScreen> createState() => _EmployeeOfMonthScreenState();
}

class _EmployeeOfMonthScreenState extends State<EmployeeOfMonthScreen> {
  // The chosen state filter, null for all (scoped state, no setState)
  final ValueProvider<EmployeeOfMonthStatus?> _filter =
      ValueProvider<EmployeeOfMonthStatus?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyInfoProvider>().start();
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  String _label(EmployeeOfMonthStatus? status) => switch (status) {
    null => 'All',
    EmployeeOfMonthStatus.active => 'Active',
    EmployeeOfMonthStatus.inactive => 'Inactive',
    EmployeeOfMonthStatus.expired => 'Ended',
  };

  @override
  Widget build(BuildContext context) {
    final canEdit = context.select<AuthProvider, bool>(
      (auth) => auth.can(Permissions.companyInfo),
    );

    return ChangeNotifierProvider.value(
      value: _filter,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Employee of the Month',
            style: getTextTheme().titleLarge?.copyWith(
              color: ConstColors.textColor,
            ),
          ),
        ),
        backgroundColor: ConstColors.backgroundColor,
        floatingActionButton: canEdit
            ? FloatingActionButton.extended(
                onPressed: () => CompanyInfoForms.setEmployeeOfMonth(context),
                icon: Icon(
                  Icons.add,
                  size: 20.r,
                  color: ConstColors.textColor,
                ),
                label: Text(
                  'Choose',
                  style: getTextTheme().labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ConstColors.textColor,
                  ),
                ),
                backgroundColor: ConstColors.primary,
                foregroundColor: ConstColors.textColor,
              )
            : null,
        body:
            Consumer2<
              CompanyInfoProvider,
              ValueProvider<EmployeeOfMonthStatus?>
            >(
              builder: (context, info, filter, _) {
                if (!info.monthsLoaded) {
                  return const Center(child: AppLoadingIndicator(size: 40));
                }

                final now = DateTime.now();
                int count(EmployeeOfMonthStatus? status) => status == null
                    ? info.months.length
                    : info.months.where((m) => m.statusAt(now) == status).length;

                final shown = filter.value == null
                    ? info.months
                    : info.months
                          .where((m) => m.statusAt(now) == filter.value)
                          .toList();

                return ListView(
                  padding: AppSpacing.screen,
                  children: [
                    Wrap(
                      spacing: 8.w,
                      children: [
                        for (final status in <EmployeeOfMonthStatus?>[
                          null,
                          EmployeeOfMonthStatus.active,
                          EmployeeOfMonthStatus.inactive,
                          EmployeeOfMonthStatus.expired,
                        ])
                          ChoiceChip(
                            label: Text('${_label(status)} (${count(status)})'),
                            selected: filter.value == status,
                            onSelected: (_) => filter.value = status,
                          ),
                      ],
                    ),
                    if (canEdit && info.months.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(
                        'Swipe a card left to switch it off or on. Earlier '
                        'months stay here as history.',
                        style: getTextTheme().labelSmall?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                      ),
                    ],
                    SizedBox(height: 8.h),
                    if (shown.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        child: Center(
                          child: Text(
                            info.months.isEmpty
                                ? 'Nobody has been chosen yet'
                                : 'Nothing under ${_label(filter.value).toLowerCase()}',
                            style: getTextTheme().bodyMedium?.copyWith(
                              color: ConstColors.textColorLight,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final record in shown)
                        EmployeeOfMonthTile(record: record, canEdit: canEdit),
                    // Room so the Choose button never covers the last card
                    SizedBox(height: 70.h),
                  ],
                );
              },
            ),
      ),
    );
  }
}
