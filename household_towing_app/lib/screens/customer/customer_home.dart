import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../utils/app_theme.dart';
import '../../widgets/service_action_card.dart';
import '../../widgets/status_badge.dart';
import 'booking_screen.dart';
import 'customer_tracking_screen.dart';
import 'customer_service_tracking_screen.dart';
import 'towing_map_screen.dart';

import 'customer_settings_screen.dart';
import 'customer_notifications_screen.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/customer_drawer.dart';
import '../../services/booking_service.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String _userName = '';
  final PageController _pageController = PageController();
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;

  final List<Map<String, dynamic>> _carouselItems = [
    {
      'subtitle': 'CURRENT STATUS',
      'title': 'Ready for service',
      'colors': [const Color(0xFF7061FA), const Color(0xFF4B3CFA)],
    },
    {
      'subtitle': 'TOWING',
      'title': '24/7 Emergency Towing',
      'colors': [const Color(0xFFF97316), const Color(0xFFEA580C)],
    },
    {
      'subtitle': 'HOUSEHOLD',
      'title': 'Expert Cleaning Services',
      'colors': [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _cleanupBookings();
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        int nextIndex = (_currentCarouselIndex + 1) % _carouselItems.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _cleanupBookings() {
    BookingService().cleanupExpiredBookings(timeoutMinutes: 15);
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
      drawer: const CustomerDrawer(),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu, size: 28),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateLight,
                              ),
                            ),
                            Text(
                              _userName.isEmpty ? 'User' : _userName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
                        boxShadow: isDark ? [] : [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                            .where('isRead', isEqualTo: false)
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                          
                          return Stack(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.notifications_outlined,
                                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CustomerNotificationsScreen()),
                                  );
                                },
                              ),
                              if (hasUnread)
                                Positioned(
                                  right: 12,
                                  top: 12,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 32),
                
                // Main Gradient Card Carousel
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentCarouselIndex = index);
                    },
                    itemCount: _carouselItems.length,
                    itemBuilder: (context, index) {
                      final item = _carouselItems[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: item['colors'],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: item['colors'][1].withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['subtitle'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: List.generate(_carouselItems.length, (dotIndex) => Container(
                                margin: const EdgeInsets.only(right: 8),
                                height: 8,
                                width: _currentCarouselIndex == dotIndex ? 32 : 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: _currentCarouselIndex == dotIndex ? 1.0 : 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              )),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                
                // Services Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('See All', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
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
                      return ShimmerLoading.cardPlaceholder(count: 2, isDark: isDark);
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
                                        color: booking['serviceType'] == 'Towing' ? AppTheme.towingOrange.withValues(alpha: 0.1) : AppTheme.householdBlue.withValues(alpha: 0.1),
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
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('tasks')
                                        .where('bookingId', isEqualTo: booking.id)
                                        .limit(1)
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
                                                backgroundColor: Colors.grey[200],
                                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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
