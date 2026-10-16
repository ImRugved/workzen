import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_date_time_picker.dart';
import '../../constants/constant_dropdown.dart';
import '../../constants/constant_snackbar.dart';
import '../../models/holiday_model.dart';
import '../../providers/organization_provider.dart';
import '../../providers/toggle_provider.dart';
import '../../providers/value_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/app_dialog_card.dart';
import '../../widgets/holiday_calendar_card.dart';

/// Admin screen to see and manage every public holiday: pick a year, see its
/// figures, add a holiday or delete one. Holidays are listed by month.
class HolidayManagementScreen extends StatefulWidget {
  const HolidayManagementScreen({super.key});

  @override
  State<HolidayManagementScreen> createState() =>
      _HolidayManagementScreenState();
}

class _HolidayManagementScreenState extends State<HolidayManagementScreen> {
  // Year shown, scoped to this screen
  final ValueProvider<int> _year = ValueProvider<int>(DateTime.now().year);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<OrganizationProvider>(context, listen: false).start();
    });
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _year,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Holidays',
            style: getTextTheme().titleLarge?.copyWith(
              color: ConstColors.textColor,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add, size: 26.r),
              tooltip: 'Add holiday',
              onPressed: () =>
                  _showAddHolidayDialog(context.read<OrganizationProvider>()),
            ),
          ],
        ),
        body: Consumer2<OrganizationProvider, ValueProvider<int>>(
          builder: (context, org, year, _) => _buildBody(org, year.value),
        ),
      ),
    );
  }

  Widget _buildBody(OrganizationProvider org, int year) {
    if (!org.holidaysLoaded) {
      return const Center(child: AppLoadingIndicator(size: 40));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Every year that has a holiday, plus this year
    final years = {
      now.year,
      ...org.holidays.map((h) => h.date.year),
    }.toList()..sort();
    final inYear = org.holidays.where((h) => h.date.year == year).toList();
    final grouped = groupHolidaysByMonth(inYear);

    return ListView(
      padding: AppSpacing.screen,
      children: [
        ConstantDropdown<int>(
          value: year,
          label: 'Year',
          isDense: true,
          items: years,
          itemLabel: (y) => '$y',
          onChanged: (y) {
            if (y != null) _year.value = y;
          },
        ),
        SizedBox(height: 12.h),
        HolidayStatsRow(holidays: org.holidays, year: year),
        SizedBox(height: 8.h),
        if (inYear.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40.h),
            child: Column(
              children: [
                Icon(
                  Icons.event_busy,
                  size: 56.r,
                  color: ConstColors.borderColor,
                ),
                SizedBox(height: 12.h),
                Text(
                  'No holidays in $year',
                  style: getTextTheme().titleSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Tap + to add one',
                  style: getTextTheme().bodySmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            Padding(
              padding: EdgeInsets.only(top: 10.h, bottom: 2.h),
              child: Text(
                entry.key,
                style: getTextTheme().labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
            ),
            for (final holiday in entry.value)
              HolidayTile(
                holiday: holiday,
                today: today,
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 22.r,
                    color: ConstColors.errorRed,
                  ),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDeleteHoliday(holiday, org),
                ),
              ),
          ],
        SizedBox(height: 16.h),
      ],
    );
  }

  Future<void> _confirmDeleteHoliday(
    HolidayModel holiday,
    OrganizationProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialogCard(
        icon: Icons.delete_outline,
        iconColor: ConstColors.errorRed,
        title: 'Delete Holiday?',
        message: 'Remove "${holiday.name}" from the holiday calendar?',
        confirmLabel: 'Delete',
        confirmColor: ConstColors.errorRed,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );

    if (confirm != true) return;

    final success = await provider.deleteHoliday(holiday.id);
    if (success) {
      ConstantSnackbar.showSuccess(title: 'Holiday deleted');
    } else {
      ConstantSnackbar.showError(title: 'Failed to delete holiday');
    }
  }

  Future<void> _showAddHolidayDialog(OrganizationProvider provider) async {
    final result = await showModalBottomSheet<_HolidayInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddHolidaySheet(),
    );

    if (result == null) return;

    final success = await provider.addHoliday(
      result.name,
      result.date,
      description: result.description,
    );
    if (success) {
      // Show the year the new holiday landed in
      _year.value = result.date.year;
      ConstantSnackbar.showSuccess(title: 'Holiday added');
    } else {
      ConstantSnackbar.showError(title: 'Failed to add holiday');
    }
  }
}

class _HolidayInput {
  final String name;
  final DateTime date;
  final String? description;

  _HolidayInput(this.name, this.date, this.description);
}

// Bottom sheet with the add holiday form. Owns its controllers so they are
// disposed only after the sheet's close animation has finished.
class _AddHolidaySheet extends StatefulWidget {
  const _AddHolidaySheet();

  @override
  State<_AddHolidaySheet> createState() => _AddHolidaySheetState();
}

class _AddHolidaySheetState extends State<_AddHolidaySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  // Picked date and whether to flag it as missing, scoped to this sheet
  final ValueProvider<DateTime?> _selectedDate = ValueProvider<DateTime?>(null);
  final ToggleProvider _dateMissing = ToggleProvider();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _selectedDate.dispose();
    _dateMissing.dispose();
    super.dispose();
  }

  void _save() {
    final date = _selectedDate.value;
    final nameValid = _formKey.currentState?.validate() ?? false;
    _dateMissing.set(date == null);
    if (!nameValid || date == null) return;

    final description = _descController.text.trim();
    Navigator.of(context).pop(
      _HolidayInput(
        _nameController.text.trim(),
        date,
        description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Form(
            key: _formKey,
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
                Row(
                  children: [
                    Container(
                      width: 40.r,
                      height: 40.r,
                      decoration: BoxDecoration(
                        color: ConstColors.lightShade,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.event,
                        size: 22.r,
                        color: ConstColors.primaryDeep,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Holiday',
                            style: getTextTheme().titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: ConstColors.textColor,
                            ),
                          ),
                          Text(
                            'Shown to every employee',
                            style: getTextTheme().labelSmall?.copyWith(
                              color: ConstColors.textColorLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.required('holiday name'),
                  decoration: const InputDecoration(
                    labelText: 'Holiday name',
                    hintText: 'e.g. Independence Day',
                  ),
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                SizedBox(height: 12.h),
                ChangeNotifierProvider.value(
                  value: _selectedDate,
                  child: ChangeNotifierProvider.value(
                    value: _dateMissing,
                    child: Consumer2<ValueProvider<DateTime?>, ToggleProvider>(
                      builder: (context, picked, missing, _) =>
                          ConstantDatePicker(
                            label: 'Date',
                            value: picked.value,
                            format: 'EEEE, dd MMM yyyy',
                            firstDate: DateTime(DateTime.now().year - 1),
                            lastDate: DateTime(DateTime.now().year + 3),
                            errorText: missing.value && picked.value == null
                                ? 'Select the holiday date'
                                : null,
                            onChanged: (date) {
                              picked.value = date;
                              missing.set(false);
                            },
                          ),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: ConstantButton(
                        text: 'Cancel',
                        isOutlined: true,
                        backgroundColor: ConstColors.primary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ConstantButton(
                        text: 'Save',
                        backgroundColor: ConstColors.primary,
                        onPressed: _save,
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
    );
  }
}
