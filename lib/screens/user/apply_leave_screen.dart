import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../models/leave_allocation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../constants/constant_snackbar.dart';
import '../../utils/validators.dart';
import '../../widgets/comp_off_request_form.dart';
import '../../constants/constant_button.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_date_time_picker.dart';
import '../../constants/constant_dropdown.dart';
import '../../app_constants.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({Key? key}) : super(key: key);

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final requestProvider = Provider.of<RequestProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      requestProvider.initializeApplyLeave();

      if (authProvider.userModel != null) {
        requestProvider.getUserLeaveBalances(authProvider.userModel!.id);
      }
    });
  }

  // Dropdown entries: the leave types the employee has balance for, "Comp Off"
  // with the earned credit once some was approved, and always "Apply Comp Off".
  List<Map<String, dynamic>> _getAvailableLeaveTypes(
    LeaveAllocationModel? allocation,
  ) {
    final provider = Provider.of<RequestProvider>(context, listen: false);
    final types = <Map<String, dynamic>>[];

    // A type is offered when the employee has it and days are still available
    // (balance minus days held by pending requests)
    void addType(String value, String label, LeaveTypeBalance? type) {
      if (type == null) return;
      final available = provider.availableLeave(value);
      if (available > 0) {
        types.add({'value': value, 'label': label, 'balance': available});
      }
    }

    addType(
      AppConstants.leaveTypePL,
      'PL (Privilege Leave)',
      allocation?.privilege,
    );
    addType(AppConstants.leaveTypeSL, 'SL (Sick Leave)', allocation?.sick);
    addType(AppConstants.leaveTypeCL, 'CL (Casual Leave)', allocation?.casual);

    final compOff = provider.availableLeave(AppConstants.leaveTypeCO);
    if (compOff > 0) {
      types.add({
        'value': AppConstants.leaveTypeCO,
        'label': 'CO (Compensatory Off)',
        'balance': compOff,
      });
    }

    types.add({
      'value': AppConstants.applyCompOffOption,
      'label': 'Apply Comp Off',
      'balance': null,
    });
    return types;
  }

  String _formatCount(num n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toString();

  Future<void> _submitLeave() async {
    if (_formKey.currentState!.validate()) {
      final rp = Provider.of<RequestProvider>(context, listen: false);
      if (rp.selectedLeaveType == null) {
        ConstantSnackbar.showError(title: 'Please select a leave type');
        return;
      }
      if (rp.shift == null) {
        ConstantSnackbar.showError(title: 'Please select the leave duration');
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final requestProvider = Provider.of<RequestProvider>(
        context,
        listen: false,
      );

      if (authProvider.userModel != null) {
        // Determine dates and shift based on selection
        DateTime fromDate;
        DateTime toDate;
        String shiftType;

        if (requestProvider.shift == 'Half Day') {
          fromDate = requestProvider.selectedDate;
          toDate = requestProvider.selectedDate;
          shiftType =
              requestProvider.halfDayShift; // "First Half" or "Second Half"
        } else {
          fromDate = requestProvider.fromDate;
          toDate = requestProvider.toDate;
          shiftType = requestProvider.shift!; // "Full Day"
        }

        // The request must fit the days still available for this leave type
        final requestedDays = shiftType == 'First Half' ||
                shiftType == 'Second Half'
            ? 0.5
            : (toDate.difference(fromDate).inDays + 1).toDouble();
        final available = requestProvider.availableLeave(
          rp.selectedLeaveType!,
        );
        if (requestedDays > available) {
          ConstantSnackbar.showError(
            title:
                'Only ${_formatCount(available)} day(s) left for this leave type, you asked for ${_formatCount(requestedDays)}',
          );
          return;
        }

        bool success = await requestProvider.applyLeave(
          authProvider.userModel!,
          fromDate,
          toDate,
          shiftType,
          _reasonController.text.trim(),
          rp.selectedLeaveType!,
        );

        if (success && mounted) {
          ConstantSnackbar.showSuccess(
            title: 'Your leave request has been sent for approval',
          );
          Get.back();
        } else if (mounted) {
          ConstantSnackbar.showError(
            title: 'Could not send your leave request. Please try again.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = Provider.of<RequestProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Apply for Leave',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leave Type Dropdown
                  if (requestProvider.isLoadingBalances)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.h),
                        child: AppLoadingIndicator(size: 40),
                      ),
                    )
                  else if (_getAvailableLeaveTypes(
                    requestProvider.leaveAllocation,
                  ).isEmpty)
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.orange,
                              size: 24.r,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                'No leave balance available. Please contact admin.',
                                style: getTextTheme().bodyMedium?.copyWith(
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'Leave Type',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Builder(
                      builder: (context) {
                        final types = _getAvailableLeaveTypes(
                          requestProvider.leaveAllocation,
                        );
                        Map<String, dynamic> detail(String value) =>
                            types.firstWhere((t) => t['value'] == value);
                        return ConstantDropdown<String>(
                          hint: 'Select Leave Type',
                          value: requestProvider.selectedLeaveType,
                          items: types
                              .map((t) => t['value'] as String)
                              .toList(),
                          itemLabel: (value) => detail(value)['label'] as String,
                          itemBuilder: (value) {
                            final type = detail(value);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  type['label'] as String,
                                  style: getTextTheme().bodyMedium,
                                ),
                                if (type['balance'] != null)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Text(
                                      '${_formatCount(type['balance'] as num)} left',
                                      style: getTextTheme().labelSmall
                                          ?.copyWith(
                                            color: Colors.indigo,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                              ],
                            );
                          },
                          onChanged: (value) {
                            context
                                .read<RequestProvider>()
                                .setSelectedLeaveType(value);
                          },
                        );
                      },
                    ),
                    SizedBox(height: 16.h),

                    // Selected Leave Count Display (moved below - above Reason)
                  ],

                  // "Apply Comp Off" swaps the leave form for the comp off form
                  if (requestProvider.selectedLeaveType ==
                      AppConstants.applyCompOffOption)
                    const CompOffRequestForm()
                  else ...[
                  // Shift Type (Full Day or Half Day)
                  Text(
                    'Leave Duration',
                    style: getTextTheme().titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ConstantDropdown<String>(
                    hint: 'Select Duration',
                    value: requestProvider.shift,
                    items: const ['Full Day', 'Half Day'],
                    itemLabel: (shift) => shift,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        context.read<RequestProvider>().setShift(newValue);
                      }
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Show different fields based on Full Day or Half Day
                  if (requestProvider.shift == 'Full Day') ...[
                    // From Date
                    Text(
                      'From Date',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ConstantDatePicker(
                      value: requestProvider.fromDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                      onChanged: requestProvider.setFromDate,
                    ),
                    SizedBox(height: 16.h),

                    // To Date
                    Text(
                      'To Date',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ConstantDatePicker(
                      value: requestProvider.toDate,
                      firstDate: requestProvider.fromDate,
                      lastDate: DateTime(2100),
                      onChanged: requestProvider.setToDate,
                    ),
                    SizedBox(height: 16.h),
                  ] else if (requestProvider.shift == 'Half Day') ...[
                    // Half Day - Show checkboxes and single date
                    Text(
                      'Select Half',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              context.read<RequestProvider>().setHalfDayShift(
                                'First Half',
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    requestProvider.halfDayShift == 'First Half'
                                    ? Colors.indigo.shade50
                                    : Colors.white,
                                border: Border.all(
                                  color:
                                      requestProvider.halfDayShift ==
                                          'First Half'
                                      ? Colors.indigo
                                      : Colors.grey.shade300,
                                  width:
                                      requestProvider.halfDayShift ==
                                          'First Half'
                                      ? 2
                                      : 1,
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    requestProvider.halfDayShift == 'First Half'
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color:
                                        requestProvider.halfDayShift ==
                                            'First Half'
                                        ? Colors.indigo
                                        : Colors.grey,
                                    size: 20.r,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'First Half',
                                    style: getTextTheme().bodyMedium?.copyWith(
                                      fontWeight:
                                          requestProvider.halfDayShift ==
                                              'First Half'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color:
                                          requestProvider.halfDayShift ==
                                              'First Half'
                                          ? Colors.indigo
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              context.read<RequestProvider>().setHalfDayShift(
                                'Second Half',
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    requestProvider.halfDayShift ==
                                        'Second Half'
                                    ? Colors.indigo.shade50
                                    : Colors.white,
                                border: Border.all(
                                  color:
                                      requestProvider.halfDayShift ==
                                          'Second Half'
                                      ? Colors.indigo
                                      : Colors.grey.shade300,
                                  width:
                                      requestProvider.halfDayShift ==
                                          'Second Half'
                                      ? 2
                                      : 1,
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    requestProvider.halfDayShift ==
                                            'Second Half'
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color:
                                        requestProvider.halfDayShift ==
                                            'Second Half'
                                        ? Colors.indigo
                                        : Colors.grey,
                                    size: 20.r,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Second Half',
                                    style: getTextTheme().bodyMedium?.copyWith(
                                      fontWeight:
                                          requestProvider.halfDayShift ==
                                              'Second Half'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color:
                                          requestProvider.halfDayShift ==
                                              'Second Half'
                                          ? Colors.indigo
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Date (single picker for half day)
                    Text(
                      'Date',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ConstantDatePicker(
                      value: requestProvider.selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                      onChanged: requestProvider.setSelectedDate,
                    ),
                    SizedBox(height: 16.h),
                  ],

                  // Selected Leave Count Display (above Reason)
                  if (requestProvider.selectedLeaveType != null &&
                      requestProvider.shift != null)
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected Leave Days:',
                            style: getTextTheme().titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                          Text(
                            requestProvider.shift == 'Half Day'
                                ? '0.5 Day'
                                : '${requestProvider.calculateLeaveDays()} ${requestProvider.calculateLeaveDays() > 1 ? 'Days' : 'Day'}',
                            style: getTextTheme().titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (requestProvider.selectedLeaveType != null &&
                      requestProvider.shift != null)
                    SizedBox(height: 16.h),

                  // Reason
                  Text(
                    'Reason',
                    style: getTextTheme().titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter reason for leave',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      contentPadding: EdgeInsets.all(16.w),
                    ),
                    validator: Validators.required('reason for leave'),
                  ),
                  SizedBox(height: 24.h),

                  // Submit Button
                  ConstantButton(
                    text: 'Submit Request',
                    isLoading: requestProvider.isLoading,
                    onPressed: _submitLeave,
                  ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
