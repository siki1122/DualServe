import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../widgets/provider_drawer.dart';

class ProviderHistoryScreen extends StatefulWidget {
  const ProviderHistoryScreen({super.key});

  @override
  State<ProviderHistoryScreen> createState() => _ProviderHistoryScreenState();
}

class _ProviderHistoryScreenState extends State<ProviderHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<DocumentSnapshot> _historyDocs = [];
  bool _isFetchingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String _searchQuery = '';

  double _totalEarnings = 0;
  int _completedJobs = 0;
  double _rating = 5.0;

  @override
  void initState() {
    super.initState();
    _loadProviderStats();
    _fetchHistory();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchHistory(isMore: true);
      }
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProviderStats() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        setState(() {
          _totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
          _completedJobs = data['jobsCompleted'] ?? 0;
          _rating = (data['rating'] ?? 5.0).toDouble();
        });
      }
    } catch (e) {
      // Error loading stats
    }
  }

  Future<void> _fetchHistory({bool isMore = false}) async {
    if (_isFetchingMore) return;

    setState(() => _isFetchingMore = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    Query query = FirebaseFirestore.instance
        .collection('tasks')
        .where('assignedProviderId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('scheduledDate'); // Ascending to use existing index

    try {
      final snapshot = await query.get();
      _hasMore = false; // Fetch all at once for simplicity with reversing

      if (mounted) {
        setState(() {
          _historyDocs.clear();
          // Reverse to show newest first
          _historyDocs.addAll(snapshot.docs.reversed);
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const ProviderDrawer(),
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textSlateDark,
          ),
        ),
      ),
      body: Column(
        children: [
          // Summary Stats Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    'Lifetime',
                    '₱${_totalEarnings.toStringAsFixed(0)}',
                    Colors.blue,
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey.shade200),
                Expanded(
                  child: _buildStatColumn('Jobs', '$_completedJobs', Colors.green),
                ),
                Container(width: 1, height: 30, color: Colors.grey.shade200),
                Expanded(
                  child: _buildStatColumn(
                    'Rating',
                    _rating.toStringAsFixed(1),
                    AppTheme.towingOrange,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search history by service...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.textSlateMedium,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // History List
          Expanded(
            child: _historyDocs.isEmpty && !_isFetchingMore
                ? const Center(
                    child: Text(
                      'No completed jobs yet.',
                      style: TextStyle(color: AppTheme.textSlateMedium),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _historyDocs.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _historyDocs.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final doc = _historyDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      if (_searchQuery.isNotEmpty) {
                        final serviceType = (data['serviceType'] ?? '')
                            .toString()
                            .toLowerCase();
                        if (!serviceType.contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }
                      }

                      return _HistoryCard(
                        booking: doc as QueryDocumentSnapshot,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final QueryDocumentSnapshot booking;

  const _HistoryCard({required this.booking});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  String _customerName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadCustomerName();
  }

  void _loadCustomerName() async {
    try {
      final customerId = widget.booking['customerId'];
      if (customerId == null || customerId.isEmpty) {
        if (mounted) setState(() => _customerName = 'Unknown');
        return;
      }

      final customerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
          
      if (mounted) {
        setState(() {
          if (customerDoc.exists) {
            _customerName = customerDoc['name'] ?? 'Unknown Customer';
          } else {
            _customerName = 'Unknown User';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _customerName = 'Unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final date = (booking['scheduledDate'] as Timestamp).toDate();
    final formattedTime = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final formattedDate =
        '${date.day}/${date.month}/${date.year} $formattedTime';

    final hasReview = true;
    final reviewText = 'Excellent work! Very professional.';

    final rawCost = (booking['estimatedCost'] ?? 0.0);
    final formattedCost = rawCost is num ? rawCost.toStringAsFixed(2) : rawCost.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.statusCompletedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.statusCompletedText,
                  ),
                ),
              ),
              Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSlateLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking['serviceType'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSlateDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer: $_customerName',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSlateMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₱$formattedCost',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          if (hasReview) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                const Text(
                  '5.0',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"$reviewText"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSlateMedium,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
