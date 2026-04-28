import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'customer'; // Default role
  String _selectedServiceType = 'Household'; // Default for providers

  // ============================================================================
  // VALIDATORS
  // ============================================================================

  /// Validate email format
  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    // Pattern: valid@email.com
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate password strength
  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Password must contain an uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Password must contain a number';
    if (!RegExp(r'[!@#\$%\^&\*\-_\.=\+]').hasMatch(password)) return r'Password must contain a special character (!@#$%^&*-_.=+)';
    return null;
  }

  /// Validate phone number
  String? _validatePhone(String phone) {
    if (phone.isEmpty) return 'Phone number is required';
    // Remove all non-digit and non-plus/minus characters for validation
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d\+\-]'), '');
    if (cleanPhone.length < 10) return 'Phone number must be at least 10 digits';
    if (!RegExp(r'^\+?[\d\-]{9,}$').hasMatch(phone)) return 'Please enter a valid phone number';
    return null;
  }

  /// Validate name
  String? _validateName(String name) {
    if (name.trim().isEmpty) return 'Name is required';
    if (name.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join us today and start booking services',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Join as',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedRole = 'customer'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'customer' ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                          border: Border.all(color: _selectedRole == 'customer' ? Colors.blue : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.person, color: _selectedRole == 'customer' ? Colors.blue : Colors.grey),
                            const SizedBox(height: 4),
                            const Text('Customer'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedRole = 'provider'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'provider' ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                          border: Border.all(color: _selectedRole == 'provider' ? Colors.blue : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.build, color: _selectedRole == 'provider' ? Colors.blue : Colors.grey),
                            const SizedBox(height: 4),
                            const Text('Provider'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedRole == 'provider') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedServiceType,
                  decoration: InputDecoration(
                    labelText: 'Service Category',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Household', child: Text('Household Services')),
                    DropdownMenuItem(value: 'Towing', child: Text('Towing Services')),
                  ],
                  onChanged: (value) => setState(() => _selectedServiceType = value ?? 'Household'),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _register() async {
    // ========================================================================
    // VALIDATION
    // ========================================================================
    final nameError = _validateName(_nameController.text);
    final emailError = _validateEmail(_emailController.text);
    final phoneError = _validatePhone(_phoneController.text);
    final passwordError = _validatePassword(_passwordController.text);

    // Collect all errors
    List<String> errors = [];
    if (nameError != null) errors.add(nameError);
    if (emailError != null) errors.add(emailError);
    if (phoneError != null) errors.add(phoneError);
    if (passwordError != null) errors.add(passwordError);

    // Show errors if any
    if (errors.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please fix the following:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...errors.map((error) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $error'),
                )),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create User
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );


      // 3. Save User Profile to Firestore
      final String role = _selectedRole == 'customer' ? 'customer' : 'pending_provider';
      
      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': role,

        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. If Provider, create initial provider profile
      if (_selectedRole == 'provider') {
        await FirebaseFirestore.instance.collection('providers').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'serviceType': _selectedServiceType,
          'status': 'offline',
          'rating': 5.0,
          'jobsCompleted': 0,
          'isApproved': false, // Crucial for security
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'An error occurred';
      // Map Firebase error codes to user-friendly messages
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered. Please use a different email.';
      } else if (e.code == 'weak-password') {
        message = 'The password is too weak. Please use a stronger password.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is invalid.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
