import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;
  String _selectedRole = 'customer';

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_selectedRole == 'driver' && _inviteCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a company invite code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Save to users collection
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'email': user.email,
          'phone': _phoneController.text.trim(),
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (_selectedRole == 'driver') {
          // Verify provider exists with this invite code
          final inviteCode = _inviteCodeController.text.trim();
          final providerSnapshot = await FirebaseFirestore.instance
              .collection('providers')
              .where('inviteCode', isEqualTo: inviteCode)
              .limit(1)
              .get();

          if (providerSnapshot.docs.isEmpty) {
            throw Exception('Invalid Company Invite Code');
          }

          final providerId = providerSnapshot.docs.first.id;

          await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set({
            'uid': user.uid,
            'providerId': providerId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': user.email,
            'status': 'available',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Also auto-add them to the company's asset inventory
          await FirebaseFirestore.instance.collection('assets').doc(user.uid).set({
            'name': _nameController.text.trim(),
            'category': 'Driver',
            'type': 'crew',
            'status': 'active',
            'ownerId': providerId,
            'quantity': 1,
            'isConsumable': false,
            'jobsCompleted': 0,
            'metadata': {
              'email': user.email,
              'phone': _phoneController.text.trim(),
            }
          });
        }

        // If provider, create provider doc too
        if (_selectedRole == 'provider') {
          await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
            'uid': user.uid,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': user.email,
            'serviceType': 'Towing', // Default
            'status': 'available',
            'services': ['Towing'],
            'isApproved': true, // Auto-approve
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Refresh user data
        if (mounted) {
          await Provider.of<UserProvider>(context, listen: false).loadCurrentUserData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.person_add_outlined, size: 64, color: AppTheme.primaryBlue),
              const SizedBox(height: 24),
              const Text(
                'Finish Your Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlateDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'We need a few more details to get you started.',
                style: TextStyle(fontSize: 16, color: AppTheme.textSlateMedium),
              ),
              const SizedBox(height: 40),
              
              const Text(
                'I want to be a:',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildRoleCard('customer', Icons.person, 'Customer'),
                  const SizedBox(width: 8),
                  _buildRoleCard('provider', Icons.home_repair_service, 'Provider'),
                  const SizedBox(width: 8),
                  _buildRoleCard('driver', Icons.local_shipping, 'Driver'),
                ],
              ),
              const SizedBox(height: 32),
              
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              if (_selectedRole == 'driver') ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _inviteCodeController,
                  decoration: InputDecoration(
                    labelText: 'Company Invite Code',
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continue to Dashboard',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String role, IconData icon, String label) {
    bool isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
