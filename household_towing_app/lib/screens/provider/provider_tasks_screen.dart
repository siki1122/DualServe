import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_task_card.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/provider/transaction_completion_screen.dart';
import '../../screens/driver/signature_capture_screen.dart';
import '../../services/location_service.dart';
import '../../widgets/asset_selection_dialog.dart';
import '../../providers/user_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/provider_drawer.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../widgets/app_booking_request_card.dart';
import '../../screens/provider/booking_detail_screen.dart';
import '../../services/booking_service.dart';
import '../../models/booking_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/asset_selection_dialog.dart';

enum ProviderTaskFilter {
  requests,
  assigned,
  inProgress,
  completed,
  declined
}

class ProviderTasksScreen extends StatefulWidget {
  const ProviderTasksScreen({super.key});

  @override
  State<ProviderTasksScreen> createState() => _ProviderTasksScreenState();
}

class _ProviderTasksScreenState extends State<ProviderTasksScreen> {
  final TaskService _taskService = TaskService();
  final BookingService _bookingService = BookingService();
  final StorageService _storageService = StorageService();
  late String _providerId;
  ProviderTaskFilter _filterStatus = ProviderTaskFilter.assigned;
  final bool _isUploading = false;
  final Map<TaskStatus, Stream<List<Task>>> _taskStreams = {};
  
  // Track accepting/rejecting state
  String? _processingBookingId;

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
      drawer: const ProviderDrawer(),
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
                  _buildFilterChip('Requests', ProviderTaskFilter.requests),
                  const SizedBox(width: 8),
                  _buildFilterChip('Assigned', ProviderTaskFilter.assigned),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Progress', ProviderTaskFilter.inProgress),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed', ProviderTaskFilter.completed),
                  const SizedBox(width: 8),
                  _buildFilterChip('Declined', ProviderTaskFilter.declined),
                ],
              ),
            ),
          ),
          // Task list
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ProviderTaskFilter status) {
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
              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
          ),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: AppTheme.textSlateDark.withValues(alpha: 0.1),
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

  Widget _buildContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_filterStatus == ProviderTaskFilter.requests || _filterStatus == ProviderTaskFilter.declined) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('assignedProviderId', isEqualTo: _providerId)
            .where('status', isEqualTo: _filterStatus == ProviderTaskFilter.requests ? 'pending' : 'rejected')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final bookingsDocs = snapshot.data?.docs ?? [];
          final bookings = bookingsDocs.map((doc) => Booking.fromFirestore(doc)).toList();
          
          // Sort by createdAt descending so newest requests are at the top
          bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppTheme.textSlateLight,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No bookings found',
                    style: TextStyle(
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
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return AppBookingRequestCard(
                booking: booking,
                isProcessing: _processingBookingId == booking.id,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingDetailScreen(bookingId: booking.id),
                    ),
                  );
                },
                onAcceptPressed: () => _handleAcceptBooking(booking),
                onDeclinePressed: () => _handleDeclineBooking(booking),
              );
            },
          );
        },
      );
    }

    TaskStatus currentTaskStatus;
    switch (_filterStatus) {
      case ProviderTaskFilter.inProgress:
        currentTaskStatus = TaskStatus.inProgress;
        break;
      case ProviderTaskFilter.completed:
        currentTaskStatus = TaskStatus.completed;
        break;
      default:
        currentTaskStatus = TaskStatus.assigned;
    }

    return StreamBuilder<List<Task>>(
      stream: _taskStreams[currentTaskStatus]!,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading tasks:\n${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
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
                  color: AppTheme.textSlateLight,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${currentTaskStatus.toString().split('.').last} tasks',
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
    );
  }

  Future<void> _handleAcceptBooking(Booking booking) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final providerName = userProvider.providerProfile?['name'] ?? userProvider.userProfile?['name'] ?? 'Provider';

    showDialog(
      context: context,
      builder: (context) => AssetSelectionDialog(
        providerId: _providerId,
        providerName: providerName,
        preselectedBooking: booking,
      ),
    ).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking accepted and dispatched!'), backgroundColor: AppTheme.statusCompletedText),
        );
      }
    });
  }

  Future<void> _handleDeclineBooking(Booking booking) async {
    setState(() => _processingBookingId = booking.id);
    try {
      await _bookingService.rejectBooking(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking declined'), backgroundColor: AppTheme.towingOrange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining booking: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingBookingId = null);
      }
    }
  }

  Widget _buildTaskCard(Task task) {
    return AppTaskCard(
      task: task,
      onTap: () => _showTaskDetail(task),
      onMilestoneToggle: (task.assignedDriverId != null) ? null : (milestone) {
        _taskService.updateTaskMilestone(task.id, milestone.id, !milestone.isCompleted);
        HapticFeedback.lightImpact();
      },
      onMessageCustomerPressed: (task.status == TaskStatus.assigned || task.status == TaskStatus.inProgress)
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    bookingId: task.bookingId ?? task.id,
                    receiverId: task.customerId,
                    receiverName: 'Customer',
                  ),
                ),
              )
          : null,
      onMessageDriverPressed: (task.assignedDriverId != null && (task.status == TaskStatus.assigned || task.status == TaskStatus.inProgress))
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    bookingId: task.bookingId ?? task.id,
                    receiverId: task.assignedDriverId!,
                    receiverName: task.assignedDriverName ?? 'Driver',
                  ),
                ),
              )
          : null,
      actionLabel: task.assignedDriverId != null
          ? 'View Details'
          : (task.status == TaskStatus.assigned 
              ? 'Start Task' 
              : (task.status == TaskStatus.inProgress ? 'Complete Task' : 'View Details')),
      onActionPressed: () {
        if (task.assignedDriverId != null) {
          _showTaskDetail(task);
          return;
        }
        
        if (task.status == TaskStatus.assigned) {
          if (task.assignedTruckId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please assign Assets (Truck & Personnel) before starting.'),
                backgroundColor: AppTheme.towingOrange,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _showAssetAssignment(task);
          } else {
            _updateStatus(task, TaskStatus.inProgress);
          }
        } else if (task.status == TaskStatus.inProgress) {
          _updateStatus(task, TaskStatus.completed);
        } else {
          _showTaskDetail(task);
        }
      },
    );
  }

  void _showAssetAssignment(Task task) async {
    final userProvider = provider_pkg.Provider.of<UserProvider>(context, listen: false);
    final providerName = userProvider.userProfile?['name'] ?? 'Provider';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AssetSelectionDialog(
        providerId: _providerId,
        providerName: providerName,
        preselectedTask: task,
      ),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assets assigned successfully!'),
            backgroundColor: AppTheme.statusCompletedText,
          ),
        );
      }
    }
  }

  void _showTaskDetail(Task task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppTheme.background,
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
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

                _buildDetailRow('Status', task.status.toString().split('.').last.toUpperCase()),
                if (task.description != null && task.description!.isNotEmpty)
                  _buildDetailRow('Notes', task.description!),
                if (task.estimatedDurationMinutes != null)
                  _buildDetailRow(
                    'Est. Duration',
                    '${task.estimatedDurationMinutes} minutes',
                  ),
                
                // NEW: Progress & Milestones Section
                if (task.milestones.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Milestones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSlateDark,
                        ),
                      ),
                      Text(
                        '${(task.progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.progress,
                      minHeight: 8,
                      backgroundColor: AppTheme.textSlateLight.withValues(alpha: 0.5),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Interactive Checklist for Milestones
                  ...task.milestones.map((milestone) {
                    return CheckboxListTile(
                      title: Text(
                        milestone.title,
                        style: TextStyle(
                          decoration: milestone.isCompleted ? TextDecoration.lineThrough : null,
                          color: milestone.isCompleted ? AppTheme.textSlateMedium : AppTheme.textSlateDark,
                        ),
                      ),
                      value: milestone.isCompleted,
                      onChanged: (task.status == TaskStatus.completed || task.assignedDriverId != null)
                          ? null 
                          : (bool? value) async {
                              if (value != null) {
                                await _taskService.updateTaskMilestone(task.id, milestone.id, value);
                                HapticFeedback.mediumImpact();
                              }
                            },
                      activeColor: AppTheme.statusCompletedText,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
                ],

                if (task.completedImageUrl != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Completion Proof',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSlateMedium,
                    ),
                  ),
                ],
                if (task.status == TaskStatus.assigned) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAssetAssignment(task);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text(
                        'Edit Assigned Assets',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final position = await LocationService().getCurrentLocation();

        if (mounted) {
          Navigator.pop(context); // Close loading

          if (position == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not detect your location. GPS is required for distance surcharge calculation.'),
                backgroundColor: AppTheme.towingOrange,
              ),
            );
            return;
          }

          final success = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionCompletionScreen(
                taskId: task.id,
                bookingId: task.bookingId ?? task.id,
                customerId: task.customerId,
                providerId: task.assignedProviderId ?? _providerId,
                serviceType: task.serviceType,
                startLatitude: position.latitude,
                startLongitude: position.longitude,
                endLatitude: task.latitude,
                endLongitude: task.longitude,
              ),
            ),
          );

          if (success == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task completed and transaction recorded!'), backgroundColor: AppTheme.statusCompletedText),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar( // Use screen context
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    try {
      await _taskService.updateTaskStatus(task.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task ${newStatus.toString().split('.').last}!'),
            backgroundColor: AppTheme.statusCompletedText,
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

  // _showCompletionDialog removed since drivers now handle billing
  List<Color> _getStatusColor(TaskStatus status, bool isDark) {
    switch (status) {
      case TaskStatus.assigned:
        return [AppTheme.primaryBlue.withValues(alpha: 0.15), AppTheme.primaryBlue];
      case TaskStatus.inProgress:
        return [AppTheme.towingOrange.withValues(alpha: 0.15), AppTheme.towingOrange];
      case TaskStatus.completed:
        return [
          isDark ? Colors.green.withValues(alpha: 0.2) : AppTheme.statusCompletedBg, 
          isDark ? Colors.greenAccent : AppTheme.statusCompletedText
        ];
      case TaskStatus.cancelled:
        return [Colors.red.withValues(alpha: 0.15), Colors.red.shade400];
      default:
        return [
          isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, 
          isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium
        ];
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
