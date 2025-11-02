import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workzen/constants/constant_colors.dart';

TextTheme getTextTheme() {
  return TextTheme(
    // Headings - primarily for section headers and titles
    headlineLarge: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w700,
      color: ConstColors.textColor,
      fontSize: 22.sp,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w600,
      color: ConstColors.textColor,
      fontSize: 18.sp,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w500,
      color: ConstColors.textColor,
      fontSize: 16.sp,
    ),

    // Body - for main content
    bodyLarge: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w600,
      color: ConstColors.textColor,
      fontSize: 16.sp,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.normal,
      color: ConstColors.textColorLight,
      fontSize: 14.sp,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w400,
      color: ConstColors.textColorLight,
      fontSize: 12.sp,
    ),

    // Titles - for cards and sections
    titleLarge: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w600,
      color: ConstColors.primary,
      fontSize: 20.sp,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w500,
      color: ConstColors.textColor,
      fontSize: 18.sp,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w500,
      color: ConstColors.textColor,
      fontSize: 16.sp,
    ),

    // Display - for standout elements and panels
    displayLarge: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w700,
      color: ConstColors.primary,
      fontSize: 24.sp,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w600,
      color: ConstColors.primary,
      fontSize: 20.sp,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w500,
      fontSize: 16.sp,
      color: ConstColors.primary,
    ),

    // Labels - for buttons and small elements
    labelSmall: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w400,
      fontSize: 10.sp,
      color: ConstColors.textColorLight,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w500,
      fontSize: 12.sp,
      color: ConstColors.textColorWhite,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w600,
      fontSize: 14.sp,
      color: ConstColors.primary,
    ),
  );
}
