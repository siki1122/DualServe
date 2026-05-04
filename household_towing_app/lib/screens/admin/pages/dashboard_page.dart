import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/metric_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime? _dateFromBooking(Map<String, dynamic> data) {
    final scheduledDate = data['scheduledDate'];
    if (scheduledDate is Timestamp) {
      return scheduledDate.toDate();
    }
    if (scheduledDate is DateTime) {
      return scheduledDate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric Cards
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Total Users',
                  icon: Icons.people,
                  boxColor: Color(0xFF2563eb).withValues(alpha: 0.1),
                  collection: 'users',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricCard(
                  title: 'Active Providers',
                  icon: Icons.handshake,
                  boxColor: Color(0xFF16a34a).withValues(alpha: 0.1),
                  collection: 'providers',
                  status: 'available',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCardRevenue(
                  'Revenue (MTD)',
                  Icons.attach_money,
                  Color(0xFFa855f7).withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricCard(
                  title: 'Total Bookings',
                  icon: Icons.schedule,
                  boxColor: Color(0xFFea580c).withValues(alpha: 0.1),
                  collection: 'bookings',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Charts
          Row(
            children: [
              Expanded(child: _buildWeeklyRequestsChart()),
              const SizedBox(width: 16),
              Expanded(child: _buildRevenueChart()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCardRevenue(String title, IconData icon, Color boxColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .where(
            'scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 30)),
            ),
          )
          .snapshots(),
      builder: (context, snapshot) {
        double revenue = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            revenue += (data['estimatedCost'] as num?)?.toDouble() ?? 0;
          }
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Color(0xFF2563eb), size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                '₱${revenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.trending_up, color: Color(0xFF22c55e), size: 16),
                  SizedBox(width: 4),
                  Text(
                    '+12.5%',
                    style: TextStyle(
                      color: Color(0xFF22c55e),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyRequestsChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Service Requests',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Service requests over the last 7 days',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('bookings')
                .where(
                  'scheduledDate',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime.now().subtract(const Duration(days: 7)),
                  ),
                )
                .snapshots(),
            builder: (context, snapshot) {
              List<int> weeklyData = [0, 0, 0, 0, 0, 0, 0];
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final date = _dateFromBooking(
                    doc.data() as Map<String, dynamic>,
                  );
                  if (date == null) continue;
                  final dayOfWeek = date.weekday - 1;
                  if (dayOfWeek >= 0 && dayOfWeek < 7) {
                    weeklyData[dayOfWeek]++;
                  }
                }
              }
              return SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(
                      7,
                      (i) => BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: weeklyData[i].toDouble(),
                            color: Color(0xFF2563eb),
                          ),
                        ],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ];
                            return Text(
                              days[value.toInt()],
                              style: const TextStyle(fontSize: 11),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Trend',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Monthly revenue for the last 6 months',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('bookings')
                .where('status', isEqualTo: 'completed')
                .where(
                  'scheduledDate',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime.now().subtract(const Duration(days: 180)),
                  ),
                )
                .snapshots(),
            builder: (context, snapshot) {
              List<double> monthlyRevenue = [0, 0, 0, 0, 0, 0];
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = _dateFromBooking(data);
                  if (date == null) continue;
                  final now = DateTime.now();
                  final monthDiff =
                      (now.year - date.year) * 12 + now.month - date.month;
                  if (monthDiff >= 0 && monthDiff < 6) {
                    monthlyRevenue[5 - monthDiff] +=
                        (data['estimatedCost'] as num?)?.toDouble() ?? 0;
                  }
                }
              }
              return SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          6,
                          (i) => FlSpot(i.toDouble(), monthlyRevenue[i]),
                        ),
                        color: Color(0xFF06b6d4),
                        dotData: FlDotData(show: false),
                        isCurved: true,
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const months = [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'Jun',
                            ];
                            return Text(
                              months[value.toInt()],
                              style: const TextStyle(fontSize: 11),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 5000,
                          getTitlesWidget: (value, meta) => Text(
                            '${value ~/ 1000}k',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
