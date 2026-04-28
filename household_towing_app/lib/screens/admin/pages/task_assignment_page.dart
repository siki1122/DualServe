import 'package:flutter/material.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'create_task_page.dart';

class TaskAssignmentScreen extends StatefulWidget {
  const TaskAssignmentScreen({super.key});

  @override
  State<TaskAssignmentScreen> createState() => _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends State<TaskAssignmentScreen> {
  final TaskService _taskService = TaskService();
  Task? _selectedTask;
  String? _selectedProviderId;
  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Task Management', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
          bottom: const TabBar(
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.textSlateMedium,
            indicatorColor: AppTheme.primaryBlue,
            tabs: [
              Tab(text: 'Unassigned'),
              Tab(text: 'Completed'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
                  ).then((_) => setState(() {}));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.towingOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Task'),
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildUnassignedTab(),
            _buildCompletedTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnassignedTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _taskService.getUnassignedTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) {
                  return _buildEmptyState('No unassigned tasks');
                }

                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final isSelected = _selectedTask?.id == task.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryBlue.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade200,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () {
                          setState(() {
                            _selectedTask = task;
                            _selectedProviderId = null;
                          });
                        },
                        leading: _buildPriorityBadge(task.priority),
                        title: Text(
                          task.serviceType,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark, fontSize: 16),
                        ),
                        subtitle: _buildTaskSubtitle(task),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppTheme.primaryBlue)
                            : const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textSlateMedium),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_selectedTask != null) ...[
            const SizedBox(height: 16),
            _buildAssignmentPanel(),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('No completed tasks found');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final imageUrl = data['completedImageUrl'] as String?;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(data['serviceType'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Location: ${data['location'] ?? ''}'),
                    trailing: const Icon(Icons.verified, color: Colors.green),
                  ),
                  if (imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Completed: ${_formatTimestamp(data['completedAt'])}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium),
                        ),
                        TextButton(
                          onPressed: () {}, 
                          child: const Text('View Details'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return _formatDate(timestamp.toDate());
    }
    return 'Unknown';
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getPriorityColor(priority).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getPriorityColor(priority).withOpacity(0.5)),
      ),
      child: Center(
        child: Text(
          priority.toString().split('.').last[0].toUpperCase(),
          style: TextStyle(color: _getPriorityColor(priority), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildTaskSubtitle(Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSlateMedium),
            const SizedBox(width: 4),
            Expanded(child: Text(task.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSlateMedium, fontSize: 13))),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.schedule, size: 14, color: AppTheme.textSlateMedium),
            const SizedBox(width: 4),
            Text(_formatDate(task.scheduledDate), style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium)),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignmentPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assign Task to Provider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
          const SizedBox(height: 16),
          _buildProviderSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isAssigning ? null : _assignTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.towingOrange, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: _isAssigning 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) 
                : const Text('Assign Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Select a provider...', style: TextStyle(color: AppTheme.textSlateMedium)),
          ),
          value: _selectedProviderId,
          icon: const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.expand_more, color: AppTheme.textSlateMedium),
          ),
          onChanged: (String? value) {
            setState(() => _selectedProviderId = value);
          },
          items: [
            DropdownMenuItem(
              value: 'provider_1',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.primaryBlue,
                      child: Text('JD', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('John Doe', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
                          Text(
                            '⭐ 4.8 (152 ratings)',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSlateMedium),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignTask() async {
    if (_selectedTask == null || _selectedProviderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a provider')),
      );
      return;
    }

    setState(() => _isAssigning = true);

    try {
      await _taskService.assignTask(_selectedTask!.id, _selectedProviderId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned successfully!'), backgroundColor: Colors.green),
        );
        setState(() {
          _selectedTask = null;
          _selectedProviderId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return AppTheme.primaryBlue;
      case TaskPriority.medium:
        return AppTheme.towingOrange;
      case TaskPriority.high:
        return Colors.red.shade600;
      case TaskPriority.urgent:
        return Colors.red.shade900;
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
