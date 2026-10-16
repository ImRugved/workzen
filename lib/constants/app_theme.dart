import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'constant_colors.dart';
import 'const_textstyle.dart';

/// The app's single source of visual style. Screens take their colours from
/// [ConstColors] and their surfaces from [NeuStyle] / [NeuCard]; nothing here
/// changes behaviour.
///
/// Design: light neumorphism. Off-white background, white raised surfaces with
/// a subtle grey border and soft black shadows, black text, soft blue
/// [ConstColors.primary] for fills and [ConstColors.primaryDeep] for blue text
/// and icons on white. Red, green, yellow and orange stay for status only.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ConstColors.primary,
      primary: ConstColors.primary,
      onPrimary: ConstColors.black,
      secondary: ConstColors.primaryDeep,
      onSecondary: ConstColors.white,
      surface: ConstColors.cardBackground,
      onSurface: ConstColors.textColor,
      error: ConstColors.errorRed,
      onError: ConstColors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ConstColors.backgroundColor,
      canvasColor: ConstColors.backgroundColor,
      cardColor: ConstColors.cardBackground,
      dividerColor: ConstColors.borderColor,
      fontFamily: 'Poppins',
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: ConstColors.backgroundColor,
        foregroundColor: ConstColors.textColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: ConstColors.textColor),
        titleTextStyle: getTextTheme().titleLarge?.copyWith(
          color: ConstColors.textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: ConstColors.cardBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: ConstColors.borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ConstColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        titleTextStyle: getTextTheme().titleMedium,
        contentTextStyle: getTextTheme().bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ConstColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: ConstColors.backgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24.r)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ConstColors.cardBackground,
        selectedColor: ConstColors.primary,
        side: const BorderSide(color: ConstColors.borderColor),
        labelStyle: getTextTheme().labelMedium?.copyWith(
          color: ConstColors.textColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ConstColors.cardBackground,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        hintStyle: getTextTheme().bodyMedium?.copyWith(
          color: ConstColors.textColorLight,
        ),
        border: NeuStyle.inputBorder(),
        enabledBorder: NeuStyle.inputBorder(),
        focusedBorder: NeuStyle.inputBorder(
          color: ConstColors.primaryDeep,
          width: 1.5,
        ),
        errorBorder: NeuStyle.inputBorder(color: ConstColors.errorRed),
        focusedErrorBorder: NeuStyle.inputBorder(
          color: ConstColors.errorRed,
          width: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ConstColors.primary,
          foregroundColor: ConstColors.black,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ConstColors.primaryDeep,
          side: const BorderSide(color: ConstColors.borderColor),
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ConstColors.primaryDeep),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ConstColors.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? ConstColors.primaryDeep
              : ConstColors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? ConstColors.primary
              : ConstColors.borderColor,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? ConstColors.primary
              : ConstColors.white,
        ),
        checkColor: WidgetStateProperty.all(ConstColors.black),
        side: const BorderSide(color: ConstColors.darkGrey),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ConstColors.primary,
        foregroundColor: ConstColors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ConstColors.cardBackground,
        indicatorColor: ConstColors.primary.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.all(
          getTextTheme().labelSmall?.copyWith(color: ConstColors.textColor),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ConstColors.cardBackground,
        selectedItemColor: ConstColors.primaryDeep,
        unselectedItemColor: ConstColors.textColorLight,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ConstColors.textColor,
        contentTextStyle: getTextTheme().bodyMedium?.copyWith(
          color: ConstColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
      ),
    );
  }
}

/// Spacing used across the app. Screens pad their content with [screen]; use
/// EdgeInsets.symmetric everywhere (never .all or .only) so spacing reads the
/// same on every page.
class AppSpacing {
  AppSpacing._();

  /// Screen body padding: 10 horizontal, 15 vertical.
  static EdgeInsets get screen =>
      EdgeInsets.symmetric(horizontal: 10.w, vertical: 15.h);
}

/// The neumorphic surface used everywhere: white, a soft grey border and two
/// soft shadows (a dark one below-right and a white highlight above-left).
class NeuStyle {
  NeuStyle._();

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;

  /// Raised surface. [pressed] flattens it for selected / pressed states.
  static BoxDecoration raised({
    Color color = ConstColors.cardBackground,
    double radius = radiusMedium,
    Color? borderColor,
    bool pressed = false,
  }) {
    final r = BorderRadius.circular(radius.r);
    return BoxDecoration(
      color: color,
      borderRadius: r,
      border: Border.all(color: borderColor ?? ConstColors.borderColor),
      boxShadow: pressed
          ? const []
          : [
              BoxShadow(
                color: ConstColors.neuShadowDark,
                blurRadius: 18,
                offset: const Offset(4, 6),
              ),
              const BoxShadow(
                color: ConstColors.neuHighlight,
                blurRadius: 12,
                offset: Offset(-4, -4),
              ),
            ],
    );
  }

  /// A small raised shadow for chips, pills and icon badges.
  static List<BoxShadow> softShadow() => const [
    BoxShadow(
      color: ConstColors.neuShadowDark,
      blurRadius: 8,
      offset: Offset(2, 3),
    ),
  ];

  static OutlineInputBorder inputBorder({
    Color color = ConstColors.borderColor,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// A raised white card. Replaces [Card] across the app so every card, form
/// panel and calendar box shares the same surface.
class NeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const NeuCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.radius = NeuStyle.radiusMedium,
    this.color = ConstColors.cardBackground,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Padding(
      padding: margin,
      child: Container(
        decoration: NeuStyle.raised(
          color: color,
          radius: radius,
          borderColor: borderColor,
        ),
        child: onTap == null
            ? body
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius.r),
                  onTap: onTap,
                  child: body,
                ),
              ),
      ),
    );
  }
}
