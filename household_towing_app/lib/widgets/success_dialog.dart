import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/app_theme.dart';

class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onPressed;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.onPressed,
  });

  static void show(BuildContext context, {required String title, required String message, VoidCallback? onPressed}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SuccessDialog(title: title, message: message, onPressed: onPressed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.network(
              'https://lottie.host/76672323-8686-4e56-8a7e-125027581177/vP7E5YV1X7.json',
              width: 150,
              height: 150,
              repeat: false,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSlateDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSlateMedium,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed ?? () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Great!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
