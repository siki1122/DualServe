import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/booking_model.dart';
import 'package:household_towing_app/models/asset_model.dart';
import 'package:household_towing_app/models/provider_model.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import '../chat/chat_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('bookings').doc(widget.booking.id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Booking no longer exists')),
          );
        }

        final booking = Booking.fromFirestore(snapshot.data!);

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text(
              'Booking Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSlateDark,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service details
                _buildSectionCard(
                  title: 'Service Details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem('Service Type', booking.serviceType),
                      const SizedBox(height: 12),
                      _buildDetailItem('Location', booking.address),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        'Scheduled',
                        '${booking.scheduledDate.toString().split(' ')[0]} at ${booking.scheduledTime}',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        'Status',
                        booking.status.toString().split('.').last.toUpperCase(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                _buildSectionCard(
                  title: 'Payment Summary',
                  child: Column(
                    children: [
                      _buildPriceRow('Base Fare', '₱${(booking.estimatedCost ?? 0) * 0.4 > 500 ? 500 : (booking.estimatedCost ?? 0) * 0.4}'),
                      const SizedBox(height: 8),
                      _buildPriceRow('Distance & Service Fee', '₱${(booking.estimatedCost ?? 0) * 0.6}'),
                      const Divider(height: 24),
                      _buildPriceRow(
                        'Total Estimated Cost',
                        '₱${booking.estimatedCost?.toStringAsFixed(2) ?? '0.00'}',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Provider Message Section
                if (booking.assignedProviderId != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppTheme.primaryBlue,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.assignedPersonnelNames.isNotEmpty
                                    ? booking.assignedPersonnelNames.first
                                    : 'Assigned Provider',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.textSlateDark,
                                ),
                              ),
                              const Text(
                                'Ready to assist you',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSlateMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text('Message'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

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
                                        color: AppTheme.primaryBlue.withOpacity(0.1),
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
              ],
            ),
          ),
        );
      },
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
        borderRadius: BorderRadius.circular(12),
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
