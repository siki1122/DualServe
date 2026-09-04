import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/task_model.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'driver_task_detail_screen.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _driverId;

  @override
  void initState() {
    super.initState();
    _driverId = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('tasks')
            .where('assignedDriverId', isEqualTo: _driverId)
            .where('status', whereNotIn: ['completed', 'cancelled']) // Only show active/upcoming
            .orderBy('status')
            .orderBy('scheduledDate', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SelectableText(
                  'Error loading tasks:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(isDark);
          }

          final tasks = snapshot.data!.docs.map((doc) => Task.fromFirestore(doc)).toList();
          
          // Sort tasks: Active ones (inProgress, assigned) first, then pending.
          tasks.sort((a, b) {
            if (a.status == TaskStatus.inProgress || a.status == TaskStatus.assigned) return -1;
            if (b.status == TaskStatus.inProgress || b.status == TaskStatus.assigned) return 1;
            return a.scheduledDate.compareTo(b.scheduledDate);
          });

          final activeTask = tasks.isNotEmpty && (tasks.first.status == TaskStatus.inProgress || tasks.first.status == TaskStatus.assigned) ? tasks.first : null;
          final upcomingTasks = activeTask != null ? tasks.skip(1).toList() : tasks;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (activeTask != null) ...[
                      _buildSectionHeader('Current Job', isDark),
                      const SizedBox(height: 12),
                      _buildActiveHeroCard(activeTask, isDark),
                      const SizedBox(height: 24),
                    ],
                    if (upcomingTasks.isNotEmpty) ...[
                      _buildSectionHeader('Upcoming Tasks', isDark),
                      const SizedBox(height: 12),
                    ],
                  ]),
                ),
              ),
              if (upcomingTasks.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildUpcomingTaskCard(upcomingTasks[index], isDark),
                      childCount: upcomingTasks.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textSlateDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no assigned tasks right now.',
            style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppTheme.textSlateDark,
      ),
    );
  }

  Widget _buildActiveHeroCard(Task task, bool isDark) {
    Color statusColor = AppTheme.primaryBlue;
    if (task.status == TaskStatus.assigned) statusColor = AppTheme.towingOrange;
    if (task.status == TaskStatus.inProgress) statusColor = AppTheme.statusCompletedText;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => DriverTaskDetailScreen(task: task)));
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task.status.name.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  task.serviceType,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textSlateDark,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.location_on, size: 18, color: statusColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.location,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : AppTheme.textSlateMedium,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.access_time, size: 18, color: statusColor),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM d, h:mm a').format(task.scheduledDate),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : AppTheme.textSlateMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DriverTaskDetailScreen(task: task)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Manage Task', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingTaskCard(Task task, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DriverTaskDetailScreen(task: task)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.engineering, color: isDark ? Colors.white70 : AppTheme.textSlateDark),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.serviceType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : AppTheme.textSlateDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(task.scheduledDate),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white24 : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
