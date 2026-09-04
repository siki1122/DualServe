import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'driver_home.dart';
import 'driver_profile_screen.dart';
import 'driver_equipment_screen.dart';
import 'driver_history_screen.dart';
import 'driver_available_tasks_screen.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class DriverMainLayout extends StatefulWidget {
  const DriverMainLayout({super.key});

  @override
  State<DriverMainLayout> createState() => _DriverMainLayoutState();
}

class _DriverMainLayoutState extends State<DriverMainLayout> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const DriverHome(),
    const DriverHistoryScreen(),
    const DriverProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: _currentIndex == 0 ? AppBar(
        title: const Text('Staff App', style: TextStyle(color: AppTheme.textSlateDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textSlateDark),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ) : null,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.textSlateMedium,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'My Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
