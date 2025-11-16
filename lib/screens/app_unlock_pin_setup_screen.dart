import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/const_textstyle.dart';
import 'app_unlock_screen.dart';
import 'admin/dashboard/admin_dashboard_screen.dart';
import 'user/dashboard/user_dashboard_screen.dart';

class AppUnlockPinSetupScreen extends StatefulWidget {
  final bool isFirstTime;
  const AppUnlockPinSetupScreen({Key? key, this.isFirstTime = false}) : super(key: key);

  @override
  State<AppUnlockPinSetupScreen> createState() => _AppUnlockPinSetupScreenState();
}

class _AppUnlockPinSetupScreenState extends State<AppUnlockPinSetupScreen> {
  String _enteredPin = '';
  String? _firstPin;
  bool _isConfirming = false;

  void _handleNumericInput(String value) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += value;
      });

      if (_enteredPin.length == 6) {
        if (!_isConfirming) {
          // First PIN entry
          _firstPin = _enteredPin;
          setState(() {
            _isConfirming = true;
            _enteredPin = '';
          });
        } else {
          // Confirm PIN entry
          if (_enteredPin == _firstPin) {
            _savePIN();
          } else {
            _handleMismatch();
          }
        }
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

  void _handleMismatch() {
    setState(() {
      _enteredPin = '';
      _firstPin = null;
      _isConfirming = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PINs do not match. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _savePIN() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);

    final success = await securityProvider.setupAppUnlockPIN(
      authProvider.userModel!.id,
      _enteredPin,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App unlock PIN set successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate to appropriate screen
      if (widget.isFirstTime) {
        // After first-time setup, go to unlock screen then dashboard
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final targetScreen = authProvider.isAdmin
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save PIN. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isConfirming ? 'Confirm PIN' : 'Setup App Unlock PIN',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
      ),
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
                _isConfirming
                    ? 'Confirm your 6-digit PIN'
                    : 'Create a 6-digit PIN to unlock the app',
                style: getTextTheme().titleMedium?.copyWith(
                  color: Colors.white,
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
            ],
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

