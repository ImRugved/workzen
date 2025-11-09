import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/custom_button.dart';
import '../../constants/const_textstyle.dart';
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

  List<Map<String, dynamic>> _getAvailableLeaveTypes(
    Map<String, dynamic>? leaveBalances,
  ) {
    if (leaveBalances == null) return [];

    List<Map<String, dynamic>> types = [];

    // PL - Privilege Leave
    if (leaveBalances.containsKey('privilegeLeaves')) {
      final plData = leaveBalances['privilegeLeaves'] as Map<String, dynamic>?;
      if (plData != null) {
        final balance = (plData['balance'] ?? 0) as num;
        if (balance > 0) {
          types.add({
            'value': AppConstants.leaveTypePL,
            'label': 'PL (Privilege Leave)',
            'balance': balance.toInt(),
          });
        }
      }
    }

    // SL - Sick Leave
    if (leaveBalances.containsKey('sickLeaves')) {
      final slData = leaveBalances['sickLeaves'] as Map<String, dynamic>?;
      if (slData != null) {
        final balance = (slData['balance'] ?? 0) as num;
        if (balance > 0) {
          types.add({
            'value': AppConstants.leaveTypeSL,
            'label': 'SL (Sick Leave)',
            'balance': balance.toInt(),
          });
        }
      }
    }

    // CL - Casual Leave
    if (leaveBalances.containsKey('casualLeaves')) {
      final clData = leaveBalances['casualLeaves'] as Map<String, dynamic>?;
      if (clData != null) {
        final balance = (clData['balance'] ?? 0) as num;
        if (balance > 0) {
          types.add({
            'value': AppConstants.leaveTypeCL,
            'label': 'CL (Casual Leave)',
            'balance': balance.toInt(),
          });
        }
      }
    }

    return types;
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? requestProvider.fromDate
          : requestProvider.toDate,
      firstDate: isFromDate ? DateTime.now() : requestProvider.fromDate,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final requestProvider = Provider.of<RequestProvider>(
        context,
        listen: false,
      );
      if (isFromDate) {
        requestProvider.setFromDate(picked);
      } else {
        requestProvider.setToDate(picked);
      }
    }
  }

  Future<void> _selectSingleDate(BuildContext context) async {
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: requestProvider.selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final requestProvider = Provider.of<RequestProvider>(
        context,
        listen: false,
      );
      requestProvider.setSelectedDate(picked);
    }
  }

  Future<void> _submitLeave() async {
    if (_formKey.currentState!.validate()) {
      final rp = Provider.of<RequestProvider>(context, listen: false);
      if (rp.selectedLeaveType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a leave type',
              style: getTextTheme().bodyMedium?.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (rp.shift == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select leave duration',
              style: getTextTheme().bodyMedium?.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
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

        bool success = await requestProvider.applyLeave(
          authProvider.userModel!,
          fromDate,
          toDate,
          shiftType,
          _reasonController.text.trim(),
          rp.selectedLeaveType!,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Leave request submitted successfully',
                style: getTextTheme().bodyMedium?.copyWith(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Get.back();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to submit leave request. Please try again.',
                style: getTextTheme().bodyMedium?.copyWith(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = Provider.of<RequestProvider>(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Apply for Leave',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
      ),
      body: Padding(
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
                      child: CircularProgressIndicator(color: Colors.indigo),
                    ),
                  )
                else if (_getAvailableLeaveTypes(
                  requestProvider.leaveBalances,
                ).isEmpty)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 24.r),
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
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: requestProvider.selectedLeaveType,
                        isExpanded: true,
                        hint: Text(
                          'Select Leave Type',
                          style: getTextTheme().bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        items:
                            _getAvailableLeaveTypes(
                              requestProvider.leaveBalances,
                            ).map((type) {
                              return DropdownMenuItem<String>(
                                value: type['value'],
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      type['label'],
                                      style: getTextTheme().bodyMedium,
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      child: Text(
                                        '${type['balance']} left',
                                        style: getTextTheme().labelSmall
                                            ?.copyWith(
                                              color: Colors.indigo,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          context.read<RequestProvider>().setSelectedLeaveType(
                            value,
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Selected Leave Count Display (moved below - above Reason)
                ],

                // Shift Type (Full Day or Half Day)
                Text(
                  'Leave Duration',
                  style: getTextTheme().titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: requestProvider.shift,
                      isExpanded: true,
                      hint: Text(
                        'Select Duration',
                        style: getTextTheme().bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      items: ['Full Day', 'Half Day']
                          .map(
                            (shift) => DropdownMenuItem<String>(
                              value: shift,
                              child: Text(
                                shift,
                                style: getTextTheme().bodyMedium,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          context.read<RequestProvider>().setShift(newValue);
                        }
                      },
                    ),
                  ),
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
                  InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateFormat.format(requestProvider.fromDate),
                            style: getTextTheme().bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Icon(Icons.calendar_today, size: 18.r),
                        ],
                      ),
                    ),
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
                  InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateFormat.format(requestProvider.toDate),
                            style: getTextTheme().bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Icon(Icons.calendar_today, size: 18.r),
                        ],
                      ),
                    ),
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
                                    requestProvider.halfDayShift == 'First Half'
                                    ? Colors.indigo
                                    : Colors.grey.shade300,
                                width:
                                    requestProvider.halfDayShift == 'First Half'
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
                                  requestProvider.halfDayShift == 'Second Half'
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
                                  requestProvider.halfDayShift == 'Second Half'
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
                  InkWell(
                    onTap: () => _selectSingleDate(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateFormat.format(requestProvider.selectedDate),
                            style: getTextTheme().bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Icon(Icons.calendar_today, size: 18.r),
                        ],
                      ),
                    ),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter reason for leave';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24.h),

                // Submit Button
                CustomButton(
                  label: 'Submit Request',
                  isLoading: requestProvider.isLoading,
                  onPressed: _submitLeave,
                ),
              ],
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
