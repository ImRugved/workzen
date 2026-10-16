import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/security_provider.dart';
import '../../providers/toggle_provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_textfield.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../utils/validators.dart';
import '../app_unlock_pin_setup_screen.dart';
import '../app_unlock_screen.dart';
import '../admin/dashboard/admin_dashboard_screen.dart';
import '../user/dashboard/user_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Password visibility (scoped state, no setState)
  final ToggleProvider _passwordVisible = ToggleProvider();

  void _showForgotPasswordDialog(BuildContext context) {
    final resetEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Form(
          key: formKey,
          child: ConstTextField(
            controller: resetEmailController,
            customText: 'Please enter your email',
            prefixIcon: Icon(Icons.email_outlined, size: 20.r),
            keyoardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                Navigator.pop(context);
                final result = await authProvider.resetPassword(
                  resetEmailController.text.trim(),
                );
                if (result['success']) {
                  ConstantSnackbar.showSuccess(title: result['message']);
                } else {
                  ConstantSnackbar.showError(title: result['error']);
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      bool success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        // Check security settings
        final securityProvider = Provider.of<SecurityProvider>(
          context,
          listen: false,
        );
        await securityProvider.initializeSecurity(authProvider.userModel!.id);

        // Check if app unlock PIN exists (mandatory)
        final hasPin = await securityProvider.hasAppUnlockPIN(
          authProvider.userModel!.id,
        );

        final targetScreen =
            (authProvider.isAdmin || authProvider.userModel?.isSubAdmin == true)
            ? const AdminDashboardScreen()
            : const UserDashboardScreen();

        if (!hasPin) {
          // PIN not set - show setup screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  const AppUnlockPinSetupScreen(isFirstTime: true),
            ),
          );
        } else {
          // PIN exists - show unlock screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AppUnlockScreen(child: targetScreen),
            ),
          );
        }
      } else if (mounted) {
        ConstantSnackbar.showError(
          title: 'Login failed. Please check your email and password.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.screen,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo or App Name
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 80.r,
                    color: ConstColors.primaryDeep,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Attendance Management',
                    textAlign: TextAlign.center,
                    style: getTextTheme().headlineSmall?.copyWith(
                      color: ConstColors.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: getTextTheme().bodyLarge?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                  SizedBox(height: 48.h),

                  // Email Field
                  ConstTextField(
                    controller: _emailController,
                    customText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, size: 20.r),
                    keyoardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  SizedBox(height: 16.h),

                  // Password Field
                  ChangeNotifierProvider.value(
                    value: _passwordVisible,
                    child: Consumer<ToggleProvider>(
                      builder: (context, visible, _) => ConstTextField(
                        controller: _passwordController,
                        customText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline, size: 20.r),
                        obsercureText: !visible.value,
                        iconss: IconButton(
                          icon: Icon(
                            visible.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: ConstColors.textColorLight,
                          ),
                          onPressed: visible.toggle,
                        ),
                        validator: Validators.password,
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Login Button
                  ConstantButton(
                    text: 'Sign In',
                    isLoading: authProvider.isLoading,
                    onPressed: _login,
                  ),

                  // Forgot Password Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showForgotPasswordDialog(context),
                      child: Text(
                        'Forgot Password?',
                        style: getTextTheme().bodyMedium?.copyWith(
                          color: ConstColors.primaryDeep,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: getTextTheme().bodyMedium?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.toNamed('/signup_screen');
                        },
                        child: Text(
                          'Sign Up',
                          style: getTextTheme().labelLarge?.copyWith(
                            color: ConstColors.primaryDeep,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordVisible.dispose();
    super.dispose();
  }
}
