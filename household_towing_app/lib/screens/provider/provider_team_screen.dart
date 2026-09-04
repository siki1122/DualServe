import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/driver_model.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class ProviderTeamScreen extends StatefulWidget {
  const ProviderTeamScreen({super.key});

  @override
  State<ProviderTeamScreen> createState() => _ProviderTeamScreenState();
}

class _ProviderTeamScreenState extends State<ProviderTeamScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _providerId;
  String _inviteCode = '';

  @override
  void initState() {
    super.initState();
    _providerId = FirebaseAuth.instance.currentUser!.uid;
    _loadInviteCode();
  }

  Future<void> _loadInviteCode() async {
    final doc = await _firestore.collection('providers').doc(_providerId).get();
    if (doc.exists) {
      final code = doc.data()?['inviteCode'] as String? ?? '';
      if (code.isEmpty) {
        // Generate a new code
        final newCode = _providerId.substring(0, 6).toUpperCase();
        await _firestore.collection('providers').doc(_providerId).update({
          'inviteCode': newCode,
        });
        setState(() => _inviteCode = newCode);
      } else {
        setState(() => _inviteCode = code);
      }
    }
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: _inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProvider>().providerProfile;
    final isHousehold = profile?['serviceType'] == 'Household';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Team', style: TextStyle(color: AppTheme.textSlateDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textSlateDark),
      ),
      body: Column(
        children: [
          _buildInviteCodeSection(isHousehold),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('drivers')
                  .where('providerId', isEqualTo: _providerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(isHousehold ? 'No personnel have joined your team yet.' : 'No drivers have joined your team yet.', style: const TextStyle(color: AppTheme.textSlateMedium)),
                  );
                }

                final drivers = snapshot.data!.docs.map((doc) => Driver.fromFirestore(doc)).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: AppTheme.primaryBlue),
                        ),
                        title: Text(driver.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(driver.phone),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(driver.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            driver.status.name.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(driver.status),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeSection(bool isHousehold) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHousehold ? 'Invite Personnel to Your Team' : 'Invite Drivers to Your Team',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with your ${isHousehold ? 'personnel' : 'drivers'}. They can enter it when registering for the app to join your company.',
            style: TextStyle(color: AppTheme.textSlateMedium),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      _inviteCode.isEmpty ? 'LOADING...' : _inviteCode,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _copyInviteCode,
                icon: const Icon(Icons.copy, color: AppTheme.primaryBlue),
                tooltip: 'Copy Code',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return AppTheme.statusCompletedText;
      case DriverStatus.busy:
        return AppTheme.towingOrange;
      case DriverStatus.offline:
        return AppTheme.textSlateMedium;
    }
  }
}
