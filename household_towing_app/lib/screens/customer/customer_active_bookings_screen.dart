import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/booking_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';
import 'customer_service_tracking_screen.dart';
import '../chat/chat_screen.dart';
import 'customer_tracking_screen.dart';
import 'customer_booking_details_screen.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/customer_drawer.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class CustomerActiveBookingsScreen extends StatefulWidget {
  const CustomerActiveBookingsScreen({super.key});

  @override
  State<CustomerActiveBookingsScreen> createState() =>
      _CustomerActiveBookingsScreenState();
}

class _CustomerActiveBookingsScreenState
    extends State<CustomerActiveBookingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      drawer: const CustomerDrawer(),
      appBar: AppBar(
        title: const Text(
          'Active Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
      ),
      body: StreamBuilder<List<Booking>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('customerId', isEqualTo: userId)
            .where('status', whereIn: ['pending', 'accepted', 'converted_to_task'])
            .snapshots()
            .map((snapshot) {
              final bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
              bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return bookings;
            }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
            );
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
                  Icon(Icons.inbox_outlined, size: 80, color: AppTheme.textSlateLight),
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
                  onTap: () => _navigateToDetailsOrTracking(context, booking),
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
                                    ? AppTheme.towingOrange.withValues(alpha: 0.1)
                                    : AppTheme.householdBlue.withValues(alpha: 0.1),
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
                              color: Colors.blue.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ASSIGNED RESOURCES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (booking.assignedTruckName != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.local_shipping, size: 16, color: AppTheme.primaryBlue),
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
                                      const Icon(Icons.person, size: 16, color: AppTheme.primaryBlue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: booking.assignedPersonnelNames.map((name) => Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textSlateDark,
                                              ),
                                            ),
                                          )).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                        
                        // NEW: Progress Bar directly on the card
                        if (booking.status == BookingStatus.converted_to_task || booking.status == BookingStatus.accepted)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('tasks')
                                .where('bookingId', isEqualTo: booking.id)
                                .snapshots(),
                            builder: (context, taskSnapshot) {
                              if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final taskData = taskSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                              final double progress = (taskData['progress'] as num?)?.toDouble() ?? 0.0;
                              
                              if (progress <= 0) return const SizedBox.shrink();
                              
                              return Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Service Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
                                        Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 6,
                                        backgroundColor: AppTheme.textSlateLight.withValues(alpha: 0.5),
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _navigateToDetailsOrTracking(context, booking),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primaryBlue,
                                  elevation: 0,
                                  side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('View Details'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (booking.status == BookingStatus.converted_to_task)
                              Expanded(
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.map, size: 18),
                                  label: const Text('Track Map'),
                                ),
                              )
                            else if (isTrackable && booking.assignedProviderId != null)
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

  void _navigateToDetailsOrTracking(BuildContext context, Booking booking) {
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
      }).catchError((error) {
        // Fallback to details if there is a permission error or network failure
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerBookingDetailsScreen(
              booking: booking,
            ),
          ),
        );
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
  }
}
