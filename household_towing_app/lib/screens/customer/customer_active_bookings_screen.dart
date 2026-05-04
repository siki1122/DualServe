import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/booking_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';
import 'customer_service_tracking_screen.dart';
import 'customer_tracking_screen.dart';
import 'customer_booking_details_screen.dart';
import '../chat/chat_screen.dart';

class CustomerActiveBookingsScreen extends StatefulWidget {
  const CustomerActiveBookingsScreen({super.key});

  @override
  State<CustomerActiveBookingsScreen> createState() =>
      _CustomerActiveBookingsScreenState();
}

class _CustomerActiveBookingsScreenState
    extends State<CustomerActiveBookingsScreen> {
  late ScrollController _scrollController;
  List<QueryDocumentSnapshot> _bookings = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadMoreBookings();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Infinite scroll: Load more when near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMoreData) {
        _loadMoreBookings();
      }
    }
  }

  Future<void> _loadMoreBookings() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      var query = FirebaseFirestore.instance
          .collection('bookings')
          .where(
            'customerId',
            isEqualTo: FirebaseAuth.instance.currentUser!.uid,
          )
          .where(
            'status',
            whereIn: ['pending', 'accepted', 'converted_to_task'],
          )
          .orderBy('scheduledDate', descending: true)
          .limit(20);

      final lastDocument = _lastDocument;
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() => _hasMoreData = false);
      } else {
        setState(() {
          _bookings.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.last;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Active Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textSlateDark,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Booking>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('customerId', isEqualTo: userId)
            .where('status', whereIn: ['pending', 'accepted', 'converted_to_task'])
            .snapshots()
            .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final bookings = snapshot.data ?? [];

          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No active bookings right now.',
                    style: TextStyle(
                      color: AppTheme.textSlateMedium,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final isTrackable = booking.status != BookingStatus.pending;

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: AppTheme.cardDecoration(context),
                child: InkWell(
                  onTap: () {
                    if (booking.status == BookingStatus.converted_to_task) {
                      // Navigate to tracking if task exists
                      FirebaseFirestore.instance
                          .collection('tasks')
                          .where('bookingId', isEqualTo: booking.id)
                          .limit(1)
                          .get()
                          .then((taskSnap) {
                        if (taskSnap.docs.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerServiceTrackingScreen(
                                taskId: taskSnap.docs.first.id,
                              ),
                            ),
                          );
                        } else {
                          // Fallback to details if task doc not found yet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerBookingDetailsScreen(
                                booking: booking,
                              ),
                            ),
                          );
                        }
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerBookingDetailsScreen(
                            booking: booking,
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: booking.serviceType == 'Towing'
                                    ? AppTheme.towingOrange.withOpacity(0.1)
                                    : AppTheme.householdBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                booking.serviceType == 'Towing'
                                    ? Icons.car_repair
                                    : Icons.cleaning_services,
                                color: booking.serviceType == 'Towing'
                                    ? AppTheme.towingOrange
                                    : AppTheme.householdBlue,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking.serviceType,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppTheme.textSlateDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking.address,
                                    style: const TextStyle(
                                      color: AppTheme.textSlateMedium,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: booking.status.name),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSlateMedium),
                            const SizedBox(width: 6),
                            Text(
                              '${booking.scheduledDate.toString().split(' ')[0]} at ${booking.scheduledTime}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSlateMedium,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        // Assigned Assets Section
                        if (booking.assignedTruckName != null || booking.assignedPersonnelNames.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.withOpacity(0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ASSIGNED RESOURCES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (booking.assignedTruckName != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.local_shipping, size: 16, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text(
                                          booking.assignedTruckName!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textSlateDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (booking.assignedPersonnelNames.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(
                                        booking.assignedPersonnelNames.first,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSlateDark,
                                        ),
                                      ),
                                      if (booking.assignedPersonnelNames.length > 1)
                                        Text(
                                          ' +${booking.assignedPersonnelNames.length - 1} more',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSlateMedium,
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CustomerBookingDetailsScreen(
                                        booking: booking,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primaryBlue,
                                  elevation: 0,
                                  side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('View Details'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isTrackable && booking.assignedProviderId != null)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          bookingId: booking.id,
                                          receiverId: booking.assignedProviderId!,
                                          receiverName: booking.assignedPersonnelNames.isNotEmpty
                                              ? booking.assignedPersonnelNames.first
                                              : 'Provider',
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                  label: const Text('Message'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
