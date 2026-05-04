import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:household_towing_app/services/provider_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/providers/user_provider.dart';

class ProviderScheduleScreen extends StatefulWidget {
  const ProviderScheduleScreen({super.key});

  @override
  State<ProviderScheduleScreen> createState() => _ProviderScheduleScreenState();
}

class _ProviderScheduleScreenState extends State<ProviderScheduleScreen>
    with TickerProviderStateMixin {
  final Map<String, List<String>> _weeklySchedule = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
    'Saturday': [],
    'Sunday': [],
  };

  bool _hasChanges = false;

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

  late ProviderService _providerService;
  bool _isLoading = false;
  late TabController _tabController;

  // Block-out dates state
  List<String> _blockOutDates = [];
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _providerService = ProviderService();
    _tabController = TabController(length: 2, vsync: this);
    _loadScheduleAndBlockOutDates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadScheduleAndBlockOutDates() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      // Load provider data (which now includes weeklySchedule)
      final provider = await _providerService.getProvider(uid);
      if (provider != null) {
        setState(() {
          _weeklySchedule.clear();
          // Initialize with empty lists first to ensure all days exist
          ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].forEach((day) {
            _weeklySchedule[day] = [];
          });
          
          provider.weeklySchedule.forEach((day, slots) {
            if (_weeklySchedule.containsKey(day)) {
              _weeklySchedule[day] = List<String>.from(slots);
            }
          });
          _blockOutDates = provider.blockOutDates;
        });
      }
    } catch (e) {
    }
  }

  void _toggleSlot(String day, String time) {
    setState(() {
      _hasChanges = true;
      if (_weeklySchedule[day]!.contains(time)) {
        _weeklySchedule[day]!.remove(time);
      } else {
        _weeklySchedule[day]!.add(time);
        // Sort chronologically using a helper
        _weeklySchedule[day]!.sort((a, b) => _compareTimes(a, b));
      }
    });
  }

  int _compareTimes(String a, String b) {
    final aTime = _parseTime(a);
    final bTime = _parseTime(b);
    return aTime.hour * 60 + aTime.minute - (bTime.hour * 60 + bTime.minute);
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);
    final isPM = parts[1] == 'PM';

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  void _saveSchedule() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // Save directly to the main provider document
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(uid)
          .update({
            'weeklySchedule': _weeklySchedule,
            'updatedAt': Timestamp.now(),
          });

      setState(() => _hasChanges = false);

      // Update UserProvider so other screens see the changes
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).loadCurrentUserData();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving schedule: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleBlockOutDate(DateTime date) async {
    final dateISO = date.toIso8601String().split('T')[0];
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      if (_blockOutDates.contains(dateISO)) {
        await _providerService.removeBlockOutDate(uid, date);
        setState(() => _blockOutDates.remove(dateISO));
      } else {
        await _providerService.addBlockOutDate(uid, date);
        setState(() {
          _blockOutDates.add(dateISO);
          _blockOutDates.sort();
        });
      }
      
      // Update UserProvider
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).loadCurrentUserData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating block-out dates: $e')),
      );
    }
  }

  void _clearAllBlockOutDates() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Clear All Block-Out Dates?', style: TextStyle(color: AppTheme.textSlateDark, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will remove all your vacation/unavailable dates. Are you sure?',
          style: TextStyle(color: AppTheme.textSlateMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSlateMedium)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                for (final dateISO in _blockOutDates) {
                  final date = DateTime.parse(dateISO);
                  await _providerService.removeBlockOutDate(uid, date);
                }
                setState(() => _blockOutDates.clear());
                
                // Update UserProvider
                if (mounted) {
                  Provider.of<UserProvider>(context, listen: false).loadCurrentUserData();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All block-out dates cleared')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error clearing dates: $e')),
                );
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    return List.generate(
      lastDay.difference(firstDay).inDays + 1,
      (index) => firstDay.add(Duration(days: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showDiscardDialog();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return Scaffold(
            backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
            appBar: AppBar(
              title: Text(
                'Manage Schedule',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.towingOrange,
                labelColor: AppTheme.towingOrange,
                unselectedLabelColor: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Weekly Schedule'),
                  Tab(text: 'Block-Out Dates'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyScheduleTab(),
                _buildBlockOutDatesTab(),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _showDiscardDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text('You have unsaved schedule changes. Are you sure you want to leave?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildWeeklyScheduleTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Your Available Time Slots',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the times when you\'re available for each day',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
            ),
          ),
          const SizedBox(height: 24),
          ..._weeklySchedule.entries.map((entry) {
            final day = entry.key;
            final selectedTimes = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            day,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: selectedTimes.isEmpty 
                                ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200)
                                : AppTheme.towingOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${selectedTimes.length} slots',
                              style: TextStyle(
                                color: selectedTimes.isEmpty 
                                  ? (isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)
                                  : AppTheme.towingOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
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
                                color: isSelected ? AppTheme.towingOrange : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.towingOrange
                                      : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Save Schedule',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildBlockOutDatesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);

    // Get upcoming blocked dates sorted
    final upcomingBlockedDates =
        _blockOutDates
            .map((dateISO) => DateTime.parse(dateISO))
            .where(
              (date) =>
                  date.isAfter(startDate) || date.isAtSameMomentAs(startDate),
            )
            .toList()
          ..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Block-Out Dates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mark dates when you\'re unavailable (vacation, days off)',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
            ),
          ),
          const SizedBox(height: 24),
          // Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Calendar Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // Day headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      .map(
                        (day) => Expanded(
                          child: Text(
                            day,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                // Calendar dates
                Builder(
                  builder: (context) {
                    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
                    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
                    final firstDayOfWeek = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun
                    final totalDaysInMonth = lastDayOfMonth.day;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: 42, // 6 weeks
                      itemBuilder: (context, index) {
                        int dayNumber = index - (firstDayOfWeek - 1) + 1;
                        bool isCurrentMonth = dayNumber > 0 && dayNumber <= totalDaysInMonth;

                        if (!isCurrentMonth) {
                          return const SizedBox.shrink();
                        }

                        final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                        final dateISO = date.toIso8601String().split('T')[0];
                        final isBlocked = _blockOutDates.contains(dateISO);
                        final isPast = date.isBefore(startDate);
                        final isToday = date.isAtSameMomentAs(startDate);

                        return GestureDetector(
                          onTap: isPast ? null : () => _toggleBlockOutDate(date),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isBlocked
                                  ? Colors.red[400]
                                  : isToday
                                  ? AppTheme.primaryBlue.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isToday ? AppTheme.primaryBlue : (isBlocked ? Colors.red[400]! : Colors.transparent),
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$dayNumber',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isBlocked
                                          ? Colors.white
                                          : isPast
                                          ? (isDark ? Colors.white.withOpacity(0.2) : Colors.grey[300])
                                          : (isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark),
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (isBlocked)
                                    const Icon(
                                      Icons.block,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Upcoming Blocked Dates
          if (upcomingBlockedDates.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming Block-Out Dates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearAllBlockOutDates,
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...upcomingBlockedDates.map((date) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade100),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red.withOpacity(0.1) : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ),
                      ),
                      title: Text(
                        _formatDateLong(date),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _toggleBlockOutDate(date),
                      ),
                    ),
                  );
                }),
              ],
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today, size: 48, color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No block-out dates set',
                      style: TextStyle(
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium, 
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatDateLong(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${_monthName(date.month)} ${date.day}, ${date.year}';
  }
}
