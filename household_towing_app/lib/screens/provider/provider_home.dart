import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/booking_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/provider_drawer.dart';
import 'available_tasks_screen.dart';
import 'provider_tasks_screen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../widgets/new_job_overlay.dart';
import '../../services/provider_service.dart';
import '../../models/provider_model.dart';

class ProviderHome extends StatefulWidget {
  const ProviderHome({super.key});

  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  final BookingService _bookingService = BookingService();
  final ProviderService _providerService = ProviderService();
  bool _isToggling = false;

  Future<void> _toggleStatus(String providerId, bool isAvailable) async {
    if (_isToggling) return;
    
    setState(() => _isToggling = true);
    try {
      final newStatus = isAvailable ? ProviderStatus.available : ProviderStatus.offline;
      await _providerService.updateProviderStatus(providerId, newStatus);
      
      if (mounted) {
        await context.read<UserProvider>().loadCurrentUserData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NewJobOverlay(
      child: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          if (userProvider.isLoading || userProvider.providerProfile == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Provider Dashboard')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final profile = userProvider.providerProfile!;

          return Scaffold(
            backgroundColor: isDark
                ? AppTheme.backgroundDark
                : AppTheme.background,
            drawer: const ProviderDrawer(),
            appBar: AppBar(
              title: const Text('Dashboard'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                _buildStatusToggle(userProvider.uid, profile['status'] == 'available', isDark),
                const SizedBox(width: 8),
              ],
              foregroundColor: isDark ? Colors.white : AppTheme.textSlateDark,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimationLimiter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 375),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      horizontalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      _buildHeader(profile['name'] ?? 'Provider', isDark, profile['status'] == 'available'),
                      const SizedBox(height: 32),
                      _buildStatsGrid(userProvider.uid, isDark),
                      const SizedBox(height: 32),
                      _buildQuickActions(context, isDark),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusToggle(String providerId, bool isAvailable, bool isDark) {
    return Row(
      children: [
        Text(
          isAvailable ? 'ONLINE' : 'OFFLINE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: isAvailable 
              ? Colors.green 
              : (isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
          ),
        ),
        const SizedBox(width: 4),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: isAvailable,
            onChanged: _isToggling ? null : (val) => _toggleStatus(providerId, val),
            activeColor: Colors.green,
            activeTrackColor: Colors.green.withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String name, bool isDark, bool isAvailable) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: TextStyle(
                fontSize: 16,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : AppTheme.textSlateMedium,
              ),
            ),
            Text(
              name,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
              ),
            ),
          ],
        ),
        if (isAvailable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.green, blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Available',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatsGrid(String providerId, bool isDark) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _bookingService.getProviderDashboardStats(providerId),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            {'pending': 0, 'active': 0, 'todayEarnings': 0.0, 'todayJobs': 0};

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Pending',
              stats['pending'].toString(),
              Icons.timer,
              Colors.orange,
              isDark,
            ),
            _buildStatCard(
              'Active',
              stats['active'].toString(),
              Icons.running_with_errors,
              Colors.blue,
              isDark,
            ),
            _buildStatCard(
              'Today',
              '₱${(stats['todayEarnings'] as double).toStringAsFixed(2)}',
              Icons.payments,
              Colors.green,
              isDark,
            ),
            _buildStatCard(
              'Jobs',
              stats['todayJobs'].toString(),
              Icons.task_alt,
              Colors.purple,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.textDarkPrimary
                      : AppTheme.textSlateDark,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : AppTheme.textSlateMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
          ),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          context,
          'My Tasks',
          'Manage your assigned jobs',
          Icons.assignment,
          AppTheme.primaryBlue,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProviderTasksScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          'Available Tasks',
          'Find new work near you',
          Icons.search,
          AppTheme.towingOrange,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AvailableTasksScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(context),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark
                          ? AppTheme.textDarkPrimary
                          : AppTheme.textSlateDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : AppTheme.textSlateMedium,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : AppTheme.textSlateMedium,
            ),
          ],
        ),
      ),
    );
  }
}
