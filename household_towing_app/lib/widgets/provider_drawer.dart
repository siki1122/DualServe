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
import 'package:household_towing_app/screens/provider/provider_ratings_screen.dart';
import 'package:household_towing_app/screens/provider/provider_team_screen.dart';

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
                    icon: Icons.group,
                    title: 'My Team (Drivers)',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderTeamScreen()));
                    },
                  ),
                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),

                  _buildDrawerItem(
                    context,
                    icon: Icons.star_outline,
                    title: 'My Ratings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderRatingsScreen()));
                    },
                  ),
                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),
                  _buildDrawerItem(
                    context,
                    icon: Icons.calendar_month,
                    title: 'Manage Schedule',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderScheduleScreen()));
                    },
                  ),

                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),
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

                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),
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
          Divider(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),
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
