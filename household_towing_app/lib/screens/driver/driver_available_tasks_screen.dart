import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_task_card.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class DriverAvailableTasksScreen extends StatefulWidget {
  const DriverAvailableTasksScreen({super.key});

  @override
  State<DriverAvailableTasksScreen> createState() => _DriverAvailableTasksScreenState();
}

class _DriverAvailableTasksScreenState extends State<DriverAvailableTasksScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _driverId;

  @override
  void initState() {
    super.initState();
    _driverId = FirebaseAuth.instance.currentUser!.uid;
  }

  Future<void> _claimTask(Task task) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final driverName = userProvider.userProfile?['name'] ?? 'Driver';

      final taskRef = _firestore.collection('tasks').doc(task.id);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(taskRef);
        if (!snapshot.exists) {
          throw Exception('Task no longer exists.');
        }

        final assignedDriver = snapshot.data()?['assignedDriverId'];
        if (assignedDriver != null && assignedDriver.toString().isNotEmpty) {
          throw Exception('Task already claimed.');
        }

        transaction.update(taskRef, {
          'assignedDriverId': _driverId,
        });

        if (task.bookingId != null && task.bookingId!.isNotEmpty) {
          final bookingRef = _firestore.collection('bookings').doc(task.bookingId);
          transaction.update(bookingRef, {
            'assignedDriverId': _driverId,
            'assignedPersonnelNames': FieldValue.arrayUnion([driverName]),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task claimed successfully!'), backgroundColor: AppTheme.statusCompletedText),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Task already claimed')) {
          errorMsg = 'This task was already claimed by someone else.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: AppTheme.towingOrange),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to claim task: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final providerId = userProvider.driverProfile?['providerId'];

    if (providerId == null || providerId.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFF8FAFC),
        body: Center(
          child: Text('No provider profile found.', style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Job Pool', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        foregroundColor: isDark ? Colors.white : AppTheme.textSlateDark,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('tasks')
            .where('assignedProviderId', isEqualTo: providerId)
            .where('status', isEqualTo: 'assigned') // Only assigned (not in progress/completed)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading tasks:\n${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(isDark);
          }

          final allTasks = snapshot.data!.docs.map((doc) => Task.fromFirestore(doc)).toList();
          
          // Filter out tasks that already have a driver locally
          final availableTasks = allTasks.where((t) => t.assignedDriverId == null || t.assignedDriverId!.isEmpty).toList();

          if (availableTasks.isEmpty) {
            return _buildEmptyState(isDark);
          }

          availableTasks.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: availableTasks.length,
            itemBuilder: (context, index) {
              final task = availableTasks[index];
              return AppTaskCard(
                task: task,
                actionLabel: 'Claim Job',
                onActionPressed: () => _claimTask(task),
                onTap: () {}, // Optional details view
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 80, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            'No Jobs Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textSlateDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New jobs from your provider will appear here.',
            style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
          ),
        ],
      ),
    );
  }
}
