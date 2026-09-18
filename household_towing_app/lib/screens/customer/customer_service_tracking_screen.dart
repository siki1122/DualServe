import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:household_towing_app/utils/app_theme.dart';

class CustomerServiceTrackingScreen extends StatefulWidget {
  final String taskId;

  const CustomerServiceTrackingScreen({super.key, required this.taskId});

  @override
  State<CustomerServiceTrackingScreen> createState() =>
      _CustomerServiceTrackingScreenState();
}

class _CustomerServiceTrackingScreenState
    extends State<CustomerServiceTrackingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Service Status', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('tasks').doc(widget.taskId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Task not found'));
          }

          final task = Task.fromFirestore(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Service Status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSlateMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(task.status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              task.status
                                  .toString()
                                  .split('.')
                                  .last
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getStatusMessage(task.status),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getStatusTextColor(task.status),
                        ),
                      ),
                      
                      // NEW: Progress Section for Customer
                      if (task.milestones.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Step: ${task.milestones.firstWhere((m) => !m.isCompleted, orElse: () => task.milestones.last).title}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _getStatusTextColor(task.status),
                              ),
                            ),
                            Text(
                              '${(task.progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _getStatusTextColor(task.status),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: task.progress,
                            minHeight: 10,
                            backgroundColor: _getStatusColor(task.status).withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(task.status)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),



                // Service Details
                const Text(
                  'Service Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark),
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  icon: Icons.home_repair_service,
                  title: 'Service Type',
                  value: task.serviceType,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  icon: Icons.location_on,
                  title: 'Location',
                  value: task.location,
                  color: AppTheme.statusCompletedText,
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  icon: Icons.schedule,
                  title: 'Requested',
                  value: _formatDate(task.scheduledDate),
                  color: AppTheme.towingOrange,
                ),
                const SizedBox(height: 12),

                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailCard(
                    icon: Icons.description,
                    title: 'Notes',
                    value: task.description!,
                    color: Colors.purple,
                  ),
                ],
                const SizedBox(height: 24),

                // Billing Details
                const Text(
                  'Payment Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.statusCompletedText.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.payments, color: AppTheme.statusCompletedText, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.status == TaskStatus.completed ? 'Final Cost' : 'Estimated Cost',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                task.status == TaskStatus.completed ? 'Paid' : 'To be paid upon completion',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '₱${(task.status == TaskStatus.completed ? (task.finalCost ?? task.estimatedCost ?? 0.0) : (task.estimatedCost ?? 0.0)).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.statusCompletedText),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // Assigned Assets & Team
                if (task.assignedProviderId != null || task.assignedTruckName != null || task.assignedPersonnelNames.isNotEmpty || task.assignedAssets.isNotEmpty) ...[
                  const Text(
                    'Assigned Team & Assets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  if (task.assignedProviderId != null) ...[
                    // We must wrap _buildProviderCard in a card decoration since we removed it earlier
                    Container(
                      decoration: AppTheme.cardDecoration(context),
                      child: _buildProviderCard(task.assignedProviderId!),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (task.assignedTruckName != null) ...[
                    _buildDetailCard(
                      icon: Icons.local_shipping,
                      title: 'Service Vehicle',
                      value: task.assignedTruckName!,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (task.assignedPersonnelNames.isNotEmpty) ...[
                    _buildDetailCard(
                      icon: Icons.group,
                      title: 'Personnel',
                      value: task.assignedPersonnelNames.join(', '),
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (task.assignedAssets.isNotEmpty) ...[
                    _buildDetailCard(
                      icon: Icons.handyman,
                      title: 'Equipment & Tools',
                      value: '${task.assignedAssets.length} items requested',
                      color: AppTheme.towingOrange,
                    ),
                  ],
                ],

                // Info Message
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryBlue),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.assignedProviderId == null
                              ? 'A provider will be assigned shortly. You\'ll receive a notification with their details.'
                              : 'Your provider is on the way. You can track their location once they start the service.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }



  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(String providerId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final providerData = snapshot.data!.data() as Map<String, dynamic>?;
        final name = providerData?['name'] ?? 'Unknown Provider';
        final phone = providerData?['phone'] ?? 'N/A';
        final rating = providerData?['rating'] ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.statusCompletedText,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: AppTheme.towingOrange),
                        const SizedBox(width: 4),
                        Text('$rating', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 16),
                        Icon(Icons.phone, size: 16, color: AppTheme.statusCompletedText),
                        const SizedBox(width: 4),
                        Text(phone, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.unassigned:
        return AppTheme.statusPendingText;
      case TaskStatus.assigned:
        return AppTheme.statusAcceptedText;
      case TaskStatus.inProgress:
        return AppTheme.statusInProgressText;
      case TaskStatus.completed:
        return AppTheme.statusCompletedText;
      case TaskStatus.cancelled:
        return AppTheme.statusCancelledText;
    }
  }

  Color _getStatusBgColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.unassigned:
        return AppTheme.statusPendingBg;
      case TaskStatus.assigned:
        return AppTheme.statusAcceptedBg;
      case TaskStatus.inProgress:
        return AppTheme.statusInProgressBg;
      case TaskStatus.completed:
        return AppTheme.statusCompletedBg;
      case TaskStatus.cancelled:
        return AppTheme.statusCancelledBg;
    }
  }

  Color _getStatusBorderColor(TaskStatus status) {
    return Colors.transparent; // Simplified design doesn't use borders here
  }

  Color _getStatusTextColor(TaskStatus status) {
    return _getStatusColor(status);
  }

  String _getStatusMessage(TaskStatus status) {
    switch (status) {
      case TaskStatus.unassigned:
        return 'Finding a provider...';
      case TaskStatus.assigned:
        return 'Provider has accepted';
      case TaskStatus.inProgress:
        return 'Service in progress';
      case TaskStatus.completed:
        return 'Service completed ✓';
      case TaskStatus.cancelled:
        return 'Service cancelled';
    }
  }



  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    String dateStr;
    if (dateOnly == today) {
      dateStr = 'Today';
    } else if (dateOnly == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${date.month}/${date.day}/${date.year}';
    }

    return '$dateStr at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeOnly(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
