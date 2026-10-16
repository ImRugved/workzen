import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/pin_entry_provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_snackbar.dart';
import '../constants/apploading_indicator.dart';
import '../constants/constant_colors.dart';

class AppUnlockScreen extends StatefulWidget {
  final Widget child;
  const AppUnlockScreen({Key? key, required this.child}) : super(key: key);

  @override
  State<AppUnlockScreen> createState() => _AppUnlockScreenState();
}

class _AppUnlockScreenState extends State<AppUnlockScreen> {
  // PIN digits, failed attempts, cooldown and biometric flag (scoped state)
  final PinEntryProvider _pin = PinEntryProvider();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize security settings first
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final securityProvider = Provider.of<SecurityProvider>(
        context,
        listen: false,
      );

      // Make sure security is initialized
      await securityProvider.initializeSecurity(authProvider.userModel!.id);

      // Only auto-trigger biometric if it's enabled
      if (securityProvider.biometricEnabled &&
          securityProvider.isDeviceSupported) {
        _checkBiometricAndAuthenticate();
      }
    });
  }

  Future<void> _checkBiometricAndAuthenticate() async {
    final securityProvider = Provider.of<SecurityProvider>(
      context,
      listen: false,
    );

    // Double check biometric is enabled before authenticating
    if (!securityProvider.biometricEnabled ||
        !securityProvider.isDeviceSupported) {
      return;
    }

    _pin.setAuthenticating(true);

    final authenticated = await securityProvider.authenticateWithBiometrics(
      reason: 'Unlock the app',
    );
    if (!mounted) return;

    if (authenticated) {
      _unlockApp();
    } else {
      _pin.setAuthenticating(false);
    }
  }

  void _unlockApp() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => widget.child));
  }

  void _handleNumericInput(String value) {
    if (_pin.addDigit(value)) {
      _verifyPIN();
    }
  }

  Future<void> _verifyPIN() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final securityProvider = Provider.of<SecurityProvider>(
      context,
      listen: false,
    );

    final verified = await securityProvider.verifyAppUnlockPIN(
      authProvider.userModel!.id,
      _pin.pin,
    );
    if (!mounted) return;

    if (verified) {
      _pin.clearFailedAttempts();
      _unlockApp();
    } else {
      _handleFailedAttempt();
    }
  }

  void _handleFailedAttempt() {
    // Three wrong PINs within a minute start a 30 second cooldown
    final cooldown = _pin.registerFailedAttempt();

    if (cooldown) {
      ConstantSnackbar.show(
        title: 'Too many incorrect attempts. Please wait 30 seconds.',
        backgroundColor: Colors.orange,
      );
    } else {
      ConstantSnackbar.showError(
        title:
            'Incorrect PIN. Attempts: ${_pin.failedAttempts}/${PinEntryProvider.maxAttempts}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _pin,
      child: Consumer<PinEntryProvider>(
        builder: (context, pin, _) => _buildScreen(context, pin),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, PinEntryProvider pin) {
    final securityProvider = Provider.of<SecurityProvider>(context);

    // Show loading while security is being initialized
    if (securityProvider.isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo.shade600, Colors.indigo.shade400],
            ),
          ),
          child: Center(
            child: AppLoadingIndicator(size: 40, color: ConstColors.white),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.indigo.shade400,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo.shade600, Colors.indigo.shade400],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 80.r, color: Colors.white),
                  SizedBox(height: 24.h),
                  Text(
                    'Unlock using your PIN',
                    style: getTextTheme().titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (pin.isCooldown)
                    Text(
                      'Please wait 30 seconds',
                      style: getTextTheme().bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
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
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 60.h),
                  // Biometric option (if enabled)
                  if (securityProvider.biometricEnabled &&
                      securityProvider.isDeviceSupported)
                    AbsorbPointer(
                      absorbing: pin.isCooldown || pin.isAuthenticating,
                      child: Opacity(
                        opacity: (pin.isCooldown || pin.isAuthenticating)
                            ? 0.5
                            : 1.0,
                        child: GestureDetector(
                          onTap: pin.isAuthenticating
                              ? null
                              : _checkBiometricAndAuthenticate,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 32.w,
                              vertical: 16.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (pin.isAuthenticating)
                                  SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: AppLoadingIndicator(
                                      size: 20,
                                      color: ConstColors.white,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.fingerprint,
                                    color: Colors.white,
                                    size: 28.r,
                                  ),
                                SizedBox(width: 12.w),
                                Text(
                                  'Unlock using Biometric',
                                  style: getTextTheme().bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 40.h),
                  // Numeric keypad
                  AbsorbPointer(
                    absorbing: pin.isCooldown,
                    child: Opacity(
                      opacity: pin.isCooldown ? 0.5 : 1.0,
                      child: Padding(
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
                                    color: Colors.white,
                                    size: 28.r,
                                  ),
                                  onPressed: pin.backspace,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
          padding: EdgeInsets.all(16.w),
          shape: const CircleBorder(),
          backgroundColor: Colors.white.withOpacity(0.2),
        ),
        child: Text(
          value,
          style: getTextTheme().headlineMedium?.copyWith(
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
