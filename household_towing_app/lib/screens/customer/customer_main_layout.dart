import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'customer_home.dart';
import 'customer_active_bookings_screen.dart';
import 'customer_history_screen.dart';
import 'customer_settings_screen.dart';
import '../../widgets/customer_drawer.dart';

class CustomerMainLayout extends StatefulWidget {
  const CustomerMainLayout({super.key});

  @override
  State<CustomerMainLayout> createState() => _CustomerMainLayoutState();
}

class _CustomerMainLayoutState extends State<CustomerMainLayout> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = [
    const CustomerHome(),
    const CustomerActiveBookingsScreen(), // Track
    const CustomerHistoryScreen(),
    const CustomerSettingsScreen(), // Profile
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
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomAppBar(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_outlined, Icons.home, 0),
              _buildNavItem(Icons.location_on_outlined, Icons.location_on, 1),
              _buildNavItem(Icons.history_outlined, Icons.history, 2),
              _buildNavItem(Icons.person_outline, Icons.person, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, int index) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => _onTabTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected 
                ? AppTheme.primaryBlue 
                : (isDark ? AppTheme.textDarkSecondary : Colors.grey.shade400),
            size: 26,
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 4,
              width: 4,
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
