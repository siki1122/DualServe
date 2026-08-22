import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../utils/app_theme.dart';
import '../../services/booking_service.dart';
import 'package:flutter/services.dart';

class NewJobOverlay extends StatefulWidget {
  final Widget child;

  const NewJobOverlay({super.key, required this.child});

  @override
  State<NewJobOverlay> createState() => _NewJobOverlayState();
}

class _NewJobOverlayState extends State<NewJobOverlay> {
  StreamSubscription? _subscription;
  final BookingService _bookingService = BookingService();
  final String _currentProviderId = FirebaseAuth.instance.currentUser!.uid;
  bool _isShowingDialog = false;
  static final Set<String> _notifiedJobIds = {};

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _subscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedProviderId', isEqualTo: _currentProviderId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty && !_isShowingDialog) {
            for (var doc in snapshot.docs) {
              if (!_notifiedJobIds.contains(doc.id)) {
                _notifiedJobIds.add(doc.id);
                _showNewJobDialog(doc);
                break; // Show one at a time
              }
            }
          }
        });
  }

  void _showNewJobDialog(DocumentSnapshot jobDoc) {
    _isShowingDialog = true;

    // Play sound/vibration
    HapticFeedback.vibrate();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timer.tick > 3 || !_isShowingDialog) {
        timer.cancel();
      } else {
        HapticFeedback.lightImpact();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _NewJobDialogContent(
        jobDoc: jobDoc,
        providerId: _currentProviderId,
        bookingService: _bookingService,
      ),
    ).then((_) {
      _isShowingDialog = false;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _NewJobDialogContent extends StatefulWidget {
  final DocumentSnapshot jobDoc;
  final String providerId;
  final BookingService bookingService;

  const _NewJobDialogContent({
    required this.jobDoc,
    required this.providerId,
    required this.bookingService,
  });

  @override
  State<_NewJobDialogContent> createState() => _NewJobDialogContentState();
}

class _NewJobDialogContentState extends State<_NewJobDialogContent> {
  int _countdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        if (mounted) {
          setState(() => _countdown--);
        }
      } else {
        timer.cancel();
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.jobDoc.data() as Map<String, dynamic>;
    final payout = (data['estimatedCost'] ?? 0.0).toDouble();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'New Job Request',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textSlateDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? Colors.white54 : Colors.black54,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              data['serviceType'] ?? 'Service',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textSlateDark,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data['address'] ?? 'No address provided',
                    style: TextStyle(
                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'ESTIMATED PAYOUT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${payout.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textSlateDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: _countdown / 30,
                      strokeWidth: 4,
                      color: isDark ? Colors.white : Colors.black87,
                      backgroundColor: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  Text(
                    '$_countdown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: isDark ? Colors.white : AppTheme.textSlateDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await widget.bookingService.rejectBooking(widget.jobDoc.id);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not decline job: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                    ),
                    child: Text(
                      'Decline',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await widget.bookingService.acceptBooking(
                          widget.jobDoc.id,
                          widget.providerId,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not accept job: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Accept Job',
                      style: TextStyle(
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
  }
}
