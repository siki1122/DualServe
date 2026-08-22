import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../../widgets/shimmer_loading.dart';

class ProviderEarningsScreen extends StatefulWidget {
  const ProviderEarningsScreen({super.key});

  @override
  State<ProviderEarningsScreen> createState() => _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState extends State<ProviderEarningsScreen> {
  final String _providerId = FirebaseAuth.instance.currentUser!.uid;
  Map<String, double> _dailyEarnings = {};
  double _totalEarnings = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    try {
      // We use scheduledDate instead of completedAt for the query to avoid needing a new index
      // We will filter the actual 7 days in memory
      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedProviderId', isEqualTo: _providerId)
          .where('status', isEqualTo: 'completed')
          .orderBy('scheduledDate')
          .get();

      double total = 0;
      Map<String, double> daily = {};

      // Initialize last 7 days with 0
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dayKey = DateFormat('EEE').format(date);
        daily[dayKey] = 0;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['completedAt'] == null) continue;

        final timestamp = (data['completedAt'] as Timestamp).toDate();

        // Only process if completed within the last 7 days
        if (timestamp.isAfter(sevenDaysAgo)) {
          final double cost = (data['estimatedCost'] as num?)?.toDouble() ?? 0.0;
          final dayKey = DateFormat('EEE').format(timestamp);

          if (daily.containsKey(dayKey)) {
            daily[dayKey] = daily[dayKey]! + cost;
          }
          total += cost;
        }
      }

      setState(() {
        _dailyEarnings = daily;
        _totalEarnings = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: const Text('My Earnings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppTheme.textSlateDark,
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTotalCard(isDark),
                  const SizedBox(height: 32),
                  const Text(
                    'Last 7 Days',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildChart(isDark),
                  const SizedBox(height: 32),
                  _buildEarningsList(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, Color(0xFF1e40af)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Earnings (7d)',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '₱${_totalEarnings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(bool isDark) {
    final List<BarChartGroupData> barGroups = [];
    final days = _dailyEarnings.keys.toList().reversed.toList();

    for (int i = 0; i < days.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: _dailyEarnings[days[i]]!,
              color: AppTheme.primaryBlue,
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    final double maxDaily = _dailyEarnings.values.fold(0.0, (max, e) => e > max ? e : max);
    final double calculatedMaxY = maxDaily > 0 ? (maxDaily * 1.2) : 1000.0;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: calculatedMaxY,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      days[value.toInt()],
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppTheme.textSlateMedium,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildEarningsList(bool isDark) {
    final days = _dailyEarnings.keys.toList().reversed.toList();
    
    return Column(
      children: days.map((day) {
        final amount = _dailyEarnings[day]!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '₱${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: amount > 0 ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
