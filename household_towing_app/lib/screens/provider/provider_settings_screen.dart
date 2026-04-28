import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/user_provider.dart';
import '../auth/location_picker_screen.dart';

class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  LatLng? _shopLocation;
  bool _isLoading = true;
  String _providerName = '';
  String _providerPhone = '';

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(uid)
          .get();

      if (providerDoc.exists && mounted) {
        setState(() {
          _providerName = providerDoc['name'] ?? '';
          _providerPhone = providerDoc['phone'] ?? '';
          if (providerDoc['latitude'] != null && providerDoc['longitude'] != null) {
            _shopLocation = LatLng(providerDoc['latitude'], providerDoc['longitude']);
          }
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
                        label: 'Business Name',
                        value: _providerName,
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        label: 'Contact Number',
                        value: _providerPhone,
                        icon: Icons.phone,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Shop Location',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.cardDecoration(context),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: AppTheme.towingOrange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _shopLocation != null ? 'Location Registered' : 'Not Set',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      if (_shopLocation != null)
                                        Text(
                                          '${_shopLocation!.latitude.toStringAsFixed(4)}, ${_shopLocation!.longitude.toStringAsFixed(4)}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final location = await Navigator.push<LatLng>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LocationPickerScreen(initialLocation: _shopLocation),
                                    ),
                                  );
                                  if (location != null) {
                                    final uid = FirebaseAuth.instance.currentUser!.uid;
                                    await FirebaseFirestore.instance.collection('providers').doc(uid).update({
                                      'latitude': location.latitude,
                                      'longitude': location.longitude,
                                    });
                                    setState(() => _shopLocation = location);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Shop location updated!')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.edit_location_alt),
                                label: Text(_shopLocation != null ? 'Update Shop Location' : 'Set Shop Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Logout'),
                                content: const Text('Are you sure you want to log out?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Logout'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await FirebaseAuth.instance.signOut();
                              // Navigation is handled by AuthWrapper
                            }
                          },
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text('Log Out', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSettingItem({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSlateMedium),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
            ],
          ),
        ],
      ),
    );
  }
}
