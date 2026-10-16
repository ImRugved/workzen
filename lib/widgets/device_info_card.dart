import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../models/security_settings_model.dart';

/// Shows the phone an account is bound to for attendance. Used on the Security
/// screen (the user's own device) and on the employee details screen (an
/// admin checks an employee's device). [onReset] adds the admin Reset Device
/// button.
class DeviceInfoCard extends StatelessWidget {
  final DeviceInfoModel? deviceInfo;
  final VoidCallback? onReset;
  final String emptyMessage;

  const DeviceInfoCard({
    super.key,
    required this.deviceInfo,
    this.onReset,
    this.emptyMessage =
        'No device registered yet. It is registered when you log in.',
  });

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 18.r, color: Colors.indigo),
          SizedBox(width: 10.w),
          Text('$label: ', style: getTextTheme().bodySmall),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: getTextTheme().bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = deviceInfo;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registered Device',
              style: getTextTheme().titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Attendance punch in and out works only from this device.',
              style: getTextTheme().bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (device == null) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.phonelink_off, color: Colors.orange, size: 20.r),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      emptyMessage,
                      style: getTextTheme().bodyMedium?.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _row(Icons.smartphone, 'Device', device.displayName),
              _row(Icons.system_update, 'OS', device.displayOs),
              _row(
                Icons.event_available,
                'Registered on',
                device.registeredAt == null
                    ? ''
                    : DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(device.registeredAt!),
              ),
              if (onReset != null) ...[
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: ConstantButton(
                    text: 'Reset Device',
                    onPressed: onReset,
                    icon: Icon(
                      Icons.phonelink_erase,
                      color: ConstColors.errorRed,
                      size: 20.r,
                    ),
                    isOutlined: true,
                    backgroundColor: ConstColors.errorRed,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
