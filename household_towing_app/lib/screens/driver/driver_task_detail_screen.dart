import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/task_model.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../chat/chat_screen.dart';
import '../../services/driver_tracking_service.dart';
import 'signature_capture_screen.dart';
import 'package:flutter/services.dart';
import '../../utils/map_utils.dart';
import 'driver_tracking_screen.dart';
import '../provider/transaction_completion_screen.dart';
import '../../services/task_service.dart';
import '../../widgets/asset_selection_dialog.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class DriverTaskDetailScreen extends StatefulWidget {
  final Task task;

  const DriverTaskDetailScreen({super.key, required this.task});

  @override
  State<DriverTaskDetailScreen> createState() => _DriverTaskDetailScreenState();
}

class _DriverTaskDetailScreenState extends State<DriverTaskDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Task _task;
  bool _isLoading = false;

  final TaskService _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  void _showAssetAssignment() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final providerName = 'Provider'; // The dialog just needs a string, doesn't matter much for driver

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AssetSelectionDialog(
        providerId: _task.assignedProviderId ?? '',
        providerName: providerName,
        preselectedTask: _task,
        isEmployeeContext: true,
      ),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assets updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload task to reflect new assets
        final doc = await _firestore.collection('tasks').doc(_task.id).get();
        if (doc.exists && mounted) {
          setState(() {
            _task = Task.fromFirestore(doc);
          });
        }
      }
    }
  }

  Future<void> _updateStatus(TaskStatus newStatus) async {
    if (newStatus == TaskStatus.completed) {
      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionCompletionScreen(
            taskId: _task.id,
            bookingId: _task.bookingId ?? _task.id,
            customerId: _task.customerId,
            providerId: _task.assignedProviderId ?? '',
            serviceType: _task.serviceType,
            startLatitude: _task.latitude,
            startLongitude: _task.longitude,
            endLatitude: _task.latitude, // Will be overridden or recalculated in billing
            endLongitude: _task.longitude,
          ),
        ),
      );
      
      if (success == true) {
        // The billing screen handles the status update to 'completed'
        setState(() {
          _task = _task.copyWith(status: TaskStatus.completed);
        });
        DriverTrackingService().stopTracking();
        return;
      }
      
      // Cancelled billing
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('tasks').doc(_task.id).update({
        'status': newStatus.name,
      }).timeout(const Duration(seconds: 5));
      setState(() {
        _task = _task.copyWith(status: newStatus);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${newStatus.name.toUpperCase()}')),
        );
      }
      
      // Handle live tracking based on status
      final trackingId = FirebaseAuth.instance.currentUser?.uid ?? _task.assignedDriverId ?? '';
      if (newStatus == TaskStatus.inProgress) { // Assuming 'En Route' or 'In Progress' should track
        DriverTrackingService().startTracking(trackingId, _task.id);
      } else if (newStatus == TaskStatus.completed || newStatus == TaskStatus.cancelled) {
        DriverTrackingService().stopTracking();
      }
    } on TimeoutException {
      setState(() {
        _task = _task.copyWith(status: newStatus);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved offline. Will sync when connection is restored.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      final trackingId = FirebaseAuth.instance.currentUser?.uid ?? _task.assignedDriverId ?? '';
      if (newStatus == TaskStatus.inProgress) {
        DriverTrackingService().startTracking(trackingId, _task.id);
      } else if (newStatus == TaskStatus.completed || newStatus == TaskStatus.cancelled) {
        DriverTrackingService().stopTracking();
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains('unavailable') || e.toString().toLowerCase().contains('network') || e.toString().toLowerCase().contains('offline')) {
        setState(() {
          _task = _task.copyWith(status: newStatus);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved offline. Will sync when connection is restored.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        if (newStatus == TaskStatus.inProgress) {
          DriverTrackingService().startTracking(_task.assignedDriverId ?? '', _task.id);
        } else if (newStatus == TaskStatus.completed || newStatus == TaskStatus.cancelled) {
          DriverTrackingService().stopTracking();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(isDark),
                      const SizedBox(height: 20),
                      _buildCustomerCard(isDark),
                    ],
                  ),
                ),
              ),
              _buildBottomActionPanel(isDark),
            ],
          ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Job #${_task.id.substring(0, 6).toUpperCase()}',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _task.status.name.toUpperCase(),
                  style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _task.serviceType,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textSlateDark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _task.location,
                      style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : AppTheme.textSlateMedium),
                    ),
                    if (_task.landmarkDescription != null && _task.landmarkDescription!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Landmark: ${_task.landmarkDescription}',
                          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                DateFormat("EEEE, MMM d '•' h:mm a").format(_task.scheduledDate),
                style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : AppTheme.textSlateMedium),
              ),
            ],
          ),
          if (_task.status == TaskStatus.assigned || _task.status == TaskStatus.inProgress) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _showAssetAssignment,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Edit Assigned Equipment', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          if (_task.milestones.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Step',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSlateDark,
                  ),
                ),
                Text(
                  '${(_task.progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _task.milestones.firstWhere((m) => !m.isCompleted, orElse: () => _task.milestones.last).title,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _task.progress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textSlateDark,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(_task.customerId).get(),
            builder: (context, snapshot) {
              String customerName = 'Customer';
              if (snapshot.hasData && snapshot.data!.exists) {
                customerName = snapshot.data!.get('name') ?? 'Customer';
              }
              
              return Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                    child: Text(
                      customerName[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      customerName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryBlue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            bookingId: _task.id,
                            receiverId: _task.customerId,
                            receiverName: customerName,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _progressToNextStep() async {
    final nextMilestone = _task.milestones.firstWhere((m) => !m.isCompleted, orElse: () => _task.milestones.last);
    
    setState(() => _isLoading = true);
    try {
      if (!nextMilestone.isCompleted) {
        await _taskService.updateTaskMilestone(_task.id, nextMilestone.id, true);
        HapticFeedback.mediumImpact();
      }
      
      TaskStatus? newStatus;
      if (_task.status == TaskStatus.assigned) {
        newStatus = TaskStatus.inProgress;
      } else if (nextMilestone.id == _task.milestones.last.id && _task.status == TaskStatus.inProgress) {
        newStatus = TaskStatus.completed;
      }

      if (newStatus != null) {
        await _updateStatus(newStatus);
      } else {
        // Just refresh local state
        final doc = await _firestore.collection('tasks').doc(_task.id).get();
        if (doc.exists && mounted) {
          setState(() {
            _task = Task.fromFirestore(doc);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update step: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBottomActionPanel(bool isDark) {
    if (_task.status == TaskStatus.completed || _task.status == TaskStatus.cancelled) {
      return const SizedBox.shrink(); // No actions for completed/cancelled
    }

    final nextMilestone = _task.milestones.firstWhere((m) => !m.isCompleted, orElse: () => _task.milestones.last);
    
    String actionText = 'Complete Step: ${nextMilestone.title}';
    Color btnColor = AppTheme.primaryBlue;

    if (_task.status == TaskStatus.assigned) {
      btnColor = Colors.orange;
    } else if (nextMilestone.isCompleted || (nextMilestone.id == _task.milestones.last.id && _task.status == TaskStatus.inProgress)) {
      actionText = 'Complete Job';
      btnColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_task.status == TaskStatus.inProgress) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DriverTrackingScreen(task: _task),
                    ),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text(
                  'Live Tracking',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  foregroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _progressToNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
