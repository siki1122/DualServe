import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/task_model.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../chat/chat_screen.dart';
import '../../services/driver_tracking_service.dart';
import '../../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
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
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  List<String> _uploadedEvidenceUrls = [];
  bool _isUploadingEvidence = false;

  final TaskService _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _uploadedEvidenceUrls = List.from(_task.preTowPhotoUrls);
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
    // Validate evidence
    final bool isTowing = _task.serviceType.toLowerCase().contains('tow');
    final int requiredPhotos = isTowing ? 4 : 2;

    if (newStatus == TaskStatus.inProgress) {
      if (_uploadedEvidenceUrls.length < requiredPhotos) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please upload all $requiredPhotos pre-service evidence photos before proceeding.'), backgroundColor: Colors.orange),
        );
        return;
      }
    }

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
      if (newStatus == TaskStatus.inProgress) { // Assuming 'En Route' or 'In Progress' should track
        DriverTrackingService().startTracking(_task.assignedDriverId ?? '', _task.id);
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
      if (newStatus == TaskStatus.inProgress) {
        DriverTrackingService().startTracking(_task.assignedDriverId ?? '', _task.id);
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
                      _buildEvidenceCard(isDark),
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
                  'Scope Checklist',
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
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _task.progress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 16),
            ..._task.milestones.map((milestone) {
              return CheckboxListTile(
                title: Text(
                  milestone.title,
                  style: TextStyle(
                    decoration: milestone.isCompleted ? TextDecoration.lineThrough : null,
                    color: milestone.isCompleted ? Colors.grey : AppTheme.textSlateDark,
                  ),
                ),
                value: milestone.isCompleted,
                onChanged: (_task.status == TaskStatus.completed)
                    ? null 
                    : (bool? value) async {
                        if (value != null) {
                          await _taskService.updateTaskMilestone(_task.id, milestone.id, value);
                          HapticFeedback.mediumImpact();
                          final doc = await _firestore.collection('tasks').doc(_task.id).get();
                          if (doc.exists && mounted) {
                            setState(() {
                              _task = Task.fromFirestore(doc);
                            });
                          }
                        }
                      },
                activeColor: Colors.green,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
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

  Widget _buildEvidenceCard(bool isDark) {
    final bool isTowing = _task.serviceType.toLowerCase().contains('tow');
    final int requiredPhotos = isTowing ? 4 : 2;
    final List<String> labels = isTowing 
        ? ['Front', 'Back', 'Left', 'Right'] 
        : ['Before 1', 'Before 2'];

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
            isTowing ? 'Pre-Tow Evidence (Required)' : 'Pre-Service Evidence (Required)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textSlateDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTowing 
              ? 'Please upload 4 photos (Front, Back, Left, Right) to document existing damage before starting the route.'
              : 'Please upload 2 "Before" photos of the area to document its condition before starting work.',
            style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isTowing ? 2 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
            ),
            itemCount: requiredPhotos,
            itemBuilder: (context, index) {
              final hasImage = index < _uploadedEvidenceUrls.length;

              return GestureDetector(
                onTap: hasImage ? null : () => _pickAndUploadImage(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: hasImage ? Colors.green : Colors.grey.shade300),
                    image: hasImage ? DecorationImage(image: NetworkImage(_uploadedEvidenceUrls[index]), fit: BoxFit.cover) : null,
                  ),
                  child: hasImage
                      ? const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(4), child: Icon(Icons.check_circle, color: Colors.green)))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isUploadingEvidence) const CircularProgressIndicator() else const Icon(Icons.add_a_photo, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(labels[index], style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(int index) async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploadingEvidence = true);
    final url = await _storageService.uploadTaskEvidenceImage(_task.id, image, index);
    
    if (url != null) {
      final updatedUrls = List<String>.from(_uploadedEvidenceUrls);
      updatedUrls.add(url);
      
      setState(() {
        _uploadedEvidenceUrls = updatedUrls;
      });
      
      // Save to task
      await _firestore.collection('tasks').doc(_task.id).update({
        'preTowPhotoUrls': _uploadedEvidenceUrls,
      });
      
      setState(() {
        _task = _task.copyWith(preTowPhotoUrls: _uploadedEvidenceUrls);
      });
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload image')));
    }
    
    if (mounted) setState(() => _isUploadingEvidence = false);
  }

  Widget _buildBottomActionPanel(bool isDark) {
    if (_task.status == TaskStatus.completed || _task.status == TaskStatus.cancelled) {
      return const SizedBox.shrink(); // No actions for completed/cancelled
    }

    String actionText = 'Start Route';
    TaskStatus nextStatus = TaskStatus.inProgress;
    Color btnColor = AppTheme.primaryBlue;
    bool isButtonDisabled = false;

    if (_task.status == TaskStatus.assigned) {
      actionText = 'Arrived at Location';
      nextStatus = TaskStatus.inProgress; // Simplified flow: Assigned -> InProgress
      btnColor = Colors.orange;
    } else if (_task.status == TaskStatus.inProgress) {
      actionText = 'Complete Job';
      nextStatus = TaskStatus.completed;
      btnColor = Colors.green;
      if (_task.progress < 1.0) {
        isButtonDisabled = true;
      }
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
              onPressed: isButtonDisabled ? null : () => _updateStatus(nextStatus),
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                actionText,
                style: TextStyle(
                  color: isButtonDisabled ? (isDark ? Colors.grey[500] : Colors.grey[500]) : Colors.white, 
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
