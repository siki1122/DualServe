import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';

class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  final TextEditingController _serviceController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  Map<String, double> _services = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final doc = await _firestore.collection('providers').doc(_uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final servicesData = data['offeredServices'] as Map<String, dynamic>? ?? {};
        setState(() {
          _services = servicesData.map((key, value) => MapEntry(key, (value as num).toDouble()));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addService() async {
    final service = _serviceController.text.trim();
    final priceStr = _priceController.text.trim();
    
    if (service.isEmpty || priceStr.isEmpty) return;

    final price = double.tryParse(priceStr);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid price')));
      return;
    }

    setState(() {
      _services[service] = price;
      _serviceController.clear();
      _priceController.clear();
    });

    await _updateFirestore();
  }

  Future<void> _removeService(String service) async {
    setState(() {
      _services.remove(service);
    });
    await _updateFirestore();
  }

  Future<void> _updateFirestore() async {
    await _firestore.collection('providers').doc(_uid).update({
      'offeredServices': _services,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Services', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textSlateDark,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What services do you provide?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSlateDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add services and set your rates.',
                    style: TextStyle(color: AppTheme.textSlateMedium, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _serviceController,
                          decoration: InputDecoration(
                            hintText: 'Service (e.g. Flatbed)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Price',
                            prefixText: '₱',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _services.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.miscellaneous_services_outlined, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                const Text(
                                  'No services added yet',
                                  style: TextStyle(color: AppTheme.textSlateMedium),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _services.length,
                            itemBuilder: (context, index) {
                              final serviceName = _services.keys.elementAt(index);
                              final price = _services[serviceName];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: AppTheme.cardDecoration(context),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppTheme.householdBlue,
                                    child: Icon(Icons.check, color: Colors.white, size: 18),
                                  ),
                                  title: Text(
                                    serviceName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '₱${price?.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _removeService(serviceName),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
