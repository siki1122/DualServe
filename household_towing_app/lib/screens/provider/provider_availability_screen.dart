import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class ProviderAvailabilityScreen extends StatefulWidget {
  const ProviderAvailabilityScreen({super.key});

  @override
  State<ProviderAvailabilityScreen> createState() => _ProviderAvailabilityScreenState();
}

class _ProviderAvailabilityScreenState extends State<ProviderAvailabilityScreen> {
  final TaskService _taskService = TaskService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _providerId;

  final Map<String, List<String>> _weeklySchedule = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
    'Saturday': [],
    'Sunday': [],
  };

  final List<String> _availableSlots = [
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
  ];

  bool _isLoading = false;
  String? _selectedDay;
  final Map<String, int> _taskCounts = {};

  @override
  void initState() {
    super.initState();
    _providerId = FirebaseAuth.instance.currentUser!.uid;
    _loadSchedule();
  }

  void _loadSchedule() async {
    try {
      final scheduleDoc = await _firestore
          .collection('providers')
          .doc(_providerId)
          .collection('schedule')
          .doc('weekly')
          .get();

      if (scheduleDoc.exists) {
        setState(() {
          scheduleDoc.data()?.forEach((day, slots) {
            if (_weeklySchedule.containsKey(day)) {
              _weeklySchedule[day] = List<String>.from(slots);
            }
          });
        });
      }

      // Load task counts for the current week
      _loadTaskCounts();
    } catch (e) {
    }
  }

  void _loadTaskCounts() async {
    final now = DateTime.now();
    // Get the start of this week (Monday)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dayName = _getDayName(date.weekday);
      final count = await _taskService.getProviderTaskCountForDate(_providerId, date);
      if (mounted) {
        setState(() {
          _taskCounts[dayName] = count;
        });
      }
    }
  }

  String _getDayName(int weekday) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday];
  }

  void _toggleSlot(String day, String time) {
    setState(() {
      if (_weeklySchedule[day]!.contains(time)) {
        _weeklySchedule[day]!.remove(time);
      } else {
        _weeklySchedule[day]!.add(time);
        _weeklySchedule[day]!.sort((a, b) => a.compareTo(b));
      }
    });
  }

  void _saveSchedule() async {
    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('providers')
          .doc(_providerId)
          .collection('schedule')
          .doc('weekly')
          .set(_weeklySchedule);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving availability: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Manage Availability'),
        backgroundColor: AppTheme.statusCompletedText,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.towingOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.statusCompletedText),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.towingOrange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Set Your Available Time Slots',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSlateDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tasks will be assigned during your available hours',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Weekly schedule sections
            ..._weeklySchedule.entries.map((entry) {
              final day = entry.key;
              final selectedTimes = entry.value;
              final taskCount = _getTaskCountForDay(day);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      border: Border(
                        bottom: BorderSide(color: AppTheme.textSlateLight),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSlateDark,
                          ),
                        ),
                        Row(
                          children: [
                            if (taskCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$taskCount tasks',
                                  style: TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.statusCompletedText,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${selectedTimes.length} slots',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Time slots
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableSlots.map((time) {
                        final isSelected = selectedTimes.contains(time);
                        return GestureDetector(
                          onTap: () => _toggleSlot(day, time),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.statusCompletedText : AppTheme.surfaceLight,
                              border: Border.all(
                                color: isSelected ? AppTheme.statusCompletedText : AppTheme.textSlateLight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              time,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textSlateDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.statusCompletedText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: AppTheme.textSlateMedium,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Availability',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getTaskCountForDay(String day) {
    return _taskCounts[day] ?? 0;
  }
}
