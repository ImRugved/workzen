import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/apploading_indicator.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';

/// The look shared by the app's form and confirm dialogs: a tinted icon, a bold
/// title, an optional message or form, and a Cancel | Confirm row under a
/// divider. The confirm label is coloured text, never a filled button.
class AppDialogCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final Widget? child;
  final String confirmLabel;
  final Color confirmColor;

  /// Shows a spinner in place of the confirm label and disables both buttons.
  final bool isBusy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const AppDialogCard({
    super.key,
    required this.icon,
    required this.title,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.iconColor = ConstColors.primaryDeep,
    this.message,
    this.child,
    this.confirmColor = ConstColors.primaryDeep,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24.r, color: iconColor),
            ),
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: getTextTheme().titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
            ),
            if (message != null) ...[
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: getTextTheme().bodyMedium?.copyWith(
                    color: ConstColors.textColor,
                  ),
                ),
              ),
            ],
            if (child != null) ...[
              SizedBox(height: 14.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: child!,
              ),
            ],
            SizedBox(height: 16.h),
            Divider(height: 1, color: ConstColors.borderColor),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: isBusy ? null : onCancel,
                    child: Text(
                      'Cancel',
                      style: getTextTheme().labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.textColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 24.h,
                  child: VerticalDivider(
                    width: 1,
                    color: ConstColors.borderColor,
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: isBusy ? null : onConfirm,
                    child: isBusy
                        ? AppLoadingIndicator(size: 18, color: confirmColor)
                        : Text(
                            confirmLabel,
                            style: getTextTheme().labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: confirmColor,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
