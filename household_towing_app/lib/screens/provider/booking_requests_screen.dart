import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_detail_screen.dart';
import '../../utils/app_theme.dart';
import '../../widgets/provider_drawer.dart';

class BookingRequestsScreen extends StatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const ProviderDrawer(),
      appBar: AppBar(
        title: const Text(
          'Requests',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'New',
                  isSelected: _filter == 'pending',
                  onTap: () => setState(() => _filter = 'pending'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Active',
                  isSelected: _filter == 'active',
                  onTap: () => setState(() => _filter = 'active'),
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
                  return const Center(child: CircularProgressIndicator());
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
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No requests found',
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
    Query query = FirebaseFirestore.instance.collection('bookings').where('providerId', isEqualTo: uid);
    
    if (_filter == 'pending') {
      query = query.where('status', isEqualTo: 'pending');
    } else if (_filter == 'active') {
      query = query.where('status', whereIn: ['accepted', 'in_progress']);
    } else {
      // all non-completed
      query = query.where('status', whereIn: ['pending', 'accepted', 'in_progress']);
    }

    return query.snapshots();
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.textSlateDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.textSlateDark : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textSlateMedium,
            fontSize: 14,
          ),
        ),
      ),
    );
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
      final customerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.booking['customerId'])
          .get();
      if (mounted) {
        setState(() {
          _customerName = customerDoc['name'] ?? 'Unknown Customer';
        });
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final status = booking['status'] as String;

    Color statusColor = AppTheme.statusPendingBg;
    Color statusTextColor = AppTheme.statusPendingText;
    String statusText = 'Pending';

    if (status == 'accepted') {
      statusColor = AppTheme.statusAcceptedBg;
      statusTextColor = AppTheme.statusAcceptedText;
      statusText = 'Accepted';
    } else if (status == 'in_progress') {
      statusColor = AppTheme.towingOrange.withOpacity(0.1);
      statusTextColor = AppTheme.towingOrange;
      statusText = 'In Progress';
    }

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
              color: Colors.black.withOpacity(0.03),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              booking['serviceType'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSlateDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer: $_customerName',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSlateMedium),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Est. Cost',
                      style: TextStyle(fontSize: 10, color: AppTheme.textSlateLight),
                    ),
                    Text(
                      '₱${booking['estimatedCost']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSlateMedium),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking['address'],
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSlateMedium),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (status == 'pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.towingOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('View Request'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onTap,
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Start Service'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textSlateDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
