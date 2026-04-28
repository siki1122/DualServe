import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/user_provider.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  bool _isLoading = true;
  String _name = '';
  String _phone = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _name = userDoc['name'] ?? '';
          _phone = userDoc['phone'] ?? '';
          _email = FirebaseAuth.instance.currentUser?.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return Scaffold(
          backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
          appBar: AppBar(
            title: Text(
              'Account Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: AppTheme.cardDecoration(context),
                        child: SwitchListTile(
                          title: const Text('Dark Mode'),
                          subtitle: Text(
                            userProvider.isDarkMode ? 'Using dark theme' : 'Using light theme',
                            style: const TextStyle(fontSize: 12),
                          ),
                          secondary: Icon(
                            userProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            color: AppTheme.primaryBlue,
                          ),
                          value: userProvider.isDarkMode,
                          onChanged: (val) => userProvider.toggleTheme(),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Profile Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSettingItem(
                        label: 'Full Name',
                        value: _name,
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        label: 'Email Address',
                        value: _email,
                        icon: Icons.email,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        label: 'Contact Number',
                        value: _phone,
                        icon: Icons.phone,
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            userProvider.clear();
                            if (mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSettingItem({required String label, required String value, required IconData icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
