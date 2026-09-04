import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'provider_home.dart';
import 'provider_tasks_screen.dart';
import 'provider_asset_inventory_screen.dart';
import 'provider_services_screen.dart';
import 'provider_ratings_screen.dart';
import '../../widgets/provider_drawer.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class ProviderMainLayout extends StatefulWidget {
  const ProviderMainLayout({super.key});

  @override
  State<ProviderMainLayout> createState() => _ProviderMainLayoutState();
}

class _ProviderMainLayoutState extends State<ProviderMainLayout> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = [
    const ProviderHome(),
    const ProviderTasksScreen(),
    const ProviderServicesScreen(),
    const ProviderAssetInventoryScreen(),
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
      drawer: const ProviderDrawer(),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppTheme.textSlateDark.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
          selectedItemColor: AppTheme.towingOrange,
          unselectedItemColor: isDark ? AppTheme.textDarkSecondary : Colors.grey.shade400,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.build_circle_outlined),
              activeIcon: Icon(Icons.build_circle),
              label: 'Services',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Assets',
            ),
          ],
        ),
      ),
    );
  }
}
