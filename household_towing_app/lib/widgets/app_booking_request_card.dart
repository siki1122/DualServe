import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class AppBookingRequestCard extends StatelessWidget {
  final Booking? booking;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onAcceptPressed;
  final VoidCallback? onDeclinePressed;
  final bool isProcessing;

  const AppBookingRequestCard({
    super.key,
    this.booking,
    this.isLoading = false,
    this.onTap,
    this.onAcceptPressed,
    this.onDeclinePressed,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || booking == null) {
      return _buildSkeleton(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRejected = booking!.status == BookingStatus.rejected;
    final statusColor = isRejected ? AppTheme.textSlateMedium : AppTheme.towingOrange; // Highlight for new requests

    return Semantics(
      label: 'Booking request for ${booking!.serviceType} at ${booking!.address}',
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: AppTheme.cardDecoration(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          booking!.serviceType.toLowerCase().contains('tow') 
                              ? Icons.car_repair 
                              : Icons.cleaning_services,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking!.serviceType,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking!.address,
                              style: TextStyle(
                                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRejected 
                              ? Colors.grey.withValues(alpha: 0.1) 
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isRejected ? 'DECLINED' : 'NEW REQUEST',
                          style: TextStyle(
                            color: isRejected ? AppTheme.textSlateMedium : AppTheme.primaryBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined, size: 14, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                      const SizedBox(width: 6),
                      Text(
                        _formatDateTime(booking!.scheduledDate, booking!.scheduledTime),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateMedium,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  if (booking!.estimatedCost != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 14, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                        const SizedBox(width: 6),
                        Text(
                          'Est. Cost: ₱${booking!.estimatedCost!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.statusCompletedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Footer Actions (hide if rejected)
                  if (!isRejected)
                    Row(
                    children: [
                      if (onDeclinePressed != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isProcessing ? null : onDeclinePressed,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Colors.redAccent),
                              foregroundColor: Colors.redAccent,
                            ),
                            child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (onDeclinePressed != null && onAcceptPressed != null)
                        const SizedBox(width: 12),
                      if (onAcceptPressed != null)
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isProcessing ? null : onAcceptPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.statusCompletedText,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isProcessing 
                              ? const SizedBox(
                                  height: 20, 
                                  width: 20, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Accept',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date, String time) {
    final dateStr = DateFormat('MMM dd').format(date);
    return '$dateStr, $time';
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 180,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
