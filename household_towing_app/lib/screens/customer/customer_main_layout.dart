import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'customer_home.dart';
import 'customer_services_screen.dart';
import 'customer_active_bookings_screen.dart';
import 'customer_history_screen.dart';
import 'billing_history_screen.dart';

class CustomerMainLayout extends StatefulWidget {
  const CustomerMainLayout({super.key});

  @override
  State<CustomerMainLayout> createState() => _CustomerMainLayoutState();
}

class _CustomerMainLayoutState extends State<CustomerMainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CustomerHome(),
    const CustomerServicesScreen(),
    const CustomerActiveBookingsScreen(),
    const CustomerHistoryScreen(),
    const BillingHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateLight,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Book',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              activeIcon: Icon(Icons.location_on),
              label: 'Track',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Billing',
            ),
          ],
        ),
      ),
    );
  }
}
