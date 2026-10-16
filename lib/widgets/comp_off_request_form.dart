import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_date_time_picker.dart';
import '../constants/constant_snackbar.dart';
import '../utils/validators.dart';
import '../providers/auth_provider.dart';
import '../providers/comp_off_form_provider.dart';
import '../providers/request_provider.dart';
import '../constants/constant_button.dart';

/// Form shown on the Apply Leave screen when "Apply Comp Off" is chosen. The
/// employee picks the day they worked (for example a holiday), whether it was
/// a full or half day, and for a half day the time they worked. The request
/// goes to admins and to sub admins allowed to approve; on approval the credit
/// is added and appears as "Comp Off" in the leave type list.
///
/// The form values live in [CompOffFormProvider]; this widget only owns the
/// form key and the reason controller.
class CompOffRequestForm extends StatefulWidget {
  const CompOffRequestForm({super.key});

  @override
  State<CompOffRequestForm> createState() => _CompOffRequestFormState();
}

class _CompOffRequestFormState extends State<CompOffRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final form = context.read<CompOffFormProvider>();
    final timeError = form.timeError;
    if (timeError != null) {
      ConstantSnackbar.showError(title: timeError);
      return;
    }

    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    final requests = context.read<RequestProvider>();

    form.setSubmitting(true);
    final error = await requests.applyCompOff(
      user,
      form.workedDate,
      form.isHalfDay,
      _reasonController.text.trim(),
      compOffDate: form.compOffDate,
      fromTime: form.fromTime,
      toTime: form.toTime,
    );
    if (!mounted) return;
    form.setSubmitting(false);

    if (error == null) {
      ConstantSnackbar.showSuccess(title: 'Comp off request submitted');
      Get.back();
    } else {
      ConstantSnackbar.showError(title: error);
    }
  }

  Widget _label(String text) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(
      text,
      style: getTextTheme().titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CompOffFormProvider(),
      child: Builder(builder: _buildForm),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.teal, size: 20.r),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Worked on a holiday or weekly off? Request comp off for that day. '
                    'Once approved, "Comp Off" with your balance appears in the leave type list.',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          _label('Date Worked'),
          Selector<CompOffFormProvider, DateTime>(
            selector: (_, p) => p.workedDate,
            builder: (context, date, _) {
              final now = DateTime.now();
              return ConstantDatePicker(
                value: date,
                firstDate: DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).subtract(const Duration(days: 90)),
                lastDate: now,
                onChanged: context.read<CompOffFormProvider>().setWorkedDate,
              );
            },
          ),
          SizedBox(height: 16.h),

          _label('Comp Off Date (day you want off)'),
          // The day off asked for in return: after the day worked, up to a year ahead
          Selector<CompOffFormProvider, (DateTime, DateTime)>(
            selector: (_, p) => (p.workedDate, p.compOffDate),
            builder: (context, dates, _) {
              final firstDay = dates.$1.add(const Duration(days: 1));
              return ConstantDatePicker(
                value: dates.$2,
                firstDate: DateTime(firstDay.year, firstDay.month, firstDay.day),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                onChanged: context.read<CompOffFormProvider>().setCompOffDate,
              );
            },
          ),
          SizedBox(height: 16.h),

          _label('Duration Worked'),
          Selector<CompOffFormProvider, bool>(
            selector: (_, p) => p.isHalfDay,
            builder: (context, isHalfDay, _) => Row(
              children: [
                for (final half in [false, true])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: half ? 0 : 12.w),
                      child: InkWell(
                        onTap: () =>
                            context.read<CompOffFormProvider>().setHalfDay(half),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: isHalfDay == half
                                ? Colors.teal.shade50
                                : Colors.white,
                            border: Border.all(
                              color: isHalfDay == half
                                  ? Colors.teal
                                  : Colors.grey.shade300,
                              width: isHalfDay == half ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Center(
                            child: Text(
                              half ? 'Half Day' : 'Full Day',
                              style: getTextTheme().bodyMedium?.copyWith(
                                fontWeight: isHalfDay == half
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Half day only: time worked
          Consumer<CompOffFormProvider>(
            builder: (context, form, _) {
              if (!form.isHalfDay) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Time Worked'),
                  Row(
                    children: [
                      Expanded(
                        child: ConstantTimePicker(
                          hint: 'From time',
                          value: form.fromTime,
                          defaultTime: const TimeOfDay(hour: 10, minute: 0),
                          onChanged: form.setFromTime,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ConstantTimePicker(
                          hint: 'To time',
                          value: form.toTime,
                          defaultTime: const TimeOfDay(hour: 14, minute: 0),
                          onChanged: form.setToTime,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                ],
              );
            },
          ),

          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comp off credit asked:',
                  style: getTextTheme().titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Selector<CompOffFormProvider, bool>(
                  selector: (_, p) => p.isHalfDay,
                  builder: (_, isHalfDay, _) => Text(
                    isHalfDay ? '0.5 Day' : '1 Day',
                    style: getTextTheme().titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          _label('Reason'),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Why did you work on this day?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              contentPadding: EdgeInsets.all(16.w),
            ),
            validator: Validators.required('a reason'),
          ),
          SizedBox(height: 24.h),

          Selector<CompOffFormProvider, bool>(
            selector: (_, p) => p.isSubmitting,
            builder: (context, isSubmitting, _) => ConstantButton(
              text: 'Submit Comp Off Request',
              isLoading: isSubmitting,
              onPressed: () => _submit(context),
            ),
          ),
        ],
      ),
    );
  }
}
