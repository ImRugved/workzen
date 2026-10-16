import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/pin_entry_provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_snackbar.dart';
import 'app_unlock_screen.dart';
import 'admin/dashboard/admin_dashboard_screen.dart';
import 'user/dashboard/user_dashboard_screen.dart';

class AppUnlockPinSetupScreen extends StatefulWidget {
  final bool isFirstTime;
  const AppUnlockPinSetupScreen({Key? key, this.isFirstTime = false})
    : super(key: key);

  @override
  State<AppUnlockPinSetupScreen> createState() =>
      _AppUnlockPinSetupScreenState();
}

class _AppUnlockPinSetupScreenState extends State<AppUnlockPinSetupScreen> {
  // PIN digits and the confirm step (scoped state, no setState)
  final PinEntryProvider _pin = PinEntryProvider();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _handleNumericInput(String value) {
    if (!_pin.addDigit(value)) return;

    if (!_pin.isConfirming) {
      // First PIN entry
      _pin.startConfirming();
    } else if (_pin.matchesFirstPin) {
      // Confirm PIN entry
      _savePIN();
    } else {
      _handleMismatch();
    }
  }

  void _handleMismatch() {
    _pin.resetSetup();
    ConstantSnackbar.showError(title: 'PINs do not match. Please try again.');
  }

  Future<void> _savePIN() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final securityProvider = Provider.of<SecurityProvider>(
      context,
      listen: false,
    );

    final success = await securityProvider.setupAppUnlockPIN(
      authProvider.userModel!.id,
      _pin.pin,
    );

    if (success && mounted) {
      ConstantSnackbar.showSuccess(title: 'App unlock PIN set successfully');

      // Navigate to appropriate screen
      if (widget.isFirstTime) {
        // After first-time setup, go to unlock screen then dashboard
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final targetScreen =
            (authProvider.isAdmin || authProvider.userModel?.isSubAdmin == true)
            ? const AdminDashboardScreen()
            : const UserDashboardScreen();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AppUnlockScreen(child: targetScreen),
          ),
        );
      } else {
        // If updating PIN, go back
        Navigator.of(context).pop();
      }
    } else if (mounted) {
      ConstantSnackbar.showError(
        title: 'Failed to save PIN. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _pin,
      child: Consumer<PinEntryProvider>(
        builder: (context, pin, _) => _buildScreen(pin),
      ),
    );
  }

  Widget _buildScreen(PinEntryProvider pin) {
    return Scaffold(
      backgroundColor: ConstColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          pin.isConfirming ? 'Confirm PIN' : 'Setup App Unlock PIN',
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
        backgroundColor: ConstColors.backgroundColor,
      ),
      body: Container(
        color: ConstColors.backgroundColor,
        // Scrolls on short screens; stays centred when everything fits
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 80.r,
                      color: ConstColors.primaryDeep,
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      pin.isConfirming
                          ? 'Confirm your 6-digit PIN'
                          : 'Create a 6-digit PIN to unlock the app',
                      style: getTextTheme().titleMedium?.copyWith(
                        color: ConstColors.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40.h),
                    // PIN dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 20.w,
                          height: 20.w,
                          margin: EdgeInsets.symmetric(horizontal: 15.w),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pin.pin.length > index
                                ? ConstColors.primary
                                : ConstColors.cardBackground,
                            border: Border.all(
                              color: ConstColors.primaryDeep,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 60.h),
                    // Numeric keypad
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.w),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _numericButton('1'),
                              _numericButton('2'),
                              _numericButton('3'),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _numericButton('4'),
                              _numericButton('5'),
                              _numericButton('6'),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _numericButton('7'),
                              _numericButton('8'),
                              _numericButton('9'),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              SizedBox(width: 72.w),
                              _numericButton('0'),
                              IconButton(
                                icon: Icon(
                                  Icons.backspace,
                                  color: ConstColors.textColor,
                                  size: 28.r,
                                ),
                                onPressed: pin.backspace,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numericButton(String value) {
    return SizedBox(
      width: 72.w,
      height: 72.w,
      child: TextButton(
        onPressed: () => _handleNumericInput(value),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          shape: const CircleBorder(
            side: BorderSide(color: ConstColors.borderColor),
          ),
          backgroundColor: ConstColors.cardBackground,
        ),
        child: Text(
          value,
          style: getTextTheme().headlineMedium?.copyWith(
            fontWeight: FontWeight.w400,
            color: ConstColors.textColor,
          ),
        ),
      ),
    );
  }
}
