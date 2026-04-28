import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/dashboard_page.dart';
import 'pages/users_page.dart';
import 'pages/providers_page.dart';
import 'pages/assets_page.dart';
import 'pages/reports_page.dart';
import 'pages/task_assignment_page.dart';
import 'pages/transactions_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            color: const Color(0xFF1a1f3a),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF0f1429),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: Colors.white.withValues(alpha: 0.1)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _sidebarItem(0, Icons.dashboard, 'Dashboard'),
                      _sidebarItem(1, Icons.people, 'Users'),
                      _sidebarItem(2, Icons.handshake, 'Providers'),
                      _sidebarItem(3, Icons.local_shipping, 'Assets'),
                      _sidebarItem(
                        4,
                        Icons.assignment_turned_in,
                        'Task Management',
                      ),
                      _sidebarItem(5, Icons.assessment, 'Reports'),
                      _sidebarItem(6, Icons.receipt_long, 'Transactions'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getPageTitle(_selectedIndex),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'DualServ Administration',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _auth.currentUser?.email ?? 'Admin',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Admin User',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Pages
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: const [
                      DashboardPage(),
                      UsersPage(),
                      ProvidersPage(),
                      AssetsPage(),
                      TaskAssignmentScreen(),
                      ReportsPage(),
                      TransactionsPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: isSelected
          ? BoxDecoration(
              color: const Color(0xFF2563eb),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPageTitle(int index) {
    const titles = [
      'Dashboard',
      'Users',
      'Providers',
      'Assets',
      'Task Management',
      'Reports',
      'Transactions',
    ];
    return titles[index];
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
      }
    }
  }
}
