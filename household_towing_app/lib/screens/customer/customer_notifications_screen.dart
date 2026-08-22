import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../../services/in_app_notification_service.dart';
import '../chat/chat_screen.dart';
import 'customer_tracking_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() => _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState extends State<CustomerNotificationsScreen> {
  final _userId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoadingRoute = false;

  Future<void> _handleNotificationClick(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    
    // Mark as read immediately
    if (data['isRead'] == false) {
      await InAppNotificationService().markAsRead(doc.id);
    }

    final type = data['type'] as String?;
    final actionData = data['actionData'] as Map<String, dynamic>?;

    if (type == null || actionData == null || !mounted) return;

    if (type == 'message') {
      final bookingId = actionData['bookingId'];
      final receiverId = actionData['senderId'];
      final receiverName = actionData['senderName'] ?? 'Provider';

      if (bookingId != null && receiverId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              bookingId: bookingId,
              receiverId: receiverId,
              receiverName: receiverName,
            ),
          ),
        );
      }
    } else if (type == 'booking_update') {
      final bookingId = actionData['bookingId'];
      
      if (bookingId != null) {
        setState(() => _isLoadingRoute = true);
        
        try {
          // Fetch booking data required for tracking screen
          final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
          
          if (bookingDoc.exists && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerTrackingScreen(
                  bookingId: bookingId,
                  bookingData: bookingDoc.data() as Map<String, dynamic>,
                ),
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Booking no longer exists.'), backgroundColor: Colors.red),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading booking: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoadingRoute = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const Scaffold(body: Center(child: Text('Not logged in')));
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
        actions: [
          TextButton(
            onPressed: () => InAppNotificationService().markAllAsRead(_userId!),
            child: const Text('Mark all read', style: TextStyle(color: AppTheme.primaryBlue)),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: _userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error loading notifications: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }

              final notifications = snapshot.data?.docs.toList() ?? [];
              
              // Sort manually to avoid requiring a composite index
              notifications.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['timestamp'] as Timestamp?;
                final bTime = bData['timestamp'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime); // descending
              });

              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 80, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final doc = notifications[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isRead = data['isRead'] ?? true;
                  final type = data['type'] as String?;
                  final timestamp = data['timestamp'] as Timestamp?;
                  
                  IconData iconData = Icons.notifications_active;
                  Color iconColor = AppTheme.primaryBlue;
                  
                  if (type == 'message') {
                    iconData = Icons.chat_bubble_outline;
                    iconColor = AppTheme.householdBlue;
                  } else if (type == 'booking_update') {
                    iconData = Icons.map_outlined;
                    iconColor = AppTheme.towingOrange;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isRead ? null : Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _handleNotificationClick(doc),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(iconData, color: iconColor, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['title'] ?? 'Notification',
                                            style: TextStyle(
                                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                              fontSize: 16,
                                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      data['message'] ?? '',
                                      style: TextStyle(
                                        color: isRead 
                                            ? (isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)
                                            : (isDark ? Colors.white70 : AppTheme.textSlateDark),
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      timestamp != null ? timeago.format(timestamp.toDate()) : 'Just now',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white30 : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          
          if (_isLoadingRoute)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
