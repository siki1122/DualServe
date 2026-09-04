import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getProviderAnalytics(String providerId, String timeRange) async {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (timeRange) {
      case 'Daily':
        startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)); // Last 7 days
        break;
      case 'Weekly':
        startDate = now.subtract(const Duration(days: 28)); // Last 4 weeks
        break;
      case 'Monthly':
        startDate = DateTime(now.year, now.month - 11, 1); // Last 12 months
        break;
      case 'Yearly':
        startDate = DateTime(now.year - 4, 1, 1); // Last 5 years
        break;
      default:
        startDate = now.subtract(const Duration(days: 30));
    }

    try {
      final tasksQuery = await _firestore
          .collection('tasks')
          .where('assignedProviderId', isEqualTo: providerId)
          .get();

      double totalRevenue = 0;
      int totalTasks = tasksQuery.docs.length;
      int completedTasks = 0;
      Map<String, double> revenueData = {};
      Map<String, int> serviceDistribution = {};

      for (var doc in tasksQuery.docs) {
        final data = doc.data();
        final status = data['status'];
        final serviceType = data['serviceType'] ?? 'Unknown';
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final price = (data['finalCost'] as num?)?.toDouble() ?? (data['estimatedCost'] as num?)?.toDouble() ?? 0.0;

        // Filter locally in Dart to avoid Firestore composite index requirement
        if (createdAt.isBefore(startDate)) continue;

        // Populate service distribution
        serviceDistribution[serviceType] = (serviceDistribution[serviceType] ?? 0) + 1;

        if (status == 'completed') {
          completedTasks++;
          totalRevenue += price;

          // Group revenue by time range
          String timeKey = _formatTimeKey(createdAt, timeRange);
          revenueData[timeKey] = (revenueData[timeKey] ?? 0) + price;
        }
      }

      double completionRate = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0.0;

      // Ensure all intervals have a key even if 0
      revenueData = _fillEmptyIntervals(revenueData, startDate, now, timeRange);

      return {
        'totalRevenue': totalRevenue,
        'totalTasks': totalTasks,
        'completionRate': completionRate,
        'revenueData': revenueData,
        'serviceDistribution': serviceDistribution,
      };
    } catch (e) {
      print("Error fetching analytics: $e");
      return {
        'totalRevenue': 0.0,
        'totalBookings': 0,
        'completionRate': 0.0,
        'revenueData': <String, double>{},
        'serviceDistribution': <String, int>{},
      };
    }
  }

  String _formatTimeKey(DateTime date, String timeRange) {
    switch (timeRange) {
      case 'Daily':
        return DateFormat('E').format(date); // Mon, Tue
      case 'Weekly':
        return 'Week ${_getWeekOfMonth(date)}';
      case 'Monthly':
        return DateFormat('MMM').format(date); // Jan, Feb
      case 'Yearly':
        return DateFormat('yyyy').format(date); // 2023, 2024
      default:
        return DateFormat('MM/dd').format(date);
    }
  }

  int _getWeekOfMonth(DateTime date) {
    int week = ((date.day - 1) / 7).floor() + 1;
    return week;
  }

  Map<String, double> _fillEmptyIntervals(Map<String, double> data, DateTime start, DateTime end, String timeRange) {
    Map<String, double> filled = {};
    DateTime current = start;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      String key = _formatTimeKey(current, timeRange);
      filled[key] = data[key] ?? 0.0;

      switch (timeRange) {
        case 'Daily':
          current = current.add(const Duration(days: 1));
          break;
        case 'Weekly':
          current = current.add(const Duration(days: 7));
          break;
        case 'Monthly':
          current = DateTime(current.year, current.month + 1, 1);
          break;
        case 'Yearly':
          current = DateTime(current.year + 1, 1, 1);
          break;
        default:
          current = current.add(const Duration(days: 1));
      }
    }
    return filled;
  }
}
