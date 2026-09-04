import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

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
  final _inviteCodeController = TextEditingController();
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
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain an uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain a number';
    }
    if (!RegExp(r'[!@#\$%\^&\*\-_\.=\+]').hasMatch(password)) {
      return r'Password must contain a special character (!@#$%^&*-_.=+)';
    }
    return null;
  }

  /// Validate phone number
  String? _validatePhone(String phone) {
    if (phone.isEmpty) return 'Phone number is required';
    // Remove all non-digit and non-plus/minus characters for validation
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d\+\-]'), '');
    if (cleanPhone.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    if (!RegExp(r'^\+?[\d\-]{9,}$').hasMatch(phone)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Format phone to E.164
  String _getFormattedPhone() {
    String p = _phoneController.text.trim();
    if (p.startsWith('0')) {
      return '+63${p.substring(1)}';
    }
    if (!p.startsWith('+')) {
      return '+$p';
    }
    return p;
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
          icon: const Icon(Icons.arrow_back, color: AppTheme.textSlateDark),
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
                  color: AppTheme.textSlateDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join us today and start booking services',
                style: TextStyle(fontSize: 16, color: AppTheme.textSlateMedium),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Join as',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlateDark,
                ),
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
                          color: _selectedRole == 'customer'
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: _selectedRole == 'customer'
                                ? AppTheme.primaryBlue
                                : AppTheme.textSlateLight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person,
                              color: _selectedRole == 'customer'
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textSlateMedium,
                            ),
                            const SizedBox(height: 4),
                            const Text('Customer', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedRole = 'provider'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'provider'
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: _selectedRole == 'provider'
                                ? AppTheme.primaryBlue
                                : AppTheme.textSlateLight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.build,
                              color: _selectedRole == 'provider'
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textSlateMedium,
                            ),
                            const SizedBox(height: 4),
                            const Text('Provider', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedRole = 'driver'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'driver'
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: _selectedRole == 'driver'
                                ? AppTheme.primaryBlue
                                : AppTheme.textSlateLight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color: _selectedRole == 'driver'
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textSlateMedium,
                            ),
                            const SizedBox(height: 4),
                            const Text('Driver', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedRole == 'driver') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _inviteCodeController,
                  decoration: InputDecoration(
                    labelText: 'Company Invite Code',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              if (_selectedRole == 'provider') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                          isExpanded: true,
                  initialValue: _selectedServiceType,
                  decoration: InputDecoration(
                    labelText: 'Service Category',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Household',
                      child: Text('Household Services'),
                    ),
                    DropdownMenuItem(
                      value: 'Towing',
                      child: Text('Towing Services'),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _selectedServiceType = value ?? 'Household',
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _sendEmailOTP(String email, String name, String otp) async {
    const serviceId = 'service_qi2p2hj';
    const templateId = 'template_bz2chir';
    const userId = 'bwUMI_HXOkvaCYkUR';
    
    try {
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': userId,
          'template_params': {
            'to_name': name,
            'email': email,
            'passcode': otp,
            'time': '15 minutes', 
          }
        }),
      );
      
      if (response.statusCode == 200) {
        return null; // Success, no error
      } else {
        return 'EmailJS Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'EmailJS Exception: $e';
    }
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
    if (_selectedRole == 'driver' && _inviteCodeController.text.trim().isEmpty) {
      errors.add('Company invite code is required for drivers');
    }

    // Show errors if any
    if (errors.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please fix the following:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...errors.map(
                  (error) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $error'),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    try {
      setState(() => _isLoading = true);

      final email = _emailController.text.trim();
      
      // TEST BYPASS: If email is an example.com domain, skip OTP and EmailJS
      if (email.endsWith('@example.com')) {
        await _finalizeEmailRegistration();
        return;
      }

      // Generate a random 6-digit OTP
      final random = Random();
      final otp = (100000 + random.nextInt(900000)).toString();

      // Send the OTP via EmailJS
      final errorMessage = await _sendEmailOTP(email, _nameController.text.trim(), otp);

      setState(() => _isLoading = false);

      if (errorMessage == null) {
        _showEmailOTPDialog(otp);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $errorMessage'),
          duration: const Duration(seconds: 10),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _showEmailOTPDialog(String generatedOtp) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.email_outlined,
                      color: AppTheme.primaryBlue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify Email Address',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSlateDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the 6-digit code sent to\n${_emailController.text.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSlateMedium,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: isVerifying ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppTheme.textSlateMedium,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isVerifying ? null : () async {
                            final enteredOtp = otpController.text.trim();
                            if (enteredOtp.length != 6) return;

                            if (enteredOtp == generatedOtp) {
                              setDialogState(() => isVerifying = true);
                              if (mounted) Navigator.pop(context); // close dialog
                              await _finalizeEmailRegistration();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invalid Code! Please try again.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isVerifying
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Verify',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _finalizeEmailRegistration() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = credential.user!;

      String? providerId;
      if (_selectedRole == 'driver') {
        final inviteCode = _inviteCodeController.text.trim();
        final providerSnapshot = await FirebaseFirestore.instance
            .collection('providers')
            .where('inviteCode', isEqualTo: inviteCode)
            .limit(1)
            .get();

        if (providerSnapshot.docs.isEmpty) {
          await user.delete();
          throw Exception('Invalid Company Invite Code');
        }
        providerId = providerSnapshot.docs.first.id;
      }

      final String role = _selectedRole;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _getFormattedPhone(),
        'role': role,
        'isEmailVerified': false,
        'isPhoneVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_selectedRole == 'provider') {
        // Generate invite code from first 6 chars of UID so drivers can join
        final providerInviteCode = user.uid.substring(0, 6).toUpperCase();
        await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _getFormattedPhone(),
          'serviceType': _selectedServiceType,
          'status': 'offline',
          'rating': 0.0,
          'jobsCompleted': 0,
          'isApproved': true, // Auto-approve
          'inviteCode': providerInviteCode,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (_selectedRole == 'driver') {
        await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set({
          'uid': user.uid,
          'providerId': providerId,
          'name': _nameController.text.trim(),
          'phone': _getFormattedPhone(),
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
            'phone': _getFormattedPhone(),
          }
        });
      }

      if (mounted) {
        await Provider.of<UserProvider>(context, listen: false).loadCurrentUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      String msg = e.toString();
      if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
         msg = 'Email is already registered. Please use a different email.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration error: $msg')));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }
}
