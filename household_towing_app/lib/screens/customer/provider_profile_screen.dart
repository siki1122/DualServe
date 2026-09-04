import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/provider_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/screens/customer/household_service_selection_screen.dart';
import 'booking_screen.dart';


class ProviderProfileScreen extends StatefulWidget {
  final String providerId;

  const ProviderProfileScreen({super.key, required this.providerId});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Provider? _provider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchProvider();
  }

  Future<void> _fetchProvider() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('providers').doc(widget.providerId).get();
      if (doc.exists) {
        setState(() {
          _provider = Provider.fromFirestore(doc);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    if (_provider == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text("Provider not found.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250.0,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.primaryBlue,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  _provider!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.8),
                    ),
                    if (_provider!.profileImageUrl.isNotEmpty)
                      Image.network(
                        _provider!.profileImageUrl,
                        fit: BoxFit.cover,
                        color: AppTheme.textSlateDark.withValues(alpha: 0.3),
                        colorBlendMode: BlendMode.darken,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    Positioned(
                      bottom: 85, // Moved up to prevent overlap with the AppBar title
                      left: 20,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            backgroundImage: _provider!.profileImageUrl.isNotEmpty
                                ? NetworkImage(_provider!.profileImageUrl)
                                : null,
                            child: _provider!.profileImageUrl.isEmpty
                                ? const Icon(Icons.person, size: 40, color: AppTheme.textSlateMedium)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _provider!.specialty,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _provider!.totalReviews == 0 ? '0.0' : _provider!.rating.toStringAsFixed(1),
                                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const Text(
                                    ' Rating',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryBlue,
                  unselectedLabelColor: AppTheme.textSlateMedium,
                  indicatorColor: AppTheme.primaryBlue,
                  tabs: const [
                    Tab(text: "Overview"),
                    Tab(text: "Credentials"),
                    Tab(text: "Reviews"),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildCredentialsTab(),
            _buildReviewsTab(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: AppTheme.textSlateDark.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () {
              if (_provider!.serviceType.toLowerCase() == 'household' || _provider!.serviceType.toLowerCase() == 'cleaning') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HouseholdServiceSelectionScreen(
                      preSelectedProviderId: _provider!.id,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingScreen(
                      serviceType: _provider!.serviceType,
                      preSelectedProviderId: _provider!.id,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Book This Provider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
        const SizedBox(height: 12),
        Text(
          _provider!.bio.isNotEmpty ? _provider!.bio : "This provider has not added a bio yet.",
          style: const TextStyle(color: AppTheme.textSlateMedium, height: 1.5),
        ),
        const SizedBox(height: 24),
        const Text("Statistics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.check_circle_outline, _provider!.jobsCompleted.toString(), "Jobs Completed")),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(Icons.access_time, "${_provider!.yearsOfExperience}", "Years Experience")),
          ],
        ),
        const SizedBox(height: 24),
        const Text("Services Offered", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (_provider!.offeredServices.isNotEmpty 
              ? _provider!.offeredServices.keys.toList() 
              : _provider!.serviceTypes).map((service) {
            return Chip(
              label: Text(service),
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
              side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
              labelStyle: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDynamicImage(String url) {
    if (url.startsWith('data:image/')) {
      final base64Str = url.split(',').last;
      return Image.memory(base64Decode(base64Str), height: 150, width: double.infinity, fit: BoxFit.cover);
    }
    return Image.network(url, height: 150, width: double.infinity, fit: BoxFit.cover);
  }

  Widget _buildCredentialsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_provider!.businessPermitUrl != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Business Permit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textSlateDark)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildDynamicImage(_provider!.businessPermitUrl!),
              ),
              const SizedBox(height: 24),
            ],
          ),
        if (_provider!.governmentIdUrl != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Government ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textSlateDark)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildDynamicImage(_provider!.governmentIdUrl!),
              ),
              const SizedBox(height: 24),
            ],
          ),
      ],
    );
  }

  Widget _buildCredentialItem(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textSlateDark)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSlateMedium, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('providerId', isEqualTo: widget.providerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading reviews: \${snapshot.error}'));
        }
        var reviews = snapshot.data?.docs ?? [];
        if (reviews.isEmpty) {
          return const Center(child: Text("No reviews yet."));
        }
        
        // Sort reviews in memory by createdAt descending
        reviews.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bTime.compareTo(aTime); // Descending order
        });
        
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: reviews.length,
          separatorBuilder: (context, index) => const Divider(height: 32),
          itemBuilder: (context, index) {
            final data = reviews[index].data() as Map<String, dynamic>;
            return _ReviewItem(reviewData: data);
          },
        );
      },
    );
  }
}

class _ReviewItem extends StatefulWidget {
  final Map<String, dynamic> reviewData;
  const _ReviewItem({required this.reviewData});

  @override
  State<_ReviewItem> createState() => _ReviewItemState();
}

class _ReviewItemState extends State<_ReviewItem> {
  String _customerName = "Customer";
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomerName();
  }

  Future<void> _fetchCustomerName() async {
    if (widget.reviewData['customerName'] != null) {
      setState(() {
        _customerName = widget.reviewData['customerName'];
        _isLoadingName = false;
      });
      return;
    }
    
    final customerId = widget.reviewData['customerId'] as String?;
    if (customerId != null && customerId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(customerId).get();
        if (doc.exists) {
          setState(() {
            _customerName = doc.data()?['name'] ?? "Customer";
            _isLoadingName = false;
          });
          return;
        }
      } catch (e) {
        // ignore
      }
    }
    setState(() {
      _isLoadingName = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rating = (widget.reviewData['rating'] as num?)?.toDouble() ?? 5.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.textSlateLight.withValues(alpha: 0.5),
              child: const Icon(Icons.person, color: AppTheme.textSlateMedium),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _isLoadingName 
                      ? const SizedBox(
                          height: 14, 
                          width: 80, 
                          child: CircularProgressIndicator(strokeWidth: 2)
                        )
                      : Text(_customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: List.generate(5, (starIndex) {
                      return Icon(
                        starIndex < rating.floor() ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 14,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(widget.reviewData['comment'] ?? '', style: const TextStyle(color: AppTheme.textSlateDark, height: 1.4)),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
