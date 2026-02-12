import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:workzen/constants/constant_colors.dart';
import 'package:workzen/constants/const_textstyle.dart';

class ConstantSnackbar {
  /// Shows a standard snackbar with consistent styling across the app
  static void show({
    required String title,
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    Future.delayed(Duration.zero, () {
      final context = Get.context;
      if (context == null) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            title,
            textAlign: TextAlign.center,
            style: getTextTheme().labelLarge?.copyWith(
              color: textColor ?? ConstColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: backgroundColor ?? ConstColors.primary,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
    });
  }

  /// Shows an error snackbar with red background
  static void showError({
    required String title,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      title: title,
      backgroundColor: ConstColors.errorRed,
      textColor: ConstColors.white,
      duration: duration,
    );
  }

  /// Shows a success snackbar with green background
  static void showSuccess({
    required String title,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      title: title,
      backgroundColor: ConstColors.successGreen,
      textColor: ConstColors.white,
      duration: duration,
    );
  }
}
