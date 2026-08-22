import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

/// A production-level task card component following senior engineering principles.
/// 
/// Features:
/// - Responsive design using [LayoutBuilder] and [Flexible].
/// - Semantic labels for accessibility.
/// - Themed styling using [AppTheme].
/// - Integrated loading (skeleton) state.
/// - Distinctive priority and status indicators.
class AppTaskCard extends StatelessWidget {
  final Task? task;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onMessagePressed;
  final VoidCallback? onActionPressed;
  final String? actionLabel;
  final Function(TaskMilestone)? onMilestoneToggle;

  const AppTaskCard({
    super.key,
    this.task,
    this.isLoading = false,
    this.onTap,
    this.onMessagePressed,
    this.onActionPressed,
    this.actionLabel,
    this.onMilestoneToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || task == null) {
      return _buildSkeleton(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(task!.status);

    return Semantics(
      label: 'Task card for ${task!.serviceType} at ${task!.location}',
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: AppTheme.cardDecoration(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          task!.serviceType.toLowerCase().contains('tow') 
                              ? Icons.car_repair 
                              : Icons.cleaning_services,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task!.serviceType,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task!.location,
                              style: TextStyle(
                                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          task!.status.name.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined, size: 14, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                      const SizedBox(width: 6),
                      Text(
                        _formatDateTime(task!.scheduledDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateMedium,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Progress Bar & Milestones (Only show for In Progress or Completed)
                  if (task!.milestones.isNotEmpty && 
                      task!.status != TaskStatus.assigned && 
                      task!.status != TaskStatus.unassigned) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark)),
                        Text(
                          '${(task!.progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task!.progress,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: task!.milestones.map((milestone) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildMilestoneChip(context, milestone, task!),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Asset info if assigned
                  if (task!.assignedTruckName != null || task!.assignedDriverName != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    if (task!.assignedTruckName != null)
                      Row(
                        children: [
                          const Icon(Icons.local_shipping, size: 16, color: AppTheme.towingOrange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Assigned: ${task!.assignedTruckName}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (task!.assignedDriverName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.airline_seat_recline_normal, size: 16, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Driver: ${task!.assignedDriverName}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                  ],

                  const SizedBox(height: 16),

                  // Footer Actions
                  Row(
                    children: [
                      if (onMessagePressed != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onMessagePressed,
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Message'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                              foregroundColor: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                            ),
                          ),
                        ),
                      if (onMessagePressed != null && onActionPressed != null)
                        const SizedBox(width: 12),
                      if (onActionPressed != null)
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: onActionPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: statusColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              actionLabel ?? 'View Details',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconRow(BuildContext context, IconData icon, String text, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }



  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.assigned:
        return AppTheme.primaryBlue;
      case TaskStatus.inProgress:
        return AppTheme.towingOrange;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.grey;
      case TaskStatus.unassigned:
        return Colors.blueGrey;
    }
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM dd, hh:mm a').format(date);
  }

  Widget _buildMilestoneChip(BuildContext context, TaskMilestone milestone, Task currentTask) {
    final isCompleted = milestone.isCompleted;
    final canToggle = onMilestoneToggle != null && currentTask.status == TaskStatus.inProgress;

    return InkWell(
      onTap: canToggle ? () => onMilestoneToggle!(milestone) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted ? Colors.green.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCompleted)
              const Padding(
                padding: EdgeInsets.only(right: 4.0),
                child: Icon(Icons.check, size: 12, color: Colors.green),
              ),
            Text(
              milestone.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                color: isCompleted ? Colors.green[700] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 180,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
