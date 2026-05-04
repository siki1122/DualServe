import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label = status;

    switch (status.toLowerCase().replaceAll('_', '')) {
      case 'pending':
        bgColor = AppTheme.statusPendingBg;
        textColor = AppTheme.statusPendingText;
        label = 'Pending';
        break;
      case 'accepted':
      case 'assigned':
        bgColor = AppTheme.statusAcceptedBg;
        textColor = AppTheme.statusAcceptedText;
        label = 'Assigned';
        break;
      case 'convertedtotask':
      case 'inprogress':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = 'In Progress';
        break;
      case 'completed':
        bgColor = AppTheme.statusCompletedBg;
        textColor = AppTheme.statusCompletedText;
        label = 'Completed';
        break;
      case 'cancelled':
      case 'rejected':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        label = 'Cancelled';
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
        label.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
