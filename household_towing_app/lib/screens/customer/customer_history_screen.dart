import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../services/review_service.dart';
import '../../models/review_model.dart';
import '../../widgets/shimmer_loading.dart';
import '../chat/chat_screen.dart';
import '../../models/booking_model.dart';
import 'customer_booking_details_screen.dart';
import '../../widgets/customer_drawer.dart';

class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({super.key});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Completed', 'Pending', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const CustomerDrawer(),
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: isDark ? [] : [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateLight),
                        prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateLight),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: isDark ? [] : [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.tune, color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark),
                    onPressed: () {},
                  ),
                )
              ],
            ),
          ),

          // Filter Chips
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                    backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                    selectedColor: AppTheme.primaryBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('customerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var docs = snapshot.data!.docs.toList();
                
                // Sort in memory to avoid missing index errors and put newest first
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final dateA = (dataA['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  final dateB = (dataB['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  return dateB.compareTo(dateA);
                });
                if (_selectedFilter != 'All') {
                  docs = docs.where((doc) {
                    final status = (doc.data() as Map<String, dynamic>)['status'] as String? ?? '';
                    if (_selectedFilter == 'Completed') return status == 'completed';
                    if (_selectedFilter == 'Pending') return status == 'pending' || status == 'accepted' || status == 'converted_to_task';
                    if (_selectedFilter == 'Cancelled') return status == 'cancelled' || status == 'rejected';
                    return true;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final booking = docs[index];
                    final data = booking.data() as Map<String, dynamic>;
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerBookingDetailsScreen(
                              booking: Booking.fromFirestore(booking),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: AppTheme.cardDecoration(context),
                        child: Column(
                          children: [
                            Row(
                          children: [
                            // Circular Icon matching 'IMG' in mockup
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                data['serviceType'] == 'Towing' ? Icons.car_repair : Icons.cleaning_services,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['serviceType'] ?? 'Unknown Service',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['address'] ?? '',
                                    style: TextStyle(
                                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Right Side: Status label
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(data['status']).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _capitalize(data['status']),
                                style: TextStyle(
                                  color: _getStatusColor(data['status']),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
                        const SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cost: ₱${(data['finalCost'] as num? ?? data['estimatedCost'] as num? ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              Row(
                                children: [
                                  if (data['assignedProviderId'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: OutlinedButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatScreen(
                                              bookingId: booking.id,
                                              receiverId: data['assignedProviderId'] as String,
                                              receiverName: 'Provider',
                                            ),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.primaryBlue,
                                          side: const BorderSide(color: AppTheme.primaryBlue),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(Icons.chat_bubble_outline, size: 14),
                                        label: const Text('Chat', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  if (!(data['isReviewed'] ?? false) && data['assignedProviderId'] != null && data['status'] == 'completed')
                                    ElevatedButton(
                                      onPressed: () {
                                        // Simple navigation to details to rate, or implement a quick dialog if preferred.
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CustomerBookingDetailsScreen(
                                              booking: Booking.fromFirestore(booking),
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Rate', style: TextStyle(fontSize: 12)),
                                    )
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No matching services.',
            style: TextStyle(color: AppTheme.textSlateMedium, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'pending': 
      case 'converted_to_task':
        return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'cancelled': 
      case 'rejected':
        return Colors.red;
      default: return AppTheme.textSlateMedium;
    }
  }

  String _capitalize(String? s) {
    if (s == null || s.isEmpty) return '';
    final formatted = s.replaceAll('_', ' ');
    return formatted[0].toUpperCase() + formatted.substring(1);
  }
}

