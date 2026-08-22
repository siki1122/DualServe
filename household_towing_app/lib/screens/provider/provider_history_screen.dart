import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../widgets/provider_drawer.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/skeleton_loader.dart';

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

  @override
  void initState() {
    super.initState();
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


  Future<void> _fetchHistory({bool isMore = false}) async {
    if (_isFetchingMore) return;
    if (isMore && !_hasMore) return;

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
                        return const SkeletonList(itemCount: 4);
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


}

class _HistoryCard extends StatefulWidget {
  final QueryDocumentSnapshot booking;

  const _HistoryCard({required this.booking});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  String _customerName = 'Loading...';
  bool _hasReview = false;
  String _reviewText = '';
  double _rating = 0.0;
  bool _isLoadingReview = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerName();
    _loadReview();
  }

  void _loadReview() async {
    try {
      final reviewSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('bookingId', isEqualTo: widget.booking.id)
          .limit(1)
          .get();

      if (reviewSnapshot.docs.isNotEmpty) {
        final data = reviewSnapshot.docs.first.data();
        if (mounted) {
          setState(() {
            _hasReview = true;
            _reviewText = data['comment'] ?? '';
            _rating = (data['rating'] as num?)?.toDouble() ?? 5.0;
            _isLoadingReview = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasReview = false;
            _isLoadingReview = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasReview = false;
          _isLoadingReview = false;
        });
      }
    }
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

    final hasReview = _hasReview;
    final reviewText = _reviewText;
    final rating = _rating;

    final rawCost = (booking['finalCost'] as num?) ?? (booking['estimatedCost'] as num?) ?? 0.0;
    final formattedCost = rawCost.toDouble().toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              StatusBadge(
                status: 'completed',
                size: BadgeSize.small,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating.floor() 
                          ? Icons.star 
                          : (index < rating ? Icons.star_half : Icons.star_border),
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
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
