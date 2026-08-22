import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../utils/global_state.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/customer/customer_service_tracking_screen.dart';
import '../models/task_model.dart';

class GlobalMessageOverlay extends StatefulWidget {
  final Widget child;

  const GlobalMessageOverlay({super.key, required this.child});

  @override
  State<GlobalMessageOverlay> createState() => _GlobalMessageOverlayState();
}

class _GlobalMessageOverlayState extends State<GlobalMessageOverlay> {
  StreamSubscription? _subscription;
  StreamSubscription? _taskSubscription;
  String? _currentUserId;
  final DateTime _startupTime = DateTime.now();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _currentUserId = user.uid;

    _subscription = FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        // Only trigger for messages received after the app starts
        .where('timestamp', isGreaterThan: Timestamp.fromDate(_startupTime))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final bookingId = data['bookingId'] as String?;
          final senderId = data['senderId'] as String?;
          final text = data['text'] as String? ?? 'Sent a message';
          
          // Don't show if the user is already actively chatting with them
          if (bookingId != null && GlobalState.activeChatBookingId.value != bookingId) {
            _showNotification(bookingId, senderId ?? 'User', text);
          }
        }
      }
    });

    _taskSubscription = FirebaseFirestore.instance
        .collection('tasks')
        .where('customerId', isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>;
          final statusStr = data['status'] as String?;
          final oldData = change.oldIndex != -1 ? snapshot.docs[change.oldIndex].data() as Map<String, dynamic>? : null;
          final oldStatus = oldData?['status'] as String?;
          
          if (statusStr != null && statusStr != oldStatus) {
            // Check if status changed
            final task = Task.fromFirestore(change.doc);
            if (task.status == TaskStatus.inProgress || task.status == TaskStatus.completed) {
               _showTaskNotification(task.id, task.status);
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _taskSubscription?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showTaskNotification(String taskId, TaskStatus status) async {
    HapticFeedback.lightImpact();

    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }

    String title = 'Status Update';
    String body = 'Your task status is now ${status.name}';
    if (status == TaskStatus.inProgress) {
      title = 'Driver In Progress';
      body = 'Your service provider is working on your request.';
    } else if (status == TaskStatus.completed) {
      title = 'Task Completed';
      body = 'Your service has been completed.';
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: () {
                _overlayEntry?.remove();
                _overlayEntry = null;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerServiceTrackingScreen(taskId: taskId),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
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
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 4), () {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  void _showNotification(String bookingId, String senderId, String text) async {
    HapticFeedback.lightImpact();

    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: () {
                _overlayEntry?.remove();
                _overlayEntry = null;
                // Navigate to chat
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      bookingId: bookingId,
                      receiverId: senderId, // we need senderId as receiver for reply
                      receiverName: 'User', // We might not have the name, but this is a fallback
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.surfaceDark 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white.withValues(alpha: 0.1) 
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'New Message',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : AppTheme.textSlateDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? AppTheme.textDarkSecondary 
                                  : AppTheme.textSlateMedium,
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
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (_overlayEntry != null && mounted) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
