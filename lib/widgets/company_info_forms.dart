import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_date_time_picker.dart';
import '../constants/constant_dropdown.dart';
import '../constants/constant_snackbar.dart';
import '../models/announcement_model.dart';
import '../models/employee_model.dart';
import '../providers/auth_provider.dart';
import '../providers/company_info_provider.dart';
import '../providers/employee_management_provider.dart';
import '../providers/value_provider.dart';
import '../utils/validators.dart';

/// The bottom sheets of the Info page: post an announcement, choose the
/// employee of the month, write a company rule. Each one saves through
/// [CompanyInfoProvider] and closes itself when that works.
class CompanyInfoForms {
  CompanyInfoForms._();

  static Future<void> _open(BuildContext context, Widget sheet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }

  static Future<void> addAnnouncement(BuildContext context) =>
      _open(context, const _AnnouncementSheet());

  static Future<void> setEmployeeOfMonth(BuildContext context) =>
      _open(context, const _EmployeeOfMonthSheet());

  /// Gives an announcement a new end time (and switches it on again).
  static Future<void> extendAnnouncement(
    BuildContext context,
    AnnouncementModel announcement,
  ) => _open(context, _ExtendSheet(announcement: announcement));

}

/// Shared look of the sheets: drag handle, icon and title, then the form.
class _SheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SheetFrame({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    child: Icon(icon, size: 22.r, color: ConstColors.primaryDeep),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: getTextTheme().titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ConstColors.textColor,
                          ),
                        ),
                        Text(
                          subtitle,
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
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// --- Announcement ---

/// The date and time an announcement ends, as one combined moment.
DateTime _combine(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

/// "Ends on" date and time fields, side by side.
class _EndTimeFields extends StatelessWidget {
  final ValueProvider<DateTime> date;
  final ValueProvider<TimeOfDay> time;

  const _EndTimeFields({required this.date, required this.time});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: ChangeNotifierProvider.value(
            value: date,
            child: Consumer<ValueProvider<DateTime>>(
              builder: (context, day, _) => ConstantDatePicker(
                label: 'Active until',
                value: day.value,
                format: 'dd MMM yyyy',
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                onChanged: (picked) => day.value = picked,
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          flex: 2,
          child: ChangeNotifierProvider.value(
            value: time,
            child: Consumer<ValueProvider<TimeOfDay>>(
              builder: (context, at, _) => ConstantTimePicker(
                label: 'At',
                value: at.value,
                onChanged: (picked) => at.value = picked,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sheet to give an announcement a new end time. It becomes active again.
class _ExtendSheet extends StatefulWidget {
  final AnnouncementModel announcement;

  const _ExtendSheet({required this.announcement});

  @override
  State<_ExtendSheet> createState() => _ExtendSheetState();
}

class _ExtendSheetState extends State<_ExtendSheet> {
  late final ValueProvider<DateTime> _endDate;
  late final ValueProvider<TimeOfDay> _endTime;

  @override
  void initState() {
    super.initState();
    // Start from the current end, or tomorrow when it is already past
    final current = widget.announcement.endsAt;
    final start = current != null && current.isAfter(DateTime.now())
        ? current
        : DateTime.now().add(const Duration(days: 1));
    _endDate = ValueProvider<DateTime>(start);
    _endTime = ValueProvider<TimeOfDay>(TimeOfDay.fromDateTime(start));
  }

  @override
  void dispose() {
    _endDate.dispose();
    _endTime.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final endsAt = _combine(_endDate.value, _endTime.value);
    if (!endsAt.isAfter(DateTime.now())) {
      ConstantSnackbar.showError(title: 'The end time must be in the future');
      return;
    }

    final saved = await context.read<CompanyInfoProvider>().extendAnnouncement(
      widget.announcement.id,
      endsAt,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      ConstantSnackbar.showSuccess(title: 'Announcement is active again');
    } else {
      ConstantSnackbar.showError(title: 'Failed to save');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      icon: Icons.schedule,
      title: 'Change End Time',
      subtitle: widget.announcement.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EndTimeFields(date: _endDate, time: _endTime),
          SizedBox(height: 16.h),
          Consumer<CompanyInfoProvider>(
            builder: (context, info, _) => ConstantButton(
              text: 'Save and Activate',
              isLoading: info.isSaving,
              onPressed: info.isSaving ? null : _save,
              backgroundColor: ConstColors.primary,
              textColor: ConstColors.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementSheet extends StatefulWidget {
  const _AnnouncementSheet();

  @override
  State<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends State<_AnnouncementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _picker = ImagePicker();
  // The picture chosen so far (scoped state, no setState)
  final ValueProvider<Uint8List?> _image = ValueProvider<Uint8List?>(null);
  // When the announcement stops being shown: tomorrow, at this time of day
  final ValueProvider<DateTime> _endDate = ValueProvider<DateTime>(
    DateTime.now().add(const Duration(days: 1)),
  );
  final ValueProvider<TimeOfDay> _endTime = ValueProvider<TimeOfDay>(
    TimeOfDay.now(),
  );

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _image.dispose();
    _endDate.dispose();
    _endTime.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (picked == null) return;
      _image.value = await picked.readAsBytes();
    } catch (e) {
      ConstantSnackbar.showError(title: 'Could not open the picture: $e');
    }
  }

  Future<void> _post() async {
    if (!_formKey.currentState!.validate()) return;

    final endsAt = _combine(_endDate.value, _endTime.value);
    if (!endsAt.isAfter(DateTime.now())) {
      ConstantSnackbar.showError(title: 'The end time must be in the future');
      return;
    }

    final info = context.read<CompanyInfoProvider>();
    final admin = context.read<AuthProvider>().userModel;
    final saved = await info.addAnnouncement(
      title: _title.text.trim(),
      message: _message.text.trim(),
      postedBy: admin?.name ?? 'Admin',
      posterId: admin?.id ?? '',
      endsAt: endsAt,
      imageBytes: _image.value,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      ConstantSnackbar.showSuccess(title: 'Announcement posted');
    } else {
      ConstantSnackbar.showError(
        title: 'Failed to post. Check the internet and the pictures bucket.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      icon: Icons.campaign_outlined,
      title: 'New Announcement',
      subtitle: 'Shown to everyone until the end time, and they are notified',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              validator: Validators.required('a title'),
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _message,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              validator: Validators.required('the message'),
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            SizedBox(height: 12.h),
            _EndTimeFields(date: _endDate, time: _endTime),
            SizedBox(height: 12.h),
            ChangeNotifierProvider.value(
              value: _image,
              child: Consumer<ValueProvider<Uint8List?>>(
                builder: (context, image, _) {
                  final bytes = image.value;
                  if (bytes == null) {
                    return ConstantButton(
                      text: 'Add a picture (optional)',
                      isOutlined: true,
                      icon: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 20.r,
                        color: ConstColors.primaryDeep,
                      ),
                      onPressed: _pickImage,
                    );
                  }
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Image.memory(
                          bytes,
                          width: double.infinity,
                          height: 160.h,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6.r,
                        right: 6.r,
                        child: CircleAvatar(
                          radius: 16.r,
                          backgroundColor: ConstColors.white,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.close, size: 18.r),
                            onPressed: () => image.value = null,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: 16.h),
            Consumer<CompanyInfoProvider>(
              builder: (context, info, _) => ConstantButton(
                text: 'Post Announcement',
                isLoading: info.isSaving,
                onPressed: info.isSaving ? null : _post,
                backgroundColor: ConstColors.primary,
                textColor: ConstColors.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Employee of the month ---

class _EmployeeOfMonthSheet extends StatefulWidget {
  const _EmployeeOfMonthSheet();

  @override
  State<_EmployeeOfMonthSheet> createState() => _EmployeeOfMonthSheetState();
}

class _EmployeeOfMonthSheetState extends State<_EmployeeOfMonthSheet> {
  final _note = TextEditingController();
  late final ValueProvider<DateTime> _month;
  final ValueProvider<EmployeeModel?> _employee = ValueProvider<EmployeeModel?>(
    null,
  );

  // The current month and the 11 before it
  late final List<DateTime> _months;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = [for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i)];
    // Normally the month that has just ended is the one being chosen
    _month = ValueProvider<DateTime>(_months.first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final employees = context.read<EmployeeManagementProvider>();
      if (employees.allEmployees.isEmpty) employees.fetchAllEmployees();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _month.dispose();
    _employee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final employee = _employee.value;
    if (employee == null) {
      ConstantSnackbar.showError(title: 'Choose an employee');
      return;
    }

    final admin = context.read<AuthProvider>().userModel;
    final saved = await context.read<CompanyInfoProvider>().setEmployeeOfMonth(
      month: _month.value,
      employee: employee,
      posterId: admin?.id ?? '',
      note: _note.text,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      ConstantSnackbar.showSuccess(title: 'Employee of the month saved');
    } else {
      ConstantSnackbar.showError(title: 'Failed to save');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      icon: Icons.emoji_events_outlined,
      title: 'Employee of the Month',
      subtitle:
          'One per month. Choosing for this month also notifies everyone.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChangeNotifierProvider.value(
            value: _month,
            child: Consumer<ValueProvider<DateTime>>(
              builder: (context, month, _) => ConstantDropdown<DateTime>(
                label: 'Month',
                value: month.value,
                items: _months,
                itemLabel: (m) => DateFormat('MMMM yyyy').format(m),
                onChanged: (m) {
                  if (m != null) month.value = m;
                },
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Everyone who has been onboarded, by name
          Consumer<EmployeeManagementProvider>(
            builder: (context, employees, _) {
              final list =
                  employees.allEmployees.where((e) => e.isOnboarded).toList()
                    ..sort((a, b) => a.name.compareTo(b.name));
              return ChangeNotifierProvider.value(
                value: _employee,
                child: Consumer<ValueProvider<EmployeeModel?>>(
                  builder: (context, chosen, _) =>
                      ConstantDropdown<EmployeeModel>(
                        label: 'Employee',
                        hint: list.isEmpty ? 'Loading...' : 'Choose',
                        value: chosen.value,
                        items: list,
                        itemLabel: (e) =>
                            e.department == null || e.department!.isEmpty
                            ? e.name
                            : '${e.name} (${e.department})',
                        onChanged: (e) => chosen.value = e,
                      ),
                ),
              );
            },
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Why they were chosen (optional)',
            ),
          ),
          SizedBox(height: 16.h),
          Consumer<CompanyInfoProvider>(
            builder: (context, info, _) => ConstantButton(
              text: 'Save',
              isLoading: info.isSaving,
              onPressed: info.isSaving ? null : _save,
              backgroundColor: ConstColors.primary,
              textColor: ConstColors.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// The company rules are written on their own screen (company_rules_screen.dart).
