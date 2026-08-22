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

import '../../widgets/dashboard_shimmer.dart';
import 'provider_verification_screen.dart';

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
              backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
              appBar: AppBar(
                title: Text(
                  'Dashboard',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: isDark ? Colors.white : AppTheme.textSlateDark,
              ),
              body: const SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: DashboardShimmer(),
              ),
            );
          }

          final profile = userProvider.providerProfile!;

          return Scaffold(
            backgroundColor: isDark
                ? AppTheme.backgroundDark
                : AppTheme.background,
            drawer: const ProviderDrawer(),
            appBar: AppBar(
              title: Text(
                'Dashboard',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                ),
              ),
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
                      const SizedBox(height: 16),
                      _buildVerificationBanner(profile, userProvider.uid),
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

  Widget _buildVerificationBanner(Map<String, dynamic> profile, String providerId) {
    final status = profile['verificationStatus'] ?? 'pending';
    final hasDocs = profile['businessPermitUrl'] != null && profile['governmentIdUrl'] != null;

    if (status == 'verified') return const SizedBox.shrink();

    Color bannerColor = Colors.orange[50]!;
    Color textColor = Colors.orange[900]!;
    IconData icon = Icons.warning_amber_rounded;
    String message = 'Verification Required';
    String subMessage = 'Please upload your business documents to start accepting jobs.';
    String buttonText = 'Verify Now';

    if (status == 'pending' && hasDocs) {
      bannerColor = Colors.blue[50]!;
      textColor = Colors.blue[900]!;
      icon = Icons.hourglass_empty_rounded;
      message = 'Verification Pending';
      subMessage = 'Your documents are currently being reviewed by our team.';
      buttonText = 'View Status';
    } else if (status == 'rejected') {
      bannerColor = Colors.red[50]!;
      textColor = Colors.red[900]!;
      icon = Icons.error_outline_rounded;
      message = 'Verification Failed';
      subMessage = profile['rejectionReason'] ?? 'Some documents were invalid. Please re-upload.';
      buttonText = 'Re-upload';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subMessage,
                      style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status != 'pending' || !hasDocs) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProviderVerificationScreen(providerId: providerId),
                    ),
                  ).then((_) => context.read<UserProvider>().loadCurrentUserData());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: textColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ],
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
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String name, bool isDark, bool isAvailable) {
    return Row(
      children: [

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                ),
              ),
              Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7061FA), Color(0xFF4B3CFA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4B3CFA).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "TODAY'S EARNINGS",
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${stats['todayJobs']} Jobs',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '₱${(stats['todayEarnings'] as num).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(Icons.timer, 'Pending', stats['pending'].toString()),
                  ),
                  Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
                  Expanded(
                    child: _buildMiniStat(Icons.running_with_errors, 'Active', stats['active'].toString()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark
                          ? AppTheme.textDarkPrimary
                          : AppTheme.textSlateDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : AppTheme.textSlateMedium,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : AppTheme.textSlateMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
