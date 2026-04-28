import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isEmailVerified = false;
  bool _canResendEmail = true;
  Timer? _timer;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    
    _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!_isEmailVerified) {
      // Start polling for verification status
      _timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _checkEmailVerified(),
      );
    }
  }

  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified && mounted) {
        setState(() => _isEmailVerified = true);
        _timer?.cancel();
        
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'isEmailVerified': true});
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        setState(() {
          _canResendEmail = false;
          _resendCountdown = 60;
        });
        _startCountdown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email resent!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        setState(() => _canResendEmail = true);
        timer.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEmailVerified) {
      // This will trigger AuthWrapper to rebuild and redirect to Home
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 80,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We have sent a verification link to:',
                style: TextStyle(
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                FirebaseAuth.instance.currentUser?.email ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Please check your inbox (and spam folder) and click the link to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _canResendEmail ? _sendVerificationEmail : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    _canResendEmail 
                      ? 'Resend Verification Email' 
                      : 'Resend in $_resendCountdown s',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text(
                  'Cancel and Logout',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
