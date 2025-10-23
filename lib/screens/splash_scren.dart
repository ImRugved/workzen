import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/token_updater.dart';
import 'admin/admin_dashboard.dart';
import 'auth/login_screen.dart';
import 'user/user_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _animationController.forward();

    // Check auth state after animation completes
    Future.delayed(const Duration(seconds: 2), () async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkAuthState();

      // Update FCM tokens for all users
      try {
        log('Updating FCM tokens for all users');
        await TokenUpdater.updateAllUserTokens();
      } catch (e) {
        log('Error updating FCM tokens: $e');
      }

      if (mounted) {
        if (authProvider.isLoggedIn) {
          // User is logged in, navigate to appropriate dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => authProvider.isAdmin
                  ? const AdminDashboard()
                  : const UserDashboard(),
            ),
          );
        } else {
          // User is not logged in, navigate to login screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade700,
              Colors.indigo.shade400,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 80,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 30),
                // App Name
                Center(
                  child: Text(
                    'Attendance Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                const Text(
                  'Manage your leaves easily',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                // Loading indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
