import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/app_theme.dart';
import '../../services/analytics_service.dart';
import '../../widgets/provider_drawer.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  String _selectedTimeRange = 'Monthly'; // Daily, Weekly, Monthly, Yearly
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};
  
  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    final providerId = FirebaseAuth.instance.currentUser?.uid;
    if (providerId != null) {
      _analyticsData = await _analyticsService.getProviderAnalytics(providerId, _selectedTimeRange);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const ProviderDrawer(),
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textSlateDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTimeFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchAnalytics,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCards(),
                          const SizedBox(height: 24),
                          const Text("Revenue Chart", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
                          const SizedBox(height: 12),
                          _buildRevenueChart(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Daily', 'Weekly', 'Monthly', 'Yearly'].map((range) {
            bool isSelected = _selectedTimeRange == range;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(range),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedTimeRange = range);
                    _fetchAnalytics();
                  }
                },
                selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textSlateMedium,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade300),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(child: _buildMetricCard(
          "Total Revenue", 
          "PHP ${_analyticsData['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}", 
          Icons.account_balance_wallet, 
          AppTheme.statusCompletedText
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(
          "Completion", 
          "${_analyticsData['completionRate']?.toStringAsFixed(1) ?? '0'}%", 
          Icons.check_circle_outline, 
          AppTheme.primaryBlue
        )),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium)),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    final revenueData = _analyticsData['revenueData'] as Map<String, double>? ?? {};
    if (revenueData.isEmpty) {
      return Container(
        height: 250,
        decoration: AppTheme.cardDecoration(context),
        child: const Center(child: Text("No data available for this period.")),
      );
    }

    List<String> keys = revenueData.keys.toList();
    List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    for (int i = 0; i < keys.length; i++) {
      double value = revenueData[keys[i]]!;
      if (value > maxY) maxY = value;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: AppTheme.primaryBlue,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY == 0 ? 100 : maxY * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= 0 && value.toInt() < keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        keys[value.toInt()], 
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSlateMedium),
                      ),
                    );
                  }
                  return const Text('');
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

  Widget _buildServicePieChart() {
    final serviceDistribution = _analyticsData['serviceDistribution'] as Map<String, int>? ?? {};
    if (serviceDistribution.isEmpty) {
      return Container(
        height: 200,
        decoration: AppTheme.cardDecoration(context),
        child: const Center(child: Text("No services completed in this period.")),
      );
    }

    List<PieChartSectionData> sections = [];
    int i = 0;
    List<Color> colors = [AppTheme.primaryBlue, Colors.amber, AppTheme.statusCompletedText, Colors.purple, Colors.red];

    serviceDistribution.forEach((key, value) {
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: value.toDouble(),
          title: value.toInt().toString(),
          radius: 50,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
      i++;
    });

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildLegend(serviceDistribution, colors),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLegend(Map<String, int> data, List<Color> colors) {
    List<Widget> legends = [];
    int i = 0;
    data.forEach((key, value) {
      legends.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Container(width: 12, height: 12, color: colors[i % colors.length]),
              const SizedBox(width: 8),
              Expanded(child: Text(key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
            ],
          ),
        )
      );
      i++;
    });
    return legends;
  }
}
