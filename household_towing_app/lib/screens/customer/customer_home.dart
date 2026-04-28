import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../widgets/service_action_card.dart';
import '../../widgets/status_badge.dart';
import 'booking_screen.dart';
import 'customer_tracking_screen.dart';
import 'request_service_screen.dart';
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
                
                // Banner / Prominent Action
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryBlue, Color(0xFF60A5FA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Need urgent help?',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Book a trusted provider now in Bacolod City.',
                        style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const RequestServiceScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.flash_on, size: 20),
                        label: const Text('Request Emergency', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
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
                        final isAccepted = booking['status'] == 'accepted';

                        return GestureDetector(
                          onTap: isAccepted
                              ? () {
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
                                            '₱${booking['estimatedCost']}',
                                            style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusBadge(status: booking['status']),
                                  ],
                                ),
                                if (isAccepted) ...[
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
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CustomerTrackingScreen(
                                              bookingId: booking.id,
                                              bookingData: booking.data() as Map<String, dynamic>,
                                            ),
                                          ),
                                        );
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
