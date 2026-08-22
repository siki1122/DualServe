import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/booking_model.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import '../chat/chat_screen.dart';
import '../../services/review_service.dart';
import '../../models/review_model.dart';
import '../../models/transaction_model.dart' as tm;
import '../../utils/pricing_constants.dart';
import 'receipt_screen.dart';
import '../../models/task_model.dart';
import 'customer_tracking_screen.dart';
class CustomerBookingDetailsScreen extends StatefulWidget {
  final Booking booking;

  const CustomerBookingDetailsScreen({super.key, required this.booking});

  @override
  State<CustomerBookingDetailsScreen> createState() =>
      _CustomerBookingDetailsScreenState();
}

class _CustomerBookingDetailsScreenState
    extends State<CustomerBookingDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Stream<DocumentSnapshot> _bookingStream;
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;

  @override
  void initState() {
    super.initState();
    _bookingStream = _firestore.collection('bookings').doc(widget.booking.id).snapshots();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _bookingStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        Booking booking = widget.booking;

        if (snapshot.hasData && snapshot.data!.exists) {
          booking = Booking.fromFirestore(snapshot.data!);
        } else if (snapshot.connectionState != ConnectionState.waiting && snapshot.hasData && !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Booking no longer exists')),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Details', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: AppTheme.textSlateDark,
            actions: [
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large Gradient Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7061FA), Color(0xFF4B3CFA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF4B3CFA).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          booking.status.toString().split('.').last.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        booking.serviceType,
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${booking.scheduledDate.toString().split(' ')[0]} at ${booking.scheduledTime}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Primary Action Button matches "Start Task"
                if (booking.assignedProviderId != null)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final receiverId = booking.assignedDriverId != null && booking.assignedDriverId!.isNotEmpty 
                                ? booking.assignedDriverId! 
                                : booking.assignedProviderId!;
                            final receiverName = booking.assignedPersonnelNames.isNotEmpty
                                ? booking.assignedPersonnelNames.first
                                : (booking.assignedDriverId != null ? 'Driver' : 'Provider');
                                
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  bookingId: booking.id,
                                  receiverId: receiverId,
                                  receiverName: receiverName,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                            elevation: 0,
                          ),
                          child: Text(
                            booking.assignedDriverId != null ? 'Message Driver' : 'Message Provider', 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.favorite_border, color: AppTheme.textSlateMedium),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                if (booking.assignedProviderId != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Assigned Provider',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSlateDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('providers').doc(booking.assignedProviderId).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final providerData = snapshot.data!.data() as Map<String, dynamic>;
                      final String providerName = providerData['name'] ?? 'Unknown Provider';
                      final String providerPhone = providerData['phone'] ?? 'N/A';
                      final double rating = (providerData['rating'] as num?)?.toDouble() ?? 0.0;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppTheme.towingOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.local_shipping,
                                color: AppTheme.towingOrange,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    providerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textSlateDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSlateMedium),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, color: AppTheme.primaryBlue, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        providerPhone,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
                
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSlateDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Service location is at ${booking.address}. Ensure to prepare the site before the provider arrives. Contact the provider for any specific instructions.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSlateMedium,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(height: 16),

                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('tasks')
                      .where('bookingId', isEqualTo: booking.id)
                      .where('customerId', isEqualTo: booking.customerId)
                      .limit(1)
                      .snapshots(),
                  builder: (context, taskSnapshot) {
                    if (taskSnapshot.hasError) {
                      debugPrint('Error loading task progress: ${taskSnapshot.error}');
                      return const SizedBox.shrink();
                    }
                    if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final task = Task.fromFirestore(taskSnapshot.data!.docs.first);
                    final taskData = taskSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                    final double progress = (taskData['progress'] as num?)?.toDouble() ?? 0.0;
                    final String status = taskData['status'] ?? '';
                    
                    if (progress <= 0 || status == 'unassigned') return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          _buildSectionCard(
                            title: 'Service Progress',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Completion', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateMedium)),
                                    Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                  ),
                                ),
                                if (taskData['milestones'] != null) ...[
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: (taskData['milestones'] as List).map((m) {
                                        final bool isCompleted = m['isCompleted'] ?? false;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isCompleted ? Colors.green.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isCompleted)
                                                  const Padding(
                                                    padding: EdgeInsets.only(right: 4.0),
                                                    child: Icon(Icons.check, size: 12, color: Colors.green),
                                                  ),
                                                Text(
                                                  m['title'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                                                    color: isCompleted ? Colors.green[700] : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          if (status == 'inProgress' || status == 'assigned') ...[
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Live Tracking',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Track your service provider in real-time as they approach your location.',
                                    style: TextStyle(color: AppTheme.textSlateMedium, fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CustomerTrackingScreen(
                                              bookingId: booking.id,
                                              bookingData: booking.toFirestore(),
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.map, size: 20),
                                      label: const Text('View Live Tracking Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),

                // Truck details
                if (booking.assignedTruckName != null)
                  _buildSectionCard(
                    title: 'Assigned Truck',
                    child: FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('assets').doc(booking.assignedTruckId).get(),
                      builder: (context, assetSnap) {
                        final plateNumber = (assetSnap.data?.data() as Map<String, dynamic>?)?['plateNumber'] ?? 'N/A';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailItem('Vehicle', booking.assignedTruckName!),
                            const SizedBox(height: 12),
                            _buildDetailItem('Plate Number', plateNumber),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),

                // Payment Summary
                if (booking.status == BookingStatus.completed)
                  FutureBuilder<QuerySnapshot>(
                    future: _firestore.collection('transactions')
                        .where('bookingId', isEqualTo: booking.id)
                        .where('customerId', isEqualTo: booking.customerId)
                        .limit(1)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading receipt: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                      
                      final transactionData = snapshot.data!.docs.first;
                      final transaction = tm.Transaction.fromFirestore(transactionData);
                      
                      return _buildSectionCard(
                        title: 'Payment Details',
                        child: Column(
                          children: [
                            _buildPriceRow('Total Final Cost', PricingConfig.formatPrice(transaction.finalCost), isTotal: true),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  String providerName = 'Unknown Provider';
                                  if (booking.assignedProviderId != null) {
                                    final providerDoc = await _firestore.collection('providers').doc(booking.assignedProviderId).get();
                                    providerName = (providerDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown Provider';
                                  }
                                  
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReceiptScreen(
                                          booking: booking,
                                          transaction: transaction,
                                          providerName: providerName,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('View Official e-Receipt'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: const BorderSide(color: AppTheme.primaryBlue),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  _buildSectionCard(
                    title: 'Payment Summary',
                    child: Column(
                      children: [
                        _buildPriceRow(
                          'Total Estimated Cost',
                          '₱${booking.estimatedCost?.toStringAsFixed(2) ?? '0.00'}',
                          isTotal: true,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Includes base fare, distance surcharge, and night differential (if applicable).',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSlateMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Replaced Provider Message Section because it is now at the top


                // Assigned Personnel
                if (booking.assignedPersonnelNames.isNotEmpty)
                  _buildSectionCard(
                    title: 'Assigned Personnel',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: booking.assignedPersonnelNames
                          .map((name) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: AppTheme.primaryBlue,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.textSlateDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 16),

                // Assigned Assets
                if (booking.assignedAssets.isNotEmpty)
                  _buildSectionCard(
                    title: 'Equipment & Tools',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: booking.assignedAssets.entries
                          .map((entry) => FutureBuilder<DocumentSnapshot>(
                                future: _firestore.collection('assets').doc(entry.key).get(),
                                builder: (context, assetSnap) {
                                  final name = (assetSnap.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Loading...';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppTheme.textSlateDark,
                                          ),
                                        ),
                                        Text(
                                          'Qty: ${entry.value}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 32),

                // Rating Section
                if (booking.status == BookingStatus.completed && !booking.isReviewed && booking.assignedProviderId != null)
                  _buildRatingSection(booking),
                
                if (booking.status == BookingStatus.completed && booking.isReviewed)
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'You have rated this service!',
                          style: TextStyle(color: AppTheme.textSlateMedium, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingSection(Booking booking) {
    return _buildSectionCard(
      title: 'Rate Your Provider',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'How was your service?',
            style: TextStyle(fontSize: 16, color: AppTheme.textSlateDark),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 40,
                ),
                onPressed: () {
                  setState(() {
                    _rating = index + 1;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Leave a comment (optional)',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _rating == 0 || _isSubmittingReview
                  ? null
                  : () async {
                      setState(() => _isSubmittingReview = true);
                      try {
                        final review = Review(
                          id: '', // Generated by Firestore
                          bookingId: booking.id,
                          customerId: booking.customerId,
                          providerId: booking.assignedProviderId!,
                          rating: _rating.toDouble(),
                          comment: _commentController.text.trim(),
                          createdAt: DateTime.now(),
                        );
                        await ReviewService().submitReview(review);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Thank you for your rating!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isSubmittingReview = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.towingOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmittingReview
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? AppTheme.textSlateDark : AppTheme.textSlateMedium,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.green : AppTheme.textSlateDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSlateDark,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSlateMedium,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSlateDark,
          ),
        ),
      ],
    );
  }
}
