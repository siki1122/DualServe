import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../../models/service_definition_model.dart';
import '../../utils/service_templates.dart';
import '../../services/provider_pricing_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/provider_drawer.dart';

class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  final TextEditingController _serviceController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _nightPercentController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final ProviderPricingService _pricingService = ProviderPricingService();

  Map<String, dynamic> _services = {};
  Map<String, String> _serviceAreas = {};
  bool _isLoading = true;
  bool _useNightDifferential = false;
  String _serviceType = 'Towing';

  int _nightStartHour = 23;
  int _nightEndHour = 5;
  double _nightPercent = 30.0;

  final TextEditingController _categoryController = TextEditingController();

  String? _selectedServiceName;
  
  // Custom service name controller for "Other" option
  final TextEditingController _customServiceController = TextEditingController();

  final List<MapEntry<int, String>> _hourOptions = List.generate(24, (i) {
    final displayHour = i == 0 ? 12 : (i > 12 ? i - 12 : i);
    final period = i >= 12 ? 'PM' : 'AM';
    return MapEntry(i, '$displayHour:00 $period');
  });

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _nightPercentController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final doc = await _firestore.collection('providers').doc(_uid).get();
      final pricing = await _pricingService.getProviderPricing(_uid);
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final servicesData = data['offeredServices'] as Map<String, dynamic>? ?? {};
        final areasData = data['serviceAreas'] as Map<String, dynamic>? ?? {};
        final areaData = data['serviceArea'] as String? ?? 'All Areas';
        setState(() {
          _services = servicesData;
          _serviceAreas = areasData.map((key, value) => MapEntry(key, value.toString()));
          _serviceType = data['serviceType'] as String? ?? 'Towing';
          _useNightDifferential = pricing.useNightDifferential;
          _nightStartHour = pricing.nightSurchargeStartHour;
          _nightEndHour = pricing.nightSurchargeEndHour;
          _nightPercent = pricing.nightSurchargePercent;
          _nightPercentController.text = pricing.nightSurchargePercent.toStringAsFixed(0);
          _isLoading = false;
        });
      } else {
        setState(() {
          _useNightDifferential = pricing.useNightDifferential;
          _nightStartHour = pricing.nightSurchargeStartHour;
          _nightEndHour = pricing.nightSurchargeEndHour;
          _nightPercent = pricing.nightSurchargePercent;
          _nightPercentController.text = pricing.nightSurchargePercent.toStringAsFixed(0);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    final percentStr = _nightPercentController.text.trim();
    final percent = double.tryParse(percentStr) ?? 30.0;

    setState(() => _isLoading = true);

    try {
      // Save night surcharge settings on provider pricing
      await _pricingService.updateProviderPricing(
        providerId: _uid,
        useNightDifferential: _useNightDifferential,
        nightSurchargeStartHour: _nightStartHour,
        nightSurchargeEndHour: _nightEndHour,
        nightSurchargePercent: percent,
      );

      setState(() {
        _nightPercent = percent;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addService() async {
    final service = _selectedServiceName == 'Other' 
        ? _customServiceController.text.trim() 
        : (_selectedServiceName ?? '');
    
    final priceStr = _priceController.text.trim();
    final area = _areaController.text.trim();
    
    if (service.isEmpty || priceStr.isEmpty) return;
    
    // Use manual category input or fallback to Other
    final categoryStr = _categoryController.text.trim();
    final category = categoryStr.isEmpty ? 'Other' : categoryStr;

    final price = double.tryParse(priceStr);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid price')));
      return;
    }

    setState(() {
      if (ServiceTemplates.defaultTemplates.containsKey(service)) {
        final template = ServiceTemplates.defaultTemplates[service]!;
        if (template.type == ServicePricingType.areaBased) {
          _services[service] = ServiceDefinition(
            type: template.type,
            minPrice: price,
            pricePerSqm: template.pricePerSqm,
            minSqm: template.minSqm,
            addons: template.addons,
            category: category,
          ).toMap();
        } else if (template.type == ServicePricingType.subtypeBased) {
          final mapped = template.toMap();
          mapped['category'] = category;
          _services[service] = mapped;
        } else {
          _services[service] = ServiceDefinition(
            type: ServicePricingType.flatRate,
            flatRatePrice: price,
            category: category,
          ).toMap();
        }
      } else {
        _services[service] = ServiceDefinition(
          type: ServicePricingType.flatRate,
          flatRatePrice: price,
          category: category,
        ).toMap();
      }
      _serviceAreas[service] = area.isNotEmpty ? area : 'All Areas';
      _selectedServiceName = null;
      _customServiceController.clear();
      _priceController.clear();
      _areaController.clear();
      _categoryController.clear();
    });

    await _updateFirestore();
  }

  Future<void> _removeService(String service) async {
    setState(() {
      _services.remove(service);
      _serviceAreas.remove(service);
    });
    await _updateFirestore();
  }

  Future<void> _editService(String serviceName, Map<String, dynamic>? currentDef, double? currentPrice) async {
    final TextEditingController editPriceController = TextEditingController(text: currentPrice?.toStringAsFixed(2) ?? '');
    final TextEditingController editAreaController = TextEditingController(text: _serviceAreas[serviceName] ?? '');
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $serviceName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price', prefixText: '₱ '),
              ),
              TextField(
                controller: editAreaController,
                decoration: const InputDecoration(labelText: 'Service Area'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final newPrice = double.tryParse(editPriceController.text.trim());
                if (newPrice != null) {
                  setState(() {
                    if (currentDef != null) {
                       final def = ServiceDefinition.fromMap(currentDef);
                       if (def.type == ServicePricingType.areaBased) {
                         _services[serviceName] = ServiceDefinition(
                           type: def.type,
                           minPrice: newPrice,
                           pricePerSqm: def.pricePerSqm,
                           minSqm: def.minSqm,
                           addons: def.addons,
                           subtypes: def.subtypes,
                           category: def.category,
                         ).toMap();
                       } else {
                         _services[serviceName] = ServiceDefinition(
                           type: def.type,
                           flatRatePrice: newPrice,
                           minPrice: def.minPrice,
                           pricePerSqm: def.pricePerSqm,
                           minSqm: def.minSqm,
                           addons: def.addons,
                           subtypes: def.subtypes,
                           category: def.category,
                         ).toMap();
                       }
                    } else {
                       _services[serviceName] = newPrice;
                    }
                    _serviceAreas[serviceName] = editAreaController.text.trim();
                  });
                  _updateFirestore();
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateFirestore() async {
    await _firestore.collection('providers').doc(_uid).update({
      'offeredServices': _services,
      'serviceAreas': _serviceAreas,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      drawer: const ProviderDrawer(),
      appBar: AppBar(
        title: Text('My Services', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark)),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppTheme.textSlateDark,
        elevation: 0,
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(20.0),
              child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What services do you provide?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textSlateDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add services and set your rates.',
                    style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _categoryController,
                                style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                                decoration: AppTheme.textFieldDecoration(
                                  label: 'Category',
                                  hint: 'e.g. Deep Cleaning, Aircon',
                                  prefixIcon: Icons.category_outlined,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedServiceName,
                                isExpanded: true,
                                style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                                dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
                                decoration: AppTheme.textFieldDecoration(
                                  label: 'Service Name',
                                  prefixIcon: Icons.handyman,
                                  isDark: isDark,
                                ),
                                items: [
                                  ...ServiceTemplates.defaultTemplates.keys.map((String service) {
                                    return DropdownMenuItem<String>(
                                      value: service,
                                      child: Text(service),
                                    );
                                  }),
                                  const DropdownMenuItem<String>(
                                    value: 'Other',
                                    child: Text('Custom Service (Other)'),
                                  ),
                                ],
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedServiceName = newValue;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                                decoration: AppTheme.textFieldDecoration(
                                  label: 'Price',
                                  prefixIcon: Icons.payments_outlined,
                                  isDark: isDark,
                                ).copyWith(prefixText: '₱ '),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedServiceName == 'Other') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customServiceController,
                                  style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                                  decoration: AppTheme.textFieldDecoration(
                                    label: 'Custom Service Name',
                                    hint: 'e.g. Lawn Mowing',
                                    prefixIcon: Icons.edit_outlined,
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _areaController,
                                style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                                decoration: AppTheme.textFieldDecoration(
                                  label: 'Service Availability Area',
                                  hint: 'Pasig, Quezon City (blank for All Areas)',
                                  prefixIcon: Icons.location_on_outlined,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _addService,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _services.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.miscellaneous_services_outlined, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No services added yet',
                                  style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _services.length,
                          itemBuilder: (context, index) {
                            final serviceName = _services.keys.elementAt(index);
                            final rawPrice = _services[serviceName];
                            double? displayPrice;
                            String priceLabel = '';
                            String? categoryLabel;

                            if (rawPrice is num) {
                              displayPrice = rawPrice.toDouble();
                              priceLabel = '₱${displayPrice.toStringAsFixed(2)}';
                            } else if (rawPrice is Map) {
                              final def = ServiceDefinition.fromMap(Map<String, dynamic>.from(rawPrice));
                              displayPrice = def.flatRatePrice ?? def.minPrice ?? 0.0;
                              categoryLabel = def.category;
                              if (def.type == ServicePricingType.areaBased) {
                                priceLabel = 'Starts at ₱${displayPrice.toStringAsFixed(2)}';
                              } else if (def.type == ServicePricingType.subtypeBased) {
                                priceLabel = 'Varies by type';
                              } else {
                                priceLabel = '₱${displayPrice.toStringAsFixed(2)}';
                              }
                            }

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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppTheme.textSlateDark,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (categoryLabel != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          categoryLabel,
                                          style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      priceLabel,
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined, size: 12, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Available in: ${_serviceAreas[serviceName] ?? "All Areas"}',
                                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
                                      onPressed: () => _editService(serviceName, rawPrice is Map ? Map<String, dynamic>.from(rawPrice) : null, displayPrice),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _removeService(serviceName),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  if (_serviceType == 'Towing') ...[
                    const SizedBox(height: 24),
                    Text(
                      'Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textSlateDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.cardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Night Surcharge',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.textSlateDark,
                                  ),
                                ),
                                Text(
                                  _useNightDifferential
                                      ? '${_hourOptions.firstWhere((e) => e.key == _nightStartHour).value} - ${_hourOptions.firstWhere((e) => e.key == _nightEndHour).value} (+${_nightPercent.toStringAsFixed(0)}%)'
                                      : 'Disabled',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textDarkSecondary : Colors.grey),
                                ),
                              ],
                            ),
                            Switch(
                              value: _useNightDifferential,
                              onChanged: (val) {
                                setState(() {
                                  _useNightDifferential = val;
                                });
                              },
                              activeThumbColor: AppTheme.primaryBlue,
                            ),
                          ],
                        ),
                        if (_useNightDifferential) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Starts At', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _nightStartHour,
                                          isExpanded: true,
                                          dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _nightStartHour = val);
                                            }
                                          },
                                          items: _hourOptions.map((e) {
                                            return DropdownMenuItem<int>(
                                              value: e.key,
                                              child: Text(e.value, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppTheme.textSlateDark)),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Ends At', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _nightEndHour,
                                          isExpanded: true,
                                          dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _nightEndHour = val);
                                            }
                                          },
                                          items: _hourOptions.map((e) {
                                            return DropdownMenuItem<int>(
                                              value: e.key,
                                              child: Text(e.value, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppTheme.textSlateDark)),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nightPercentController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
                            decoration: AppTheme.textFieldDecoration(
                              label: 'Night Surcharge Rate (%)',
                              prefixIcon: Icons.percent,
                              isDark: isDark,
                            ),
                          ),
                        ],
                          const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _savePreferences,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],
                ],
              ),
            ),
    );
  }
}
