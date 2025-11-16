import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/const_textstyle.dart';
import 'package:local_auth/local_auth.dart';
import 'app_unlock_pin_setup_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({Key? key}) : super(key: key);

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userModel != null) {
        Provider.of<SecurityProvider>(context, listen: false)
            .initializeSecurity(authProvider.userModel!.id);
      }
    });
  }

  Future<void> _setupBiometric() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);

    if (!securityProvider.isDeviceSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication is not supported on this device'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if app unlock PIN exists (mandatory)
    final hasPin = await securityProvider.hasAppUnlockPIN(authProvider.userModel!.id);
    
    if (!hasPin) {
      // Show dialog to setup PIN first
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Setup App Unlock PIN', style: getTextTheme().titleMedium),
          content: Text(
            'You need to set up a 6-digit app unlock PIN first before enabling biometric authentication.',
            style: getTextTheme().bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: getTextTheme().labelLarge),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppUnlockPinSetupScreen(),
                  ),
                ).then((_) {
                  // After PIN setup, try enabling biometric again
                  _setupBiometric();
                });
              },
              child: Text('Setup PIN', style: getTextTheme().labelLarge),
            ),
          ],
        ),
      );
      return;
    }

    // Test biometric authentication
    final authenticated = await securityProvider.authenticateWithBiometrics(
      reason: 'Authenticate to enable biometric login',
    );

    if (authenticated) {
      final success = await securityProvider.toggleBiometric(
        authProvider.userModel!.id,
        true,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication enabled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Security',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
      ),
      body: Consumer<SecurityProvider>(
        builder: (context, securityProvider, child) {
          if (securityProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Biometric Authentication Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biometric Authentication',
                          style: getTextTheme().titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        if (securityProvider.isDeviceSupported)
                          Text(
                            'Available: ${securityProvider.availableBiometrics.map((e) {
                              switch (e) {
                                case BiometricType.face:
                                  return 'Face ID';
                                case BiometricType.fingerprint:
                                  return 'Fingerprint';
                                case BiometricType.iris:
                                  return 'Iris';
                                case BiometricType.strong:
                                  return 'Strong Biometric';
                                case BiometricType.weak:
                                  return 'Weak Biometric';
                              }
                            }).join(', ')}',
                            style: getTextTheme().bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          )
                        else
                          Text(
                            'Not supported on this device',
                            style: getTextTheme().bodySmall?.copyWith(
                              color: Colors.orange,
                            ),
                          ),
                        SizedBox(height: 16.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Enable Biometric',
                              style: getTextTheme().bodyMedium,
                            ),
                            Switch(
                              value: securityProvider.biometricEnabled,
                              onChanged: (value) async {
                                final authProvider =
                                    Provider.of<AuthProvider>(context, listen: false);
                                if (value) {
                                  await _setupBiometric();
                                } else {
                                  await securityProvider.toggleBiometric(
                                    authProvider.userModel!.id,
                                    false,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        if (!securityProvider.biometricEnabled &&
                            securityProvider.isDeviceSupported)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _setupBiometric,
                              icon: Icon(Icons.fingerprint, size: 20.r),
                              label: Text('Setup Biometric'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                // App Unlock PIN Info
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Unlock PIN',
                          style: getTextTheme().titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'A 6-digit PIN is required to unlock the app. This is mandatory for app security.',
                          style: getTextTheme().bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 20.r),
                            SizedBox(width: 8.w),
                            Text(
                              securityProvider.hasAppUnlockPin
                                  ? 'PIN is configured'
                                  : 'PIN not configured',
                              style: getTextTheme().bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
