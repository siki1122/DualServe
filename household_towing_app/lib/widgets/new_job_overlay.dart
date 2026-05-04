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
            final newJob = snapshot.docs.first;
            _showNewJobDialog(newJob);
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
    final data = widget.jobDoc.data() as Map<String, dynamic>;
    final payout = (data['estimatedCost'] ?? 0.0).toDouble();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.towingOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flash_on, color: AppTheme.towingOrange),
                ),
                const SizedBox(width: 12),
                const Text(
                  'New Job Request!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              data['serviceType'] ?? 'Service',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['address'] ?? 'No address provided',
                      style: const TextStyle(
                        color: AppTheme.textSlateMedium,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  const Text(
                    'ESTIMATED PAYOUT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${payout.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
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
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: _countdown / 30,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: AppTheme.towingOrange,
                      backgroundColor: AppTheme.towingOrange.withOpacity(0.1),
                    ),
                  ),
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: AppTheme.textSlateDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        color: Colors.red,
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
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'ACCEPT JOB',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
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
