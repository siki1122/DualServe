import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'provider_home.dart';
import 'booking_requests_screen.dart';
import 'provider_history_screen.dart';
import 'earnings_history_screen.dart';
import 'provider_pricing_settings_screen.dart';

class ProviderMainLayout extends StatefulWidget {
  const ProviderMainLayout({super.key});

  @override
  State<ProviderMainLayout> createState() => _ProviderMainLayoutState();
}

class _ProviderMainLayoutState extends State<ProviderMainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ProviderHome(),
    const BookingRequestsScreen(),
    const ProviderHistoryScreen(),
    const EarningsHistoryScreen(),
    const ProviderPricingSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
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
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.towingOrange,
          unselectedItemColor: AppTheme.textSlateLight,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Requests',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.attach_money_outlined),
              activeIcon: Icon(Icons.attach_money),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Pricing',
            ),
          ],
        ),
      ),
    );
  }
}
