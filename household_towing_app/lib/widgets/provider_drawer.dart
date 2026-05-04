import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/screens/provider/provider_schedule_screen.dart';
import 'package:household_towing_app/screens/provider/provider_tasks_screen.dart';
import 'package:household_towing_app/screens/provider/available_tasks_screen.dart';
import 'package:household_towing_app/screens/provider/provider_settings_screen.dart';
import 'package:household_towing_app/screens/provider/provider_asset_inventory_screen.dart';

import 'package:household_towing_app/screens/provider/provider_services_screen.dart';
import 'package:household_towing_app/screens/provider/provider_history_screen.dart';
import 'package:household_towing_app/screens/provider/provider_earnings_screen.dart';
import 'package:household_towing_app/screens/provider/provider_pricing_settings_screen.dart';

class ProviderDrawer extends StatelessWidget {
  const ProviderDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.towingOrange,
                  child: Icon(Icons.person, size: 35, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Service Provider',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                  ),
                ),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? 'provider@example.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildDrawerItem(
                    context,
                    icon: Icons.task_alt,
                    title: 'My Assigned Tasks',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderTasksScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.search,
                    title: 'Browse Available Tasks',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableTasksScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.calendar_month,
                    title: 'Manage Schedule',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderScheduleScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.inventory_2,
                    title: 'Asset Inventory',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderAssetInventoryScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.handyman,
                    title: 'My Services',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderServicesScreen()));
                    },
                  ),
                  Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
                  _buildDrawerItem(
                    context,
                    icon: Icons.history,
                    title: 'Service History',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderHistoryScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.payments_outlined,
                    title: 'My Earnings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderEarningsScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.sell_outlined,
                    title: 'Pricing Config',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderPricingSettingsScreen()));
                    },
                  ),
                  Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderSettingsScreen()));
                    },
                  ),
                ],
              ),
            ),
          ),
          Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
          _buildDrawerItem(
            context,
            icon: Icons.logout,
            title: 'Logout',
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              // AuthWrapper will handle navigation
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
        ),
      ),
      onTap: onTap,
    );
  }
}
