import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../constants/constant_dropdown.dart';
import '../models/request_model.dart';
import '../providers/request_filter_provider.dart';
import '../utils/leave_month_utils.dart';

/// The month filter (and, for an admin, the employee filter) of a request
/// list. The choices come from the requests themselves, so only months and
/// employees that have a request are offered.
class RequestExtraFilters extends StatelessWidget {
  /// Every request of the list, before any filter.
  final List<RequestModel> requests;
  final RequestFilterProvider filter;

  /// Shows the employee filter (admin view).
  final bool showEmployee;

  const RequestExtraFilters({
    super.key,
    required this.requests,
    required this.filter,
    this.showEmployee = false,
  });

  @override
  Widget build(BuildContext context) {
    // Month keys, newest first
    final monthLabels = <String, String>{
      for (final g in groupRequestsByMonth(requests))
        '${g.month.year}-${g.month.month.toString().padLeft(2, '0')}':
            DateFormat('MMMM yyyy').format(g.month),
    };
    final months = [RequestFilterProvider.all, ...monthLabels.keys];

    // Employees by name
    final names = <String, String>{};
    for (final r in requests) {
      names[r.userId] = r.userName;
    }
    final employeeIds = names.keys.toList()
      ..sort((a, b) => names[a]!.compareTo(names[b]!));
    final employees = [RequestFilterProvider.all, ...employeeIds];

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      child: Row(
        children: [
          Expanded(
            child: ConstantDropdown<String>(
              label: 'Month',
              isDense: true,
              value: months.contains(filter.selectedMonth)
                  ? filter.selectedMonth
                  : RequestFilterProvider.all,
              items: months,
              itemLabel: (m) =>
                  m == RequestFilterProvider.all ? 'All months' : monthLabels[m]!,
              onChanged: (m) {
                if (m != null) filter.setMonth(m);
              },
            ),
          ),
          if (showEmployee) ...[
            SizedBox(width: 12.w),
            Expanded(
              child: ConstantDropdown<String>(
                label: 'Employee',
                isDense: true,
                value: employees.contains(filter.selectedEmployee)
                    ? filter.selectedEmployee
                    : RequestFilterProvider.all,
                items: employees,
                itemLabel: (id) => id == RequestFilterProvider.all
                    ? 'All employees'
                    : names[id]!,
                onChanged: (id) {
                  if (id != null) filter.setEmployee(id);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
