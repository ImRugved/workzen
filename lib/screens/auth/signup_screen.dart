import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/security_provider.dart';
import '../../providers/toggle_provider.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_textfield.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_snackbar.dart';
import '../../utils/validators.dart';
import '../app_unlock_pin_setup_screen.dart';
import '../app_unlock_screen.dart';
import '../admin/dashboard/admin_dashboard_screen.dart';
import '../user/dashboard/user_dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _secretCodeController = TextEditingController();
  // Password visibility (scoped state, no setState)
  final ToggleProvider _passwordVisible = ToggleProvider();
  final ToggleProvider _confirmPasswordVisible = ToggleProvider();

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Map<String, dynamic> result = await authProvider.signup(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _secretCodeController.text.trim(),
      );

      if (result['success'] && mounted) {
        // Show success message
        ConstantSnackbar.showSuccess(
          title: result['message'] ?? 'Your account is ready',
        );

        // Check security settings
        final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
        await securityProvider.initializeSecurity(authProvider.userModel!.id);
        
        // Check if app unlock PIN exists (mandatory)
        final hasPin = await securityProvider.hasAppUnlockPIN(authProvider.userModel!.id);
        
        final targetScreen = (authProvider.isAdmin || authProvider.userModel?.isSubAdmin == true)
            ? const AdminDashboardScreen()
            : const UserDashboardScreen();
        
        if (!hasPin) {
          // PIN not set - show setup screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const AppUnlockPinSetupScreen(isFirstTime: true),
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
        // Show specific error message
        String errorMessage =
            result['error'] ?? 'Registration failed. Please try again.';
        Color backgroundColor = Colors.red;

        // Special handling for database not found error
        if (result['errorType'] == 'database_not_found') {
          backgroundColor = Colors.orange;
        } else if (result['errorType'] == 'permission_denied') {
          backgroundColor = Colors.deepOrange;
        }

        ConstantSnackbar.show(
          title: errorMessage,
          backgroundColor: backgroundColor,
          // Longer for important errors
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.indigo),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo or App Name
                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: getTextTheme().headlineSmall?.copyWith(
                          color: Colors.indigo,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Sign up to get started',
                    textAlign: TextAlign.center,
                    style: getTextTheme().bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  SizedBox(height: 32.h),

                  // Name Field
                  ConstTextField(
                    controller: _nameController,
                    customText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline, size: 20.r),
                    validator: Validators.required('your name'),
                  ),
                  SizedBox(height: 16.h),

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
                            color: Colors.grey,
                          ),
                          onPressed: visible.toggle,
                        ),
                        validator: Validators.password,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Confirm Password Field
                  ChangeNotifierProvider.value(
                    value: _confirmPasswordVisible,
                    child: Consumer<ToggleProvider>(
                      builder: (context, visible, _) => ConstTextField(
                        controller: _confirmPasswordController,
                        customText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_outline, size: 20.r),
                        obsercureText: !visible.value,
                        iconss: IconButton(
                          icon: Icon(
                            visible.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: visible.toggle,
                        ),
                        validator: Validators.confirmPassword(
                          () => _passwordController.text,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Secret Code Field (for admin)
                  ConstTextField(
                    controller: _secretCodeController,
                    customText: 'Secret Code (optional for admin)',
                    prefixIcon: Icon(Icons.key_outlined, size: 20.r),
                  ),
                  SizedBox(height: 24.h),

                  // Signup Button
                  ConstantButton(
                    text: 'Sign Up',
                    isLoading: authProvider.isLoading,
                    onPressed: _signup,
                  ),
                  SizedBox(height: 16.h),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: getTextTheme()
                            .bodyMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        child: Text('Sign In',
                            style: getTextTheme().labelLarge?.copyWith(
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.bold,
                                )),
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _secretCodeController.dispose();
    _passwordVisible.dispose();
    _confirmPasswordVisible.dispose();
    super.dispose();
  }
}
