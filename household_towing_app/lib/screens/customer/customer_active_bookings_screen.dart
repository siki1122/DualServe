import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';
import 'customer_tracking_screen.dart';

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
          .where('status', whereIn: ['pending', 'accepted'])
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Active Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textSlateDark,
        automaticallyImplyLeading: false,
      ),
      body: _bookings.isEmpty && !_isLoading
          ? Center(
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
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              itemCount: _bookings.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                // Loading indicator at bottom
                if (index == _bookings.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.towingOrange,
                        ),
                      ),
                    ),
                  );
                }

                final booking = _bookings[index];
                final isAccepted = booking['status'] == 'accepted';

                return GestureDetector(
                  onTap: isAccepted
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerTrackingScreen(
                                bookingId: booking.id,
                                bookingData:
                                    booking.data() as Map<String, dynamic>,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.cardDecoration(context),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: booking['serviceType'] == 'Towing'
                                    ? AppTheme.towingOrange.withOpacity(0.1)
                                    : AppTheme.householdBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                booking['serviceType'] == 'Towing'
                                    ? Icons.car_repair
                                    : Icons.cleaning_services,
                                color: booking['serviceType'] == 'Towing'
                                    ? AppTheme.towingOrange
                                    : AppTheme.householdBlue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking['serviceType'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppTheme.textSlateDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking['address'] ?? 'Unknown location',
                                    style: const TextStyle(
                                      color: AppTheme.textSlateMedium,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: booking['status']),
                          ],
                        ),
                        if (isAccepted) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Scheduled: ${booking['scheduledDate']?.toDate().toString().split(' ')[0] ?? 'N/A'} at ${booking['scheduledTime'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSlateMedium,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
