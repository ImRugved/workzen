import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'constant_colors.dart';
import 'const_textstyle.dart';

/// The app's one dropdown. Use it everywhere instead of a bare
/// DropdownButton / DropdownButtonFormField so the look (outlined field, radius,
/// text style, colours) stays the same.
///
/// [items] are the values; [itemLabel] turns a value into the text shown.
/// Pass [itemBuilder] when an entry needs more than text (a colour dot, a
/// count badge). A null [value] shows the [hint].
class ConstantDropdown<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final Widget Function(T item)? itemBuilder;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final Widget? prefixIcon;
  final bool isDense;
  final bool isEnabled;
  final double? borderRadius;

  const ConstantDropdown({
    super.key,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.label,
    this.hint,
    this.value,
    this.itemBuilder,
    this.validator,
    this.prefixIcon,
    this.isDense = false,
    this.isEnabled = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius ?? 10.r);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return DropdownButtonFormField<T>(
      // A new key makes the field follow [value] when it is changed from
      // outside (for example a department change clearing the role)
      key: ValueKey(value),
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      isDense: isDense,
      icon: Icon(Icons.arrow_drop_down, color: ConstColors.textColorLight),
      style: getTextTheme().bodyMedium,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: getTextTheme().bodyMedium,
        hintText: hint,
        hintStyle: getTextTheme().bodyMedium,
        prefixIcon: prefixIcon,
        isDense: isDense,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: isDense ? 10.h : 5.h,
        ),
        border: border(ConstColors.darkGrey),
        enabledBorder: border(ConstColors.darkGrey),
        focusedBorder: border(ConstColors.primary, 1.5),
        errorBorder: border(ConstColors.errorRed),
        focusedErrorBorder: border(ConstColors.errorRed, 1.5),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child:
                  itemBuilder?.call(item) ??
                  Text(
                    itemLabel(item),
                    overflow: TextOverflow.ellipsis,
                    style: getTextTheme().bodyMedium,
                  ),
            ),
          )
          .toList(),
      onChanged: isEnabled ? onChanged : null,
    );
  }
}
