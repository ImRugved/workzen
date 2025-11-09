import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/custom_button.dart';
import '../../constants/const_textstyle.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({Key? key}) : super(key: key);

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _shift = 'Full Day';
  final _reasonController = TextEditingController();

  final List<String> _shiftOptions = ['Full Day', 'First Half', 'Second Half'];

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: isFromDate ? DateTime.now() : _fromDate,
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
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          if (_toDate.isBefore(_fromDate)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _submitLeave() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final requestProvider = Provider.of<RequestProvider>(context, listen: false);

      if (authProvider.userModel != null) {
        bool success = await requestProvider.applyLeave(
          authProvider.userModel!,
          _fromDate,
          _toDate,
          _shift,
          _reasonController.text.trim(),
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave request submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Get.back();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to submit leave request. Please try again.'),
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
                          dateFormat.format(_fromDate),
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
                          dateFormat.format(_toDate),
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

                // Shift
                Text(
                  'Shift',
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
                      value: _shift,
                      isExpanded: true,
                      items: _shiftOptions.map((String shift) {
                        return DropdownMenuItem<String>(
                          value: shift,
                          child: Text(shift, style: getTextTheme().bodyMedium),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _shift = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
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
