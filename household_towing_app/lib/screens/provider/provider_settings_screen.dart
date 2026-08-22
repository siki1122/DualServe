import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/widgets/shimmer_loading.dart';
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
          if (providerDoc['latitude'] != null &&
              providerDoc['longitude'] != null) {
            _shopLocation = LatLng(
              providerDoc['latitude'],
              providerDoc['longitude'],
            );
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
          backgroundColor: isDark
              ? AppTheme.backgroundDark
              : AppTheme.background,
          appBar: AppBar(
            title: Text(
              'Account Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppTheme.textDarkPrimary
                    : AppTheme.textSlateDark,
              ),
            ),
          ),
          body: _isLoading
              ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: ShimmerLoading.listPlaceholder(count: 4),
              )
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
                          color: isDark
                              ? AppTheme.textDarkPrimary
                              : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: AppTheme.cardDecoration(context),
                        child: SwitchListTile(
                          title: const Text('Dark Mode'),
                          subtitle: Text(
                            userProvider.isDarkMode
                                ? 'Using dark theme'
                                : 'Using light theme',
                            style: const TextStyle(fontSize: 12),
                          ),
                          secondary: Icon(
                            userProvider.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
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
                          color: isDark
                              ? AppTheme.textDarkPrimary
                              : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSettingItem(
                        label: 'Business Name',
                        value: _providerName,
                        icon: Icons.business,
                        onEdit: () => _editField('Business Name', _providerName, 'name'),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        label: 'Contact Number',
                        value: _providerPhone,
                        icon: Icons.phone,
                        onEdit: () => _editField('Contact Number', _providerPhone, 'phone'),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        label: 'Password',
                        value: '••••••••',
                        icon: Icons.lock,
                        onEdit: _changePassword,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Shop Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.textDarkPrimary
                              : AppTheme.textSlateDark,
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
                                const Icon(
                                  Icons.location_on,
                                  color: AppTheme.towingOrange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _shopLocation != null
                                            ? 'Location Registered'
                                            : 'Not Set',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_shopLocation != null)
                                        Text(
                                          '${_shopLocation!.latitude.toStringAsFixed(4)}, ${_shopLocation!.longitude.toStringAsFixed(4)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSlateMedium,
                                          ),
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
                                  final location =
                                      await Navigator.push<LatLng>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              LocationPickerScreen(
                                                initialLocation: _shopLocation,
                                              ),
                                        ),
                                      );
                                  if (location != null) {
                                    final uid =
                                        FirebaseAuth.instance.currentUser!.uid;
                                    await FirebaseFirestore.instance
                                        .collection('providers')
                                        .doc(uid)
                                        .update({
                                          'latitude': location.latitude,
                                          'longitude': location.longitude,
                                        });
                                    setState(() => _shopLocation = location);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Shop location updated!'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.edit_location_alt),
                                label: Text(
                                  _shopLocation != null
                                      ? 'Update Shop Location'
                                      : 'Set Shop Location',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
                          color: isDark
                              ? AppTheme.textDarkPrimary
                              : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                final isDark = Theme.of(context).brightness == Brightness.dark;
                                return AlertDialog(
                                  backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  title: Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                                    ),
                                  ),
                                  content: Text(
                                    'Are you sure you want to log out?',
                                    style: TextStyle(
                                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                                        foregroundColor: Colors.red,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                      child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              await FirebaseAuth.instance.signOut();
                              // Navigation is handled by AuthWrapper
                            }
                          },
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            'Log Out',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isGoogleUser = user.providerData.any((userInfo) => userInfo.providerId == 'google.com');
    if (isGoogleUser) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Google Sign-In'),
          content: const Text('Your account is linked to Google. Password changes are managed through your Google Account.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Okay'),
            ),
          ],
        ),
      );
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Change Password',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Please enter your current password and your new password.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                      decoration: AppTheme.textFieldDecoration(
                        label: 'Current Password',
                        prefixIcon: Icons.lock_outline,
                        isDark: isDark,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                      decoration: AppTheme.textFieldDecoration(
                        label: 'New Password',
                        prefixIcon: Icons.lock_outline,
                        isDark: isDark,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                      decoration: AppTheme.textFieldDecoration(
                        label: 'Confirm New Password',
                        prefixIcon: Icons.lock_outline,
                        isDark: isDark,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                      validator: (v) => v != newPasswordController.text ? 'Passwords do not match' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, {
                      'current': currentPasswordController.text,
                      'new': newPasswordController.text,
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final currentPassword = result['current']!;
      final newPassword = result['new']!;
      final email = user.email;
      
      if (email == null) return;

      try {
        AuthCredential credential = EmailAuthProvider.credential(
          email: email, 
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to change password. Make sure current password is correct.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editField(String title, String currentValue, String fieldName) async {
    final controller = TextEditingController(text: currentValue);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Edit $title',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
            ),
          ),
          content: TextField(
            controller: controller,
            style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
            decoration: AppTheme.textFieldDecoration(
              label: 'New $title',
              prefixIcon: Icons.edit_outlined,
              isDark: isDark,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != currentValue) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      try {
        await FirebaseFirestore.instance.collection('providers').doc(uid).update({
          fieldName: result,
        });

        // Data Consistency: If the Business Name changed, update related collections
        if (fieldName == 'name') {
          final assetsQuery = await FirebaseFirestore.instance
              .collection('assets')
              .where('ownerId', isEqualTo: uid)
              .get();
          
          if (assetsQuery.docs.isNotEmpty) {
            final batch = FirebaseFirestore.instance.batch();
            for (var doc in assetsQuery.docs) {
              batch.update(doc.reference, {'providerName': result});
            }
            await batch.commit();
          }
        }

        setState(() {
          if (fieldName == 'name') _providerName = result;
          if (fieldName == 'phone') _providerPhone = result;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title updated!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update $title: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildSettingItem({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onEdit,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSlateMedium),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
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
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: AppTheme.primaryBlue),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
