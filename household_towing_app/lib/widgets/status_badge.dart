import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = AppTheme.statusPendingBg;
        textColor = AppTheme.statusPendingText;
        break;
      case 'accepted':
        bgColor = AppTheme.statusAcceptedBg;
        textColor = AppTheme.statusAcceptedText;
        break;
      case 'completed':
        bgColor = AppTheme.statusCompletedBg;
        textColor = AppTheme.statusCompletedText;
        break;
      default:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
