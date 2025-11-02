import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:workzen/constants/constant_colors.dart';
import 'package:workzen/constants/const_textstyle.dart';

class ConstTextField extends StatelessWidget {
  final String customText;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obsercureText;
  final TextInputType keyoardType;
  final int maxline;
  final List<TextInputFormatter>? inputFormatters;
  final Function(String)? onChanged;
  final Function(String?)? onSaved;
  final Widget? iconss;
  final Widget? prefixIcon;
  final String? prefixText;
  final TextStyle? prefixStyle;
  final Color? cursorColor;
  final double? cursorHeight;
  final TextStyle? labelStyle;
  final double? enabledBorderRadius;
  final double? focusedBorderRadius;
  final double? errorBorderRadius;
  final double? focusedErrorBorderRadius;
  final bool? isMandatory;

  const ConstTextField({
    Key? key,
    required this.customText,
    required this.controller,
    this.validator,
    this.obsercureText = false,
    this.keyoardType = TextInputType.text,
    this.maxline = 1,
    this.inputFormatters,
    this.onChanged,
    this.onSaved,
    this.iconss,
    this.prefixIcon,
    this.prefixText,
    this.prefixStyle,
    this.cursorColor,
    this.cursorHeight,
    this.labelStyle,
    this.enabledBorderRadius,
    this.focusedBorderRadius,
    this.errorBorderRadius,
    this.focusedErrorBorderRadius,
    this.isMandatory = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obsercureText,
      keyboardType: keyoardType,
      maxLines: maxline,
      style: getTextTheme().bodyMedium,
      inputFormatters: inputFormatters,
      textCapitalization: TextCapitalization.none,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        label: isMandatory == true
            ? Row(
                children: [
                  Text(
                    customText,
                    style: labelStyle ?? getTextTheme().bodyMedium,
                  ),
                  Text(
                    ' *',
                    style: (labelStyle ?? getTextTheme().bodyLarge)?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Text(customText, style: labelStyle ?? getTextTheme().bodyMedium),
        prefixIcon: prefixIcon,
        prefixText: prefixText,
        prefixStyle: prefixStyle,
        suffixIcon: iconss,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(enabledBorderRadius ?? 8.r),
          borderSide: BorderSide(color: ConstColors.primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(focusedBorderRadius ?? 8.r),
          borderSide: BorderSide(color: ConstColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(errorBorderRadius ?? 8.r),
          borderSide: BorderSide(color: ConstColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(focusedErrorBorderRadius ?? 8.r),
          borderSide: BorderSide(color: ConstColors.errorRed),
        ),
        filled: true,
        fillColor: ConstColors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
      ),
      cursorColor: cursorColor ?? ConstColors.black,
      cursorHeight: cursorHeight ?? 20.h,
      validator: validator,
      onChanged: onChanged,
      onSaved: onSaved,
    );
  }
}
