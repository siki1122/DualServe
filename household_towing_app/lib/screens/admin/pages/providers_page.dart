import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/stat_card.dart';

class ProvidersPage extends StatefulWidget {
  const ProvidersPage({super.key});

  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _providerSearch = '';
  String _providerTypeFilter = 'All Types';
  final String _providerStatusFilter = 'All Status';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              tabs: [
                Tab(text: 'Active Providers'),
                Tab(text: 'Pending Approvals'),
              ],
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildProvidersList(isApproved: true),
                _buildProvidersList(isApproved: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersList({required bool isApproved}) {
    // We get ALL providers and filter in Dart to handle missing 'isApproved' fields gracefully
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('providers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 1. FILTER BY APPROVAL STATUS (Handling missing fields)
        var providers =
            snapshot.data?.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final bool docApproved =
                  data['isApproved'] ?? true; // Default to true for old docs
              return docApproved == isApproved;
            }).toList() ??
            [];

        // 2. CALCULATE STATS
        int total = providers.length;
        int available = providers
            .where((doc) => doc['status'] == 'available')
            .length;
        int busy = providers.where((doc) => doc['status'] == 'busy').length;

        double avgRating = 0;
        if (total > 0) {
          double sum = 0;
          for (var p in providers) {
            sum += (p['rating'] as num?)?.toDouble() ?? 0;
          }
          avgRating = sum / total;
        }

        // 3. APPLY SEARCH AND UI FILTERS
        if (_providerSearch.isNotEmpty) {
          providers = providers.where((doc) {
            final name = (doc['name'] ?? '').toString().toLowerCase();
            final email = (doc['email'] ?? '').toString().toLowerCase();
            final search = _providerSearch.toLowerCase();
            return name.contains(search) || email.contains(search);
          }).toList();
        }

        if (_providerTypeFilter != 'All Types') {
          providers = providers
              .where((doc) => doc['serviceType'] == _providerTypeFilter)
              .toList();
        }

        if (_providerStatusFilter != 'All Status') {
          providers = providers
              .where(
                (doc) => doc['status'] == _providerStatusFilter.toLowerCase(),
              )
              .toList();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stat Cards
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: isApproved ? 'Active' : 'Pending',
                      value: '$total',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: 'Available',
                      value: '$available',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: 'Busy',
                      value: '$busy',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: 'Avg Rating',
                      value: '${avgRating.toStringAsFixed(1)} ⭐',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Table Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isApproved
                              ? 'Active Service Providers'
                              : 'Pending Approvals',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${providers.length}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search and Filters
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) =>
                                setState(() => _providerSearch = v),
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildFilterDropdown(
                          'All Types',
                          ['All Types', 'Household', 'Towing'],
                          _providerTypeFilter,
                          (v) => setState(() => _providerTypeFilter = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // The Table
                    if (providers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_off_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No providers found in this category',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('Provider')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Rating')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: providers
                              .map(
                                (p) => DataRow(
                                  cells: [
                                    DataCell(
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['name'] ?? 'N/A',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            p['email'] ?? 'N/A',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(p['serviceType'] ?? 'N/A')),
                                    DataCell(
                                      Text(
                                        p['status']?.toString().toUpperCase() ??
                                            'OFFLINE',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '⭐ ${p['rating']?.toStringAsFixed(1) ?? '5.0'}',
                                      ),
                                    ),
                                    DataCell(
                                      isApproved
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            )
                                          : ElevatedButton(
                                              onPressed: () =>
                                                  _approveProvider(p.id),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                              ),
                                              child: const Text(
                                                'Approve',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterDropdown(
    String label,
    List<String> items,
    String value,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _approveProvider(String uid) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve Provider?'),
          content: const Text(
            'This will grant them access to the provider dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(uid), {
        'role': 'provider',
      });
      batch.update(_firestore.collection('providers').doc(uid), {
        'isApproved': true,
        'status': 'available',
      });
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Provider Approved!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve provider: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
