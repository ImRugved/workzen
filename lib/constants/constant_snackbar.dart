import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:workzen/constants/constant_colors.dart';
import 'package:workzen/constants/const_textstyle.dart';

class ConstantSnackbar {
  /// Shows a standard snackbar with consistent styling across the app
  ///
  /// Parameters:
  /// - [title]: The title of the snackbar (typically 'User Alert')
  /// - [message]: The message to display in the snackbar
  /// - [backgroundColor]: Optional background color, defaults to primary color
  /// - [textColor]: Optional text color, defaults to white
  static void show({
    required String title,
    required String message,
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: backgroundColor ?? ConstColors.primary,
      colorText: textColor ?? ConstColors.white,
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),

      borderRadius: 12.r,
      duration: duration,
      isDismissible: true,
      // dismissDirection: DismissDirection.horizontal,
      // forwardAnimationCurve: Curves.easeOutBack,
      titleText: Text(
        title,
        style: getTextTheme().labelLarge?.copyWith(
          color: textColor ?? ConstColors.white,
          fontWeight: FontWeight.bold,
          //fontSize: 14.sp,
        ),
      ),
      messageText: Text(
        message,
        style: getTextTheme().labelMedium?.copyWith(
          color: textColor ?? ConstColors.white,
        ),
      ),
    );
  }

  /// Shows an error snackbar with red background
  static void showError({
    required String message,
    String title = 'User Alert',
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      title: title,
      message: message,
      backgroundColor: ConstColors.errorRed,
      textColor: ConstColors.white,
    );
  }

  /// Shows a success snackbar with green background
  static void showSuccess({required String message, String title = 'Success'}) {
    show(
      title: title,
      message: message,
      backgroundColor: ConstColors.primary,
      textColor: ConstColors.white,
    );
  }
}
