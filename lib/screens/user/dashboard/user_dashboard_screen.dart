import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/value_provider.dart';
import '../../../widgets/floating_nav_bar.dart';
import '../user_home.dart';
import 'demo_page.dart';
import '../../profile_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({Key? key}) : super(key: key);

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  // Selected tab (scoped state, no setState)
  final ValueProvider<int> _selectedIndex = ValueProvider<int>(0);
  late PageController _pageController;

  final List<Widget> _screens = [
    const UserHome(),
    const UserDemoPage(),
    const ProfileScreen(),
  ];

  // Titles reserved for potential future use

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _selectedIndex.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _selectedIndex.value = index;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<bool> _onWillPop(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop(context);
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: _screens,
          onPageChanged: (index) => _selectedIndex.value = index,
        ),
        bottomNavigationBar: ChangeNotifierProvider.value(
          value: _selectedIndex,
          child: Selector<ValueProvider<int>, int>(
            selector: (_, tab) => tab.value,
            builder: (context, selected, _) => FloatingNavBar(
              currentIndex: selected,
              onTap: _onItemTapped,
              items: const [
                NavBarItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                ),
                NavBarItem(
                  icon: Icons.info_outline,
                  activeIcon: Icons.info,
                  label: 'Info',
                ),
                NavBarItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
