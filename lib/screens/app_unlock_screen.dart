import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/const_textstyle.dart';

class AppUnlockScreen extends StatefulWidget {
  final Widget child;
  const AppUnlockScreen({Key? key, required this.child}) : super(key: key);

  @override
  State<AppUnlockScreen> createState() => _AppUnlockScreenState();
}

class _AppUnlockScreenState extends State<AppUnlockScreen> {
  String _enteredPin = '';
  List<DateTime> _failedAttemptTimes = [];
  bool _isCooldown = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize security settings first
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
      
      // Make sure security is initialized
      await securityProvider.initializeSecurity(authProvider.userModel!.id);
      
      // Only auto-trigger biometric if it's enabled
      if (securityProvider.biometricEnabled && securityProvider.isDeviceSupported) {
        _checkBiometricAndAuthenticate();
      }
    });
  }

  Future<void> _checkBiometricAndAuthenticate() async {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);

    // Double check biometric is enabled before authenticating
    if (!securityProvider.biometricEnabled || !securityProvider.isDeviceSupported) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    final authenticated = await securityProvider.authenticateWithBiometrics(
      reason: 'Unlock the app',
    );

    if (authenticated) {
      _unlockApp();
    } else {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  void _unlockApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => widget.child),
    );
  }

  void _handleNumericInput(String value) {
    if (_isCooldown) return;

    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += value;
      });

      if (_enteredPin.length == 6) {
        _verifyPIN();
      }
    }
  }

  void _handleBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPIN() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);

    final verified = await securityProvider.verifyAppUnlockPIN(
      authProvider.userModel!.id,
      _enteredPin,
    );

    if (verified) {
      _failedAttemptTimes.clear();
      _unlockApp();
    } else {
      _handleFailedAttempt();
    }
  }

  void _handleFailedAttempt() {
    final now = DateTime.now();
    _failedAttemptTimes.add(now);

    // Remove attempts older than 1 minute
    _failedAttemptTimes.removeWhere(
      (time) => now.difference(time) > const Duration(minutes: 1),
    );

    setState(() {
      _enteredPin = '';
    });

    if (_failedAttemptTimes.length >= 3) {
      _startCooldown();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Incorrect PIN. Attempts: ${_failedAttemptTimes.length}/3',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startCooldown() {
    setState(() {
      _isCooldown = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Too many incorrect attempts. Please wait 30 seconds.'),
        backgroundColor: Colors.orange,
      ),
    );

    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isCooldown = false;
          _failedAttemptTimes.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final securityProvider = Provider.of<SecurityProvider>(context);

    // Show loading while security is being initialized
    if (securityProvider.isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.shade600,
                Colors.indigo.shade400,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.shade600,
                Colors.indigo.shade400,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80.r,
                  color: Colors.white,
                ),
                SizedBox(height: 24.h),
                Text(
                  'Unlock using your PIN',
                  style: getTextTheme().titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                if (_isCooldown)
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
                        color: _enteredPin.length > index
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 60.h),
                // Biometric option (if enabled)
                if (securityProvider.biometricEnabled &&
                    securityProvider.isDeviceSupported)
                  AbsorbPointer(
                    absorbing: _isCooldown || _isAuthenticating,
                    child: Opacity(
                      opacity: (_isCooldown || _isAuthenticating) ? 0.5 : 1.0,
                      child: GestureDetector(
                        onTap: _isAuthenticating
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
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isAuthenticating)
                                SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
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
                  absorbing: _isCooldown,
                  child: Opacity(
                    opacity: _isCooldown ? 0.5 : 1.0,
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
                                onPressed: _handleBackspace,
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
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

