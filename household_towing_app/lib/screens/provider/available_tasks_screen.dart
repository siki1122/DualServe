import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';

class AvailableTasksScreen extends StatefulWidget {
  const AvailableTasksScreen({super.key});

  @override
  State<AvailableTasksScreen> createState() => _AvailableTasksScreenState();
}

class _AvailableTasksScreenState extends State<AvailableTasksScreen> {
  final TaskService _taskService = TaskService();
  late String _providerId;
  bool _isAccepting = false;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _providerId = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Available Tasks',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.towingOrange,
        onRefresh: () async {
          setState(() {
            _refreshKey++;
          });
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: StreamBuilder<List<Task>>(
          key: ValueKey(_refreshKey),
          stream: _taskService.getUnassignedTasks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tasks = snapshot.data ?? [];

            if (tasks.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No available tasks right now',
                            style: TextStyle(
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back soon for new requests',
                            style: TextStyle(
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskCard(task);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTaskDetail(task),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with priority
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.serviceType,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  task.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityBgColor(task.priority, isDark),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        task.priority.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          color: _getPriorityTextColor(task.priority, isDark),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Details row
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatTime(task.scheduledDate),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (task.estimatedDurationMinutes != null)
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 16, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          const SizedBox(width: 6),
                          Text(
                            '${task.estimatedDurationMinutes} min',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showTaskDetail(task),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                          foregroundColor: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAccepting ? null : () => _acceptTask(task),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.towingOrange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isAccepting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Accept Task', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTaskDetail(Task task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Task Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSlateDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSlateMedium),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow('Service Type', task.serviceType),
                  _buildDetailRow('Location', task.location),
                  _buildDetailRow('Scheduled', _formatDateTime(task.scheduledDate)),
                  _buildDetailRow(
                    'Priority',
                    task.priority.toString().split('.').last.toUpperCase(),
                  ),
                  if (task.estimatedDurationMinutes != null)
                    _buildDetailRow(
                      'Est. Duration',
                      '${task.estimatedDurationMinutes} minutes',
                    ),
                  if (task.estimatedCost != null)
                    _buildDetailRow(
                      'Est. Cost',
                      '₱${task.estimatedCost}',
                    ),
                  if (task.description != null && task.description!.isNotEmpty)
                    _buildDetailRow('Details', task.description!),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isAccepting ? null : () => _acceptTask(task),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.towingOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'Accept Task',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSlateMedium,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textSlateDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptTask(Task task) async {
    setState(() => _isAccepting = true);

    try {
      // Assign task to this provider
      await _taskService.assignTask(task.id, _providerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Task accepted! It\'s now in your "My Tasks"'),
            backgroundColor: Colors.green,
          ),
        );

        // Close bottom sheet if open
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  Color _getPriorityBgColor(TaskPriority priority, bool isDark) {
    switch (priority) {
      case TaskPriority.low:
        return isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50;
      case TaskPriority.medium:
        return isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50;
      case TaskPriority.high:
        return isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50;
      case TaskPriority.urgent:
        return isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade100;
    }
  }

  Color _getPriorityTextColor(TaskPriority priority, bool isDark) {
    switch (priority) {
      case TaskPriority.low:
        return isDark ? Colors.blueAccent : Colors.blue.shade700;
      case TaskPriority.medium:
        return isDark ? Colors.orangeAccent : Colors.orange.shade700;
      case TaskPriority.high:
        return isDark ? Colors.redAccent : Colors.red.shade700;
      case TaskPriority.urgent:
        return isDark ? Colors.red.shade300 : Colors.red.shade900;
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    String dateStr;
    if (dateOnly == today) {
      dateStr = 'Today';
    } else if (dateOnly == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${date.month}/${date.day}';
    }

    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $time';
  }
}
