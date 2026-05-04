import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/services/logging_service.dart';

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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Service Status'),
        backgroundColor: Colors.green,
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
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(task.status),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusBorderColor(task.status),
                    ),
                  ),
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
                              color: Colors.grey,
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Timeline
                _buildTimeline(task),
                const SizedBox(height: 24),

                // Service Details
                const Text(
                  'Service Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  icon: Icons.home_repair_service,
                  title: 'Service Type',
                  value: task.serviceType,
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  icon: Icons.location_on,
                  title: 'Location',
                  value: task.location,
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  icon: Icons.schedule,
                  title: 'Requested',
                  value: _formatDate(task.scheduledDate),
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  icon: Icons.priority_high,
                  title: 'Priority',
                  value: task.priority.toString().split('.').last,
                  color: _getPriorityColor(task.priority),
                ),
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

                // Provider Info (if assigned)
                if (task.assignedProviderId != null) ...[
                  const Text(
                    'Assigned Provider',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildProviderCard(task.assignedProviderId!),
                ],

                // Assigned Truck
                if (task.assignedTruckName != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Assigned Truck',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailCard(
                    icon: Icons.local_shipping,
                    title: 'Vehicle',
                    value: task.assignedTruckName!,
                    color: Colors.blueAccent,
                  ),
                ],

                // Assigned Personnel
                if (task.assignedPersonnelNames.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Assigned Team',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...task.assignedPersonnelNames.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildDetailCard(
                      icon: Icons.person_pin,
                      title: 'Personnel',
                      value: name,
                      color: Colors.teal,
                    ),
                  )),
                ],

                // Equipment & Tools
                if (task.assignedAssets.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Equipment & Tools',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailCard(
                    icon: Icons.handyman,
                    title: 'Resources',
                    value: '${task.assignedAssets.length} items assigned',
                    color: Colors.orange,
                  ),
                ],

                // Info Message
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.assignedProviderId == null
                              ? 'A provider will be assigned shortly. You\'ll receive a notification with their details.'
                              : 'Your provider is on the way. You can track their location once they start the service.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
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

  Widget _buildTimeline(Task task) {
    return Column(
      children: [
        _buildTimelineStep('Requested', true, Icons.check_circle, Colors.green),
        Container(
          width: 2,
          height: 20,
          color: task.status != TaskStatus.unassigned
              ? Colors.green
              : Colors.grey[300],
        ),
        _buildTimelineStep(
          'Assigned',
          task.assignedProviderId != null,
          Icons.person,
          task.assignedProviderId != null ? Colors.green : Colors.grey,
        ),
        Container(
          width: 2,
          height: 20,
          color:
              task.status == TaskStatus.inProgress ||
                  task.status == TaskStatus.completed
              ? Colors.green
              : Colors.grey[300],
        ),
        _buildTimelineStep(
          'In Progress',
          task.status == TaskStatus.inProgress ||
              task.status == TaskStatus.completed,
          Icons.directions_car,
          task.status == TaskStatus.inProgress ||
                  task.status == TaskStatus.completed
              ? Colors.green
              : Colors.grey,
        ),
        Container(
          width: 2,
          height: 20,
          color: task.status == TaskStatus.completed
              ? Colors.green
              : Colors.grey[300],
        ),
        _buildTimelineStep(
          'Completed',
          task.status == TaskStatus.completed,
          Icons.check_circle,
          task.status == TaskStatus.completed ? Colors.green : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildTimelineStep(
    String label,
    bool completed,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: TextStyle(
            fontWeight: completed ? FontWeight.bold : FontWeight.normal,
            color: completed ? Colors.black : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green,
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
                        Icon(Icons.star, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text('$rating', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 16),
                        Icon(Icons.phone, size: 16, color: Colors.green),
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
        return Colors.blue;
      case TaskStatus.assigned:
        return Colors.orange;
      case TaskStatus.inProgress:
        return Colors.purple;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }

  Color _getStatusBgColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.unassigned:
        return Colors.blue[50]!;
      case TaskStatus.assigned:
        return Colors.orange[50]!;
      case TaskStatus.inProgress:
        return Colors.purple[50]!;
      case TaskStatus.completed:
        return Colors.green[50]!;
      case TaskStatus.cancelled:
        return Colors.red[50]!;
    }
  }

  Color _getStatusBorderColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.unassigned:
        return Colors.blue[200]!;
      case TaskStatus.assigned:
        return Colors.orange[200]!;
      case TaskStatus.inProgress:
        return Colors.purple[200]!;
      case TaskStatus.completed:
        return Colors.green[200]!;
      case TaskStatus.cancelled:
        return Colors.red[200]!;
    }
  }

  Color _getStatusTextColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.unassigned:
        return Colors.blue[700]!;
      case TaskStatus.assigned:
        return Colors.orange[700]!;
      case TaskStatus.inProgress:
        return Colors.purple[700]!;
      case TaskStatus.completed:
        return Colors.green[700]!;
      case TaskStatus.cancelled:
        return Colors.red[700]!;
    }
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

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.blue;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.urgent:
        return Colors.red[900]!;
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
}
