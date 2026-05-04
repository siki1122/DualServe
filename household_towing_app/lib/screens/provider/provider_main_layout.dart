import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'provider_home.dart';
import 'provider_tasks_screen.dart';
import 'provider_asset_inventory_screen.dart';
import 'provider_services_screen.dart';
import '../../widgets/provider_drawer.dart';

class ProviderMainLayout extends StatefulWidget {
  const ProviderMainLayout({super.key});

  @override
  State<ProviderMainLayout> createState() => _ProviderMainLayoutState();
}

class _ProviderMainLayoutState extends State<ProviderMainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ProviderHome(),
    const ProviderTasksScreen(),
    const ProviderAssetInventoryScreen(),
    const ProviderServicesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const ProviderDrawer(),
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
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'My Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.build_circle_outlined),
              activeIcon: Icon(Icons.build_circle),
              label: 'Services',
            ),
          ],
        ),
      ),
    );
  }
}
