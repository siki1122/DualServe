import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../widgets/customer_drawer.dart';
import 'package:household_towing_app/utils/app_theme.dart';


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
          drawer: const CustomerDrawer(),
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
                        onEdit: () => _editField('Full Name', _name, 'name'),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        label: 'Email Address',
                        value: _email,
                        icon: Icons.email,
                        onEdit: _editEmail,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        label: 'Contact Number',
                        value: _phone,
                        icon: Icons.phone,
                        onEdit: () => _editField('Contact Number', _phone, 'phone'),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        label: 'Password',
                        value: '••••••••',
                        icon: Icons.lock,
                        onEdit: _changePassword,
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
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
                              userProvider.clear();
                              if (mounted) {
                                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                              }
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

  Future<void> _editEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isGoogleUser = user.providerData.any((userInfo) => userInfo.providerId == 'google.com');
    if (isGoogleUser) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Google Sign-In'),
          content: const Text('Your account is securely linked to Google. To change your email address, you would need to use a different Google account or link an email/password.'),
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

    final emailController = TextEditingController(text: _email);
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Change Email Address',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Please enter your new email and current password to verify your identity.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                  decoration: AppTheme.textFieldDecoration(
                    label: 'New Email Address',
                    prefixIcon: Icons.email_outlined,
                    isDark: isDark,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                  decoration: AppTheme.textFieldDecoration(
                    label: 'Current Password',
                    prefixIcon: Icons.lock_outline,
                    isDark: isDark,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
              ),
              ElevatedButton(
                onPressed: () {
                  final newEmail = emailController.text.trim();
                  final password = passwordController.text;
                  if (newEmail.isNotEmpty && password.isNotEmpty) {
                    Navigator.pop(context, {'email': newEmail, 'password': password});
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
      final newEmail = result['email']!;
      final password = result['password']!;
      
      if (newEmail == _email) return;

      try {
        final user = FirebaseAuth.instance.currentUser!;
        
        // 1. Re-authenticate
        AuthCredential credential = EmailAuthProvider.credential(
          email: _email, 
          password: password,
        );
        await user.reauthenticateWithCredential(credential);

        // 2. Update Email in Auth (using verifyBeforeUpdateEmail)
        await user.verifyBeforeUpdateEmail(newEmail);

        // 3. Update Email in Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'email': newEmail,
        });

        setState(() {
          _email = newEmail;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email updated successfully!'), backgroundColor: AppTheme.statusCompletedText),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update email: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
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
      
      if (currentPassword == newPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New password cannot be the same as the current password.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
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
            const SnackBar(content: Text('Password changed successfully!'), backgroundColor: AppTheme.statusCompletedText),
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
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          fieldName: result,
        });
        setState(() {
          if (fieldName == 'name') _name = result;
          if (fieldName == 'phone') _phone = result;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title updated!'), backgroundColor: AppTheme.statusCompletedText),
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
          Icon(icon, color: AppTheme.primaryBlue),
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
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                  ),
                  overflow: TextOverflow.ellipsis,
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
