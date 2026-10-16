import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'apploading_indicator.dart';
import 'constant_colors.dart';
import 'const_textstyle.dart';

/// The app's one button. Use it everywhere instead of a bare ElevatedButton /
/// OutlinedButton so colours, radius, height and the loading state stay
/// consistent.
///
/// - Filled (default): [backgroundColor] with [textColor] text.
/// - Outlined: set [isOutlined]; [backgroundColor] is then the border and text
///   colour on a transparent button.
/// - Full width by default; pass [isFullWidth] false to size to its content
///   (dialog actions, buttons in a row with an Expanded around them keep it
///   true), or give an explicit [width].
class ConstantButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  // Customization parameters
  final double? height;
  final double? width;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? disabledBackgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final TextStyle? textStyle;
  final Widget? icon;
  final bool isDisabled;
  final bool isLoading;
  final bool isOutlined;
  final double? elevation;
  final Color? textColor;
  final Color? loadingColor;
  final double? horizontalInnerPadding;
  final double? verticalInnerPadding;
  final double? horizontalMargin;
  final double? verticalMargin;

  /// Lines the label may wrap onto before it is cut with an ellipsis. Null
  /// keeps one line.
  final int? maxLines;

  const ConstantButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.maxLines,
    this.height,
    this.width,
    this.isFullWidth = true,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.borderColor,
    this.borderRadius,
    this.textStyle,
    this.icon,
    this.isDisabled = false,
    this.isLoading = false,
    this.isOutlined = false,
    this.elevation,
    this.textColor,
    this.loadingColor,
    this.horizontalInnerPadding,
    this.verticalInnerPadding,
    this.horizontalMargin,
    this.verticalMargin,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = backgroundColor ?? ConstColors.primary;
    final fillColor = isOutlined ? Colors.transparent : baseColor;
    final labelColor =
        textColor ?? (isOutlined ? baseColor : ConstColors.white);
    final outlineColor = borderColor ?? baseColor;
    final disabled = isDisabled || isLoading || onPressed == null;

    return Container(
      height: height ?? 50.h,
      width: width ?? (isFullWidth ? double.infinity : null),
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin ?? 0,
        vertical: verticalMargin ?? 0,
      ),
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: elevation ?? (isOutlined ? 0 : 2),
          backgroundColor: fillColor,
          // A disabled button is dimmed so it never looks tappable
          disabledBackgroundColor:
              disabledBackgroundColor ??
              (isOutlined ? Colors.transparent : baseColor.withValues(alpha: 0.4)),
          foregroundColor: labelColor,
          disabledForegroundColor: labelColor.withValues(alpha: 0.6),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalInnerPadding ?? 20.w,
            vertical: verticalInnerPadding ?? 12.h,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 10.r),
            side: BorderSide(
              color: disabled && !isOutlined
                  ? Colors.transparent
                  : outlineColor,
              width: 1.2,
            ),
          ),
        ),
        child: isLoading
            ? AppLoadingIndicator(color: loadingColor ?? labelColor, size: 22)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, SizedBox(width: 8.w)],
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      maxLines: maxLines ?? 1,
                      textAlign: TextAlign.center,
                      style:
                          textStyle ??
                          getTextTheme().labelLarge?.copyWith(
                            color: labelColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
