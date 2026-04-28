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
    final data = jobDoc.data() as Map<String, dynamic>;
    
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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.flash_on, color: AppTheme.towingOrange),
          SizedBox(width: 8),
          Text('New Job Request!', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['serviceType'] ?? 'Service',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('📍 ${data['address'] ?? 'No address'}',
              style: const TextStyle(color: AppTheme.textSlateMedium)),
          const SizedBox(height: 16),
          Text('Est. Payout: ₱${data['estimatedCost']}',
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20)),
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
                    strokeWidth: 6,
                    color: AppTheme.towingOrange,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                Text('$_countdown',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Decline', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await widget.bookingService.acceptBooking(widget.jobDoc.id, widget.providerId);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('ACCEPT JOB', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
