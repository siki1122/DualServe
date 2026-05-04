import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/report_metric_card.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reports & Analytics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'System performance and insights',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      underline: const SizedBox(),
                      value: 'Last 6 Months',
                      items: const [
                        DropdownMenuItem(
                          value: 'Last 6 Months',
                          child: Text('Last 6 Months'),
                        ),
                        DropdownMenuItem(
                          value: 'Last 3 Months',
                          child: Text('Last 3 Months'),
                        ),
                        DropdownMenuItem(
                          value: 'Last Month',
                          child: Text('Last Month'),
                        ),
                      ],
                      onChanged: (value) {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Report export is not available yet'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Report metrics
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, usersSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('bookings').snapshots(),
                builder: (context, bookingsSnapshot) {
                  int totalCustomers = usersSnapshot.data?.docs.length ?? 0;
                  double monthlyRevenue = 0;
                  if (bookingsSnapshot.hasData) {
                    for (var doc in bookingsSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['status'] == 'completed') {
                        monthlyRevenue +=
                            (data['estimatedCost'] as num?)?.toDouble() ?? 0;
                      }
                    }
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: ReportMetricCard(
                          value: '$totalCustomers',
                          title: 'Total Customers',
                          icon: Icons.people,
                          color: Color(0xFF2563eb),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ReportMetricCard(
                          value: '₱${monthlyRevenue.toStringAsFixed(0)}',
                          title: 'Monthly Revenue',
                          icon: Icons.attach_money,
                          color: Color(0xFF16a34a),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ReportMetricCard(
                          value: '12 min',
                          title: 'Avg Response Time',
                          icon: Icons.schedule,
                          color: Color(0xFFea580c),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ReportMetricCard(
                          value: '4.8',
                          title: 'Average Rating',
                          icon: Icons.star,
                          color: Color(0xFFa855f7),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          // Charts
          Row(
            children: [
              Expanded(child: _buildServiceRequestsTrendChart()),
              const SizedBox(width: 16),
              Expanded(child: _buildRevenueGrowthChart()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRequestsTrendChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Requests Trend',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Monthly requests by service type',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('bookings').snapshots(),
            builder: (context, snapshot) {
              List<int> monthlyRequests = [0, 0, 0, 0, 0, 0, 0];
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final date = _dateFromBooking(
                    doc.data() as Map<String, dynamic>,
                  );
                  if (date == null) continue;
                  final now = DateTime.now();
                  final monthDiff =
                      (now.year - date.year) * 12 + now.month - date.month;
                  if (monthDiff >= 0 && monthDiff < 7) {
                    monthlyRequests[6 - monthDiff]++;
                  }
                }
              }
              return SizedBox(
                height: 300,
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
                            toY: monthlyRequests[i].toDouble(),
                            color: i == 6
                                ? Color(0xFFf59e0b)
                                : Color(0xFF2563eb),
                          ),
                        ],
                      ),
                    ),
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
                              'Jul',
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
                          interval: 50,
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

  Widget _buildRevenueGrowthChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Growth',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Monthly revenue over time',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('bookings')
                .where('status', isEqualTo: 'completed')
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
                height: 300,
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
                          interval: 10000,
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
