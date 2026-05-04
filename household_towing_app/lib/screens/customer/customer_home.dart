import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../widgets/service_action_card.dart';
import '../../widgets/status_badge.dart';
import 'booking_screen.dart';
import 'customer_tracking_screen.dart';
import 'customer_service_tracking_screen.dart';
import 'towing_map_screen.dart';

import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'customer_settings_screen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  void _loadUserName() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      setState(() {
        _userName = doc['name'] ?? 'Customer';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profile & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello! 👋',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                          ),
                        ),
                        Text(
                          _userName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                            shape: BoxShape.circle,
                            boxShadow: isDark ? [] : [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.settings_outlined,
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CustomerSettingsScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                            shape: BoxShape.circle,
                            boxShadow: isDark ? [] : [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 32),
                
                // Services Section
                Text(
                  'Our Services',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: ServiceActionCard(
                          title: 'Household',
                          icon: Icons.cleaning_services,
                          backgroundColor: AppTheme.householdBlue,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingScreen(serviceType: 'Cleaning')));
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: ServiceActionCard(
                          title: 'Towing',
                          icon: Icons.car_repair,
                          backgroundColor: AppTheme.towingOrange,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const TowingMapScreen()));
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Recent Bookings Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Bookings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('See All', style: TextStyle(color: AppTheme.primaryBlue)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('customerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.cardDecoration(context),
                        child: Center(
                          child: Text(
                            'No bookings yet!\nSelect a service above to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateLight,
                              height: 1.5,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final booking = snapshot.data!.docs[index];
                        final status = booking['status'];
                        final bool isTrackable = status == 'accepted' || status == 'converted_to_task';

                        return GestureDetector(
                          onTap: isTrackable
                              ? () {
                                  if (status == 'converted_to_task') {
                                    // Find task then navigate
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
                                      }
                                    });
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CustomerTrackingScreen(
                                          bookingId: booking.id,
                                          bookingData: booking.data() as Map<String, dynamic>,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: AppTheme.cardDecoration(context),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: booking['serviceType'] == 'Towing' ? AppTheme.towingOrange.withOpacity(0.1) : AppTheme.householdBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        booking['serviceType'] == 'Towing' ? Icons.car_repair : Icons.cleaning_services,
                                        color: booking['serviceType'] == 'Towing' ? AppTheme.towingOrange : AppTheme.householdBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            booking['serviceType'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            booking['address'],
                                            style: TextStyle(
                                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '₱${(booking['estimatedCost'] as num? ?? 0.0).toStringAsFixed(2)}',
                                            style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusBadge(status: booking['status']),
                                  ],
                                ),
                                if (isTrackable) ...[
                                  const SizedBox(height: 16),
                                  Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryBlue,
                                        side: const BorderSide(color: AppTheme.primaryBlue),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        if (status == 'converted_to_task') {
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
                                            }
                                          });
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CustomerTrackingScreen(
                                                bookingId: booking.id,
                                                bookingData: booking.data() as Map<String, dynamic>,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.location_on, size: 18),
                                      label: const Text('Track Provider', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
