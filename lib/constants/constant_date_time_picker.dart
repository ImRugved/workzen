import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'constant_colors.dart';
import 'const_textstyle.dart';

/// The app's date, time and date range pickers. Use these everywhere instead
/// of calling showDatePicker / showTimePicker / showDateRangePicker directly,
/// so the dialogs share one theme.
///
/// Each has two forms:
/// - a field widget ([ConstantDatePicker], [ConstantTimePicker],
///   [ConstantDateRangePicker]) that shows the chosen value in an outlined box
///   and opens the dialog on tap;
/// - a static `pick` for places that open the dialog from their own widget.

/// Wraps a picker dialog in the app colours.
Widget _themed(BuildContext context, Widget? child) {
  final base = Theme.of(context);
  return Theme(
    data: base.copyWith(
      // White dialog, black text; the deeper blue marks the selection so it
      // stays visible on white
      colorScheme: base.colorScheme.copyWith(
        primary: ConstColors.primaryDeep,
        onPrimary: ConstColors.white,
        surface: ConstColors.white,
        onSurface: ConstColors.textColor,
        onSurfaceVariant: ConstColors.textColor,
        surfaceTint: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: ConstColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: ConstColors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: ConstColors.white,
        headerForegroundColor: ConstColors.textColor,
        dividerColor: ConstColors.borderColor,
        rangePickerBackgroundColor: ConstColors.white,
        rangePickerSurfaceTintColor: Colors.transparent,
        rangeSelectionBackgroundColor: ConstColors.lightShade,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: ConstColors.white,
        hourMinuteTextColor: ConstColors.textColor,
        dayPeriodTextColor: ConstColors.textColor,
        dialTextColor: ConstColors.textColor,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ConstColors.primaryDeep),
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

/// The outlined, tappable box the three field widgets share.
class _PickerBox extends StatelessWidget {
  final String? label;
  final String text;
  final bool hasValue;
  final IconData icon;
  final VoidCallback? onTap;
  final String? errorText;
  final bool isDense;

  const _PickerBox({
    required this.label,
    required this.text,
    required this.hasValue,
    required this.icon,
    required this.onTap,
    required this.errorText,
    required this.isDense,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10.r);
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: getTextTheme().bodyMedium?.copyWith(
            color: ConstColors.textColor,
          ),
          errorText: errorText,
          isDense: isDense,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: isDense ? 10.h : 14.h,
          ),
          suffixIcon: Icon(icon, size: 20.r, color: ConstColors.textColor),
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: ConstColors.darkGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: ConstColors.darkGrey),
          ),
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: getTextTheme().bodyMedium?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
      ),
    );
  }
}

/// Date field. [value] null shows [hint].
class ConstantDatePicker extends StatelessWidget {
  final String? label;
  final String hint;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String format;
  final bool isDense;
  final bool isEnabled;
  final String? errorText;

  const ConstantDatePicker({
    super.key,
    required this.onChanged,
    this.label,
    this.hint = 'Select date',
    this.value,
    this.firstDate,
    this.lastDate,
    this.format = 'dd/MM/yyyy',
    this.isDense = false,
    this.isEnabled = true,
    this.errorText,
  });

  /// Opens the date dialog; null when dismissed.
  static Future<DateTime?> pick(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final first = firstDate ?? DateTime(2000);
    final last = lastDate ?? DateTime.now().add(const Duration(days: 365 * 5));
    var initial = initialDate ?? DateTime.now();
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: _themed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PickerBox(
      label: label,
      text: value == null ? hint : DateFormat(format).format(value!),
      hasValue: value != null,
      icon: Icons.calendar_today,
      isDense: isDense,
      errorText: errorText,
      onTap: isEnabled
          ? () async {
              final picked = await pick(
                context,
                initialDate: value,
                firstDate: firstDate,
                lastDate: lastDate,
              );
              if (picked != null) onChanged(picked);
            }
          : null,
    );
  }
}

/// Time field. [value] null shows [hint].
class ConstantTimePicker extends StatelessWidget {
  final String? label;
  final String hint;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;
  final TimeOfDay defaultTime;
  final bool isDense;
  final bool isEnabled;
  final String? errorText;

  const ConstantTimePicker({
    super.key,
    required this.onChanged,
    this.label,
    this.hint = 'Select time',
    this.value,
    this.defaultTime = const TimeOfDay(hour: 10, minute: 0),
    this.isDense = false,
    this.isEnabled = true,
    this.errorText,
  });

  /// Opens the time dialog; null when dismissed.
  static Future<TimeOfDay?> pick(
    BuildContext context, {
    TimeOfDay? initialTime,
  }) {
    return showTimePicker(
      context: context,
      initialTime: initialTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: _themed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PickerBox(
      label: label,
      text: value == null ? hint : value!.format(context),
      hasValue: value != null,
      icon: Icons.access_time,
      isDense: isDense,
      errorText: errorText,
      onTap: isEnabled
          ? () async {
              final picked = await pick(
                context,
                initialTime: value ?? defaultTime,
              );
              if (picked != null) onChanged(picked);
            }
          : null,
    );
  }
}

/// Date range field (from - to).
class ConstantDateRangePicker extends StatelessWidget {
  final String? label;
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String format;
  final bool isDense;
  final bool isEnabled;

  const ConstantDateRangePicker({
    super.key,
    required this.onChanged,
    this.label,
    this.value,
    this.firstDate,
    this.lastDate,
    this.format = 'dd MMM yyyy',
    this.isDense = false,
    this.isEnabled = true,
  });

  /// Opens the date range dialog; null when dismissed.
  static Future<DateTimeRange?> pick(
    BuildContext context, {
    DateTimeRange? initialRange,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365 * 5)),
      builder: _themed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat(format);
    return _PickerBox(
      label: label,
      text: value == null
          ? 'Select dates'
          : '${fmt.format(value!.start)}  -  ${fmt.format(value!.end)}',
      hasValue: value != null,
      icon: Icons.date_range,
      isDense: isDense,
      errorText: null,
      onTap: isEnabled
          ? () async {
              final picked = await pick(
                context,
                initialRange: value,
                firstDate: firstDate,
                lastDate: lastDate,
              );
              if (picked != null) onChanged(picked);
            }
          : null,
    );
  }
}
