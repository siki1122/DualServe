import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import '../../widgets/success_dialog.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
import '../chat/chat_screen.dart';
import '../../utils/map_utils.dart';

class ProviderTasksScreen extends StatefulWidget {
  const ProviderTasksScreen({super.key});

  @override
  State<ProviderTasksScreen> createState() => _ProviderTasksScreenState();
}

class _ProviderTasksScreenState extends State<ProviderTasksScreen> {
  final TaskService _taskService = TaskService();
  final StorageService _storageService = StorageService();
  late String _providerId;
  TaskStatus _filterStatus = TaskStatus.assigned;
  bool _isUploading = false;
  final Map<TaskStatus, Stream<List<Task>>> _taskStreams = {};

  @override
  void initState() {
    super.initState();
    _providerId = FirebaseAuth.instance.currentUser!.uid;
    
    // Pre-initialize streams to prevent flickering on tab switch
    _taskStreams[TaskStatus.assigned] = _taskService.getProviderTasksByStatus(_providerId, TaskStatus.assigned);
    _taskStreams[TaskStatus.inProgress] = _taskService.getProviderTasksByStatus(_providerId, TaskStatus.inProgress);
    _taskStreams[TaskStatus.completed] = _taskService.getProviderTasksByStatus(_providerId, TaskStatus.completed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: Text(
          'My Tasks',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Assigned', TaskStatus.assigned),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Progress', TaskStatus.inProgress),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed', TaskStatus.completed),
                ],
              ),
            ),
          ),
          // Task list
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _taskStreams[_filterStatus]!,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final tasks = snapshot.data ?? [];

                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_filterStatus.toString().split('.').last} tasks',
                          style: const TextStyle(
                            color: AppTheme.textSlateMedium,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, TaskStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? (isDark ? AppTheme.towingOrange : AppTheme.textSlateDark) 
            : (isDark ? AppTheme.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
              ? (isDark ? AppTheme.towingOrange : AppTheme.textSlateDark) 
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
          ),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTaskDetail(task),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
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
                        color: _getStatusColor(task.status, isDark)[0],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        task.status.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(task.status, isDark)[1],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                // Schedule and priority
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(task.scheduledDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityBgColor(task.priority, isDark),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.priority.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          color: _getPriorityTextColor(task.priority, isDark),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    if (task.status == TaskStatus.inProgress)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton.icon(
                            onPressed: () => MapUtils.openMap(task.location),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.directions, size: 18),
                            label: const Text('Navigate', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    if (task.status == TaskStatus.assigned || task.status == TaskStatus.inProgress)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    bookingId: task.id,
                                    receiverId: task.customerId,
                                    receiverName: 'Customer',
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              side: const BorderSide(color: AppTheme.primaryBlue),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    if (task.status == TaskStatus.assigned)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateStatus(task, TaskStatus.inProgress),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.towingOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Start Task', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    else if (task.status == TaskStatus.inProgress)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateStatus(task, TaskStatus.completed),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Complete Task', style: TextStyle(fontWeight: FontWeight.bold)),
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
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 16),
              _buildDetailRow('Service Type', task.serviceType),
              _buildDetailRow('Location', task.location),
              _buildDetailRow('Scheduled', _formatDate(task.scheduledDate)),
              _buildDetailRow('Priority', task.priority.toString().split('.').last.toUpperCase()),
              _buildDetailRow('Status', task.status.toString().split('.').last.toUpperCase()),
              if (task.description != null && task.description!.isNotEmpty)
                _buildDetailRow('Notes', task.description!),
              if (task.estimatedDurationMinutes != null)
                _buildDetailRow(
                  'Est. Duration',
                  '${task.estimatedDurationMinutes} minutes',
                ),
              if (task.completedImageUrl != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Completion Proof',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSlateMedium,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    task.completedImageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(Task task, TaskStatus newStatus) async {
    if (newStatus == TaskStatus.completed) {
      _showCompletionDialog(task);
      return;
    }

    try {
      await _taskService.updateTaskStatus(task.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task ${newStatus.toString().split('.').last}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCompletionDialog(Task task) {
    showDialog(
      context: context,
      barrierDismissible: !_isUploading,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Complete Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please upload a photo of the completed service for verification.'),
              const SizedBox(height: 20),
              if (_isUploading)
                const CircularProgressIndicator()
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildUploadOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () => _handleImageUpload(task, ImageSource.camera, setDialogState),
                    ),
                    _buildUploadOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () => _handleImageUpload(task, ImageSource.gallery, setDialogState),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            if (!_isUploading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.primaryBlue),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _handleImageUpload(Task task, ImageSource source, Function setDialogState) async {
    final image = await _storageService.pickImage(source);
    if (image == null) return;

    setDialogState(() => _isUploading = true);

    try {
      final imageUrl = await _storageService.uploadServiceImage(task.id, image);
      if (imageUrl != null) {
        await _taskService.updateTaskCompletion(task.id, imageUrl);
        if (mounted) {
          Navigator.pop(context); // Close upload dialog
          SuccessDialog.show(
            context,
            title: 'Job Well Done!',
            message: 'You have successfully completed this task and uploaded the proof.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing task: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setDialogState(() => _isUploading = false);
    }
  }

  List<Color> _getStatusColor(TaskStatus status, bool isDark) {
    switch (status) {
      case TaskStatus.assigned:
        return [AppTheme.primaryBlue.withOpacity(0.15), AppTheme.primaryBlue];
      case TaskStatus.inProgress:
        return [AppTheme.towingOrange.withOpacity(0.15), AppTheme.towingOrange];
      case TaskStatus.completed:
        return [
          isDark ? Colors.green.withOpacity(0.2) : AppTheme.statusCompletedBg, 
          isDark ? Colors.greenAccent : AppTheme.statusCompletedText
        ];
      case TaskStatus.cancelled:
        return [Colors.red.withOpacity(0.15), Colors.red.shade400];
      default:
        return [
          isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, 
          isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium
        ];
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}/${date.day} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
