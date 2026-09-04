import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:household_towing_app/utils/app_theme.dart';


enum BadgeSize { small, normal, large }

/// A production-ready, accessible status badge that maps strings/enums
/// to standardized app theme colors automatically.
class StatusBadge extends StatelessWidget {
  final String status;
  final BadgeSize size;
  final bool showIcon;

  const StatusBadge({
    super.key,
    required this.status,
    this.size = BadgeSize.normal,
    this.showIcon = true,
  });

  /// Maps a status string to its corresponding theme colors
  _BadgeTheme _getThemeForStatus(String statusText, bool isDark) {
    final text = statusText.toLowerCase();

    if (text.contains('complete') || text.contains('verified') || text.contains('available') || text.contains('success')) {
      return _BadgeTheme(
        background: AppTheme.statusCompletedBg,
        text: AppTheme.statusCompletedText,
        icon: Icons.check_circle_rounded,
      );
    } else if (text.contains('progress') || text.contains('active') || text.contains('converted')) {
      return _BadgeTheme(
        background: AppTheme.statusInProgressBg,
        text: AppTheme.statusInProgressText,
        icon: Icons.sync_rounded,
      );
    } else if (text.contains('cancel') || text.contains('reject') || text.contains('offline') || text.contains('fail')) {
      return _BadgeTheme(
        background: AppTheme.statusCancelledBg,
        text: AppTheme.statusCancelledText,
        icon: Icons.cancel_rounded,
      );
    } else if (text.contains('pending') || text.contains('wait') || text.contains('assigned') || text.contains('accept')) {
      return _BadgeTheme(
        background: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade100,
        text: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
        icon: Icons.schedule_rounded,
      );
    }

    // Default neutral theme
    return _BadgeTheme(
      background: isDark ? AppTheme.textSlateMedium.withValues(alpha: 0.2) : Colors.grey.shade200,
      text: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
      icon: Icons.info_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = _getThemeForStatus(status, isDark);

    // Dynamic sizing
    double horizontalPadding = 12.0;
    double verticalPadding = 6.0;
    double fontSize = 12.0;
    double iconSize = 14.0;

    switch (size) {
      case BadgeSize.small:
        horizontalPadding = 8.0;
        verticalPadding = 4.0;
        fontSize = 10.0;
        iconSize = 12.0;
        break;
      case BadgeSize.large:
        horizontalPadding = 16.0;
        verticalPadding = 8.0;
        fontSize = 14.0;
        iconSize = 16.0;
        break;
      case BadgeSize.normal:
      default:
        break;
    }

    // Format text to Title Case (e.g., "in_progress" -> "In Progress")
    String formattedText = status
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '')
        .join(' ');

    // Map internal technical statuses to user-friendly terms consistent with the system
    if (status.toLowerCase() == 'converted_to_task') {
      formattedText = 'In Progress';
    }

    return Semantics(
      label: 'Status: $formattedText',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(100), // Fully rounded pill shape
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showIcon) ...[
              Icon(
                theme.icon,
                size: iconSize,
                color: theme.text,
              ),
              SizedBox(width: size == BadgeSize.small ? 4.0 : 6.0),
            ],
            Text(
              formattedText,
              style: TextStyle(
                color: theme.text,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                height: 1.2, // Consistent vertical centering
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTheme {
  final Color background;
  final Color text;
  final IconData icon;

  _BadgeTheme({
    required this.background,
    required this.text,
    required this.icon,
  });
}
