import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_date_time_picker.dart';
import '../constants/constant_snackbar.dart';
import '../models/user_model.dart';
import '../providers/admin_attendance_filter_provider.dart';

/// What the admin chose in the filter sheet.
class AttendanceFilterSelection {
  /// Null stands for all employees.
  final String? employeeId;
  final AttendancePeriod period;
  final DateTimeRange? customRange;

  const AttendanceFilterSelection({
    required this.employeeId,
    required this.period,
    required this.customRange,
  });
}

/// Choices being made in the sheet, before Apply. Scoped to the sheet.
class _FilterDraft with ChangeNotifier {
  String? employeeId;
  AttendancePeriod period;
  DateTimeRange? range;
  String query = '';

  _FilterDraft({this.employeeId, required this.period, this.range});

  void setEmployee(String? id) {
    employeeId = id;
    notifyListeners();
  }

  void setPeriod(AttendancePeriod value) {
    period = value;
    notifyListeners();
  }

  void setRange(DateTimeRange value) {
    range = value;
    notifyListeners();
  }

  void setQuery(String value) {
    query = value.trim().toLowerCase();
    notifyListeners();
  }
}

/// Bottom sheet to filter the admin attendance: which employee (all, or one
/// found with the search) and which period (a month, two months or a date
/// range). Closing it with Apply returns the choice.
class AttendanceFilterSheet extends StatefulWidget {
  final List<UserModel> employees;
  final String? initialEmployeeId;
  final AttendancePeriod initialPeriod;
  final DateTimeRange? initialRange;

  const AttendanceFilterSheet({
    super.key,
    required this.employees,
    required this.initialEmployeeId,
    required this.initialPeriod,
    required this.initialRange,
  });

  static Future<AttendanceFilterSelection?> show(
    BuildContext context, {
    required List<UserModel> employees,
    required String? employeeId,
    required AttendancePeriod period,
    required DateTimeRange? customRange,
  }) {
    return showModalBottomSheet<AttendanceFilterSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AttendanceFilterSheet(
        employees: employees,
        initialEmployeeId: employeeId,
        initialPeriod: period,
        initialRange: customRange,
      ),
    );
  }

  @override
  State<AttendanceFilterSheet> createState() => _AttendanceFilterSheetState();
}

class _AttendanceFilterSheetState extends State<AttendanceFilterSheet> {
  // Controllers and the draft are owned here so they are disposed with the sheet
  final TextEditingController _search = TextEditingController();
  late final _FilterDraft _draft = _FilterDraft(
    employeeId: widget.initialEmployeeId,
    period: widget.initialPeriod,
    range: widget.initialRange,
  );

  @override
  void dispose() {
    _search.dispose();
    _draft.dispose();
    super.dispose();
  }

  void _apply() {
    if (_draft.period == AttendancePeriod.custom && _draft.range == null) {
      ConstantSnackbar.showError(title: 'Select the from and to dates');
      return;
    }
    Navigator.of(context).pop(
      AttendanceFilterSelection(
        employeeId: _draft.employeeId,
        period: _draft.period,
        customRange: _draft.range,
      ),
    );
  }

  void _reset() {
    Navigator.of(context).pop(
      const AttendanceFilterSelection(
        employeeId: null,
        period: AttendancePeriod.today,
        customRange: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _draft,
      child: Padding(
        // Lifts the sheet above the keyboard
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: ConstColors.borderColor,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Filter Attendance',
                    style: getTextTheme().titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ConstColors.textColor,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  _sectionTitle('Employee'),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _search,
                    onChanged: _draft.setQuery,
                    decoration: InputDecoration(
                      hintText: 'Search employee by name or ID',
                      prefixIcon: Icon(Icons.search, size: 20.r),
                      isDense: true,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _employeeList(),
                  SizedBox(height: 16.h),
                  _sectionTitle('Period'),
                  SizedBox(height: 8.h),
                  _periodChips(),
                  _customRange(),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Expanded(
                        child: ConstantButton(
                          text: 'Reset',
                          isOutlined: true,
                          backgroundColor: ConstColors.primary,
                          onPressed: _reset,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ConstantButton(
                          text: 'Apply',
                          backgroundColor: ConstColors.primary,
                          onPressed: _apply,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: getTextTheme().labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: ConstColors.textColor,
    ),
  );

  // "All employees" and the matches of the search, one tappable row each
  Widget _employeeList() {
    return Consumer<_FilterDraft>(
      builder: (context, draft, _) {
        final matches = widget.employees.where((e) {
          if (draft.query.isEmpty) return true;
          return e.name.toLowerCase().contains(draft.query) ||
              (e.employeeId ?? '').toLowerCase().contains(draft.query);
        }).toList();

        return Container(
          constraints: BoxConstraints(maxHeight: 200.h),
          decoration: BoxDecoration(
            border: Border.all(color: ConstColors.borderColor),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: Material(
              type: MaterialType.transparency,
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  _employeeRow(
                    label: 'All employees',
                    subtitle: '${widget.employees.length} employees',
                    selected: draft.employeeId == null,
                    onTap: () => draft.setEmployee(null),
                  ),
                  for (final e in matches)
                    _employeeRow(
                      label: e.name,
                      subtitle: [
                        if (e.employeeId != null) e.employeeId!,
                        if (e.department != null) e.department!,
                      ].join(' • '),
                      selected: draft.employeeId == e.id,
                      onTap: () => draft.setEmployee(e.id),
                    ),
                  if (matches.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      child: Center(
                        child: Text(
                          'No employee found',
                          style: getTextTheme().bodySmall?.copyWith(
                            color: ConstColors.textColorLight,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _employeeRow({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected
            ? ConstColors.primary.withValues(alpha: 0.2)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: getTextTheme().bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ConstColors.textColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: getTextTheme().labelSmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 20.r, color: ConstColors.primaryDeep),
          ],
        ),
      ),
    );
  }

  Widget _periodChips() {
    return Consumer<_FilterDraft>(
      builder: (context, draft, _) => Wrap(
        spacing: 8.w,
        runSpacing: 6.h,
        children: [
          for (final period in AttendancePeriod.values)
            ChoiceChip(
              label: Text(
                period.label,
                style: getTextTheme().labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
              selected: draft.period == period,
              selectedColor: ConstColors.primary.withValues(alpha: 0.35),
              backgroundColor: ConstColors.cardBackground,
              showCheckmark: false,
              side: BorderSide(
                color: draft.period == period
                    ? ConstColors.primaryDeep
                    : ConstColors.borderColor,
              ),
              onSelected: (_) => draft.setPeriod(period),
            ),
        ],
      ),
    );
  }

  // The from / to dates, shown only for "Date range"
  Widget _customRange() {
    return Consumer<_FilterDraft>(
      builder: (context, draft, _) {
        if (draft.period != AttendancePeriod.custom) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.only(top: 12.h),
          child: ConstantDateRangePicker(
            label: 'From - To',
            value: draft.range,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            onChanged: draft.setRange,
          ),
        );
      },
    );
  }
}
