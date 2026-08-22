import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A production-ready, accessible async button that automatically handles
/// loading states and prevents double-submissions.
class PrimaryAsyncButton extends StatefulWidget {
  final String text;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final double borderRadius;
  final bool isDestructive;

  const PrimaryAsyncButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
    this.height = 56.0,
    this.borderRadius = 16.0,
    this.isDestructive = false,
  });

  @override
  State<PrimaryAsyncButton> createState() => _PrimaryAsyncButtonState();
}

class _PrimaryAsyncButtonState extends State<PrimaryAsyncButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading || widget.onPressed == null) return;

    setState(() => _isLoading = true);
    
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine colors
    Color bg = widget.backgroundColor ?? AppTheme.primaryBlue;
    if (widget.isDestructive) {
      bg = Colors.red.shade600;
    }
    
    // Disabled state color
    if (widget.onPressed == null) {
      bg = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300;
    }

    final txtColor = widget.textColor ?? (widget.onPressed == null ? Colors.grey.shade500 : Colors.white);

    Widget buttonContent = _isLoading
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              color: txtColor,
              strokeWidth: 2.5,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: txtColor),
                const SizedBox(width: 8),
              ],
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: txtColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );

    Widget button = Semantics(
      button: true,
      label: _isLoading ? 'Loading ${widget.text}' : widget.text,
      enabled: widget.onPressed != null && !_isLoading,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.isFullWidth ? double.infinity : null,
        height: widget.height,
        child: ElevatedButton(
          onPressed: (_isLoading || widget.onPressed == null) ? null : _handlePress,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: txtColor,
            disabledBackgroundColor: bg, // Let opacity handle visual disable if needed, but we explicitly set bg above
            elevation: widget.onPressed == null ? 0 : (_isLoading ? 0 : 4),
            shadowColor: bg.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isFullWidth ? 0 : 32,
            ),
          ),
          child: buttonContent,
        ),
      ),
    );

    return button;
  }
}
