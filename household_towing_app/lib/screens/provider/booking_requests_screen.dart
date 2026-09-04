import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_detail_screen.dart';
import '../../utils/app_theme.dart';
import '../../widgets/provider_drawer.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class BookingRequestsScreen extends StatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      drawer: const ProviderDrawer(),
      appBar: AppBar(
        title: const Text(
          'New Job Requests',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textSlateDark,
          ),
        ),
      ),
      body: Column(
        children: [
          // Info Header
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                const Text(
                  'Review and accept incoming service requests.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSlateMedium,
                  ),
                ),
              ],
            ),
          ),
          // Bookings List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No new requests at the moment',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final booking = snapshot.data!.docs[index];
                    return _BookingCard(
                      booking: booking,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BookingDetailScreen(bookingId: booking.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getStream(String uid) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedProviderId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
}

class _BookingCard extends StatefulWidget {
  final QueryDocumentSnapshot booking;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.onTap});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  String _customerName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadCustomerName();
  }

  void _loadCustomerName() async {
    try {
      final customerId = widget.booking['customerId'];
      if (customerId == null || customerId.isEmpty) {
        if (mounted) setState(() => _customerName = 'Guest Customer');
        return;
      }

      final customerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
          
      if (mounted) {
        if (customerDoc.exists) {
          final data = customerDoc.data() as Map<String, dynamic>;
          setState(() {
            _customerName = data['name'] ?? data['displayName'] ?? 'Customer';
          });
        } else {
          setState(() => _customerName = 'Customer');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _customerName = 'Customer');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textSlateDark.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['serviceType'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSlateDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer: $_customerName',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSlateMedium,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Est. Cost',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSlateLight,
                      ),
                    ),
                    Text(
                      '₱${(booking['estimatedCost'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.statusCompletedText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppTheme.textSlateMedium,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking['address'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSlateMedium,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.towingOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
