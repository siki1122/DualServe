import 'package:flutter/material.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'booking_screen.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';

class ServiceVariant {
  final String name;
  final String description;
  final double price;
  final String unit;
  ServiceVariant(this.name, this.description, this.price, this.unit);
}

final Map<String, List<ServiceVariant>> householdCategories = {
  'Deep Cleaning': [
    ServiceVariant('Standard Deep Cleaning', 'Complete deep clean', 3500, 'per session'),
  ],
  'Aircon Cleaning': [
    ServiceVariant('Window Type', 'Standard cleaning', 700, 'per unit'),
    ServiceVariant('Split Type', 'Standard cleaning', 1000, 'per unit'),
  ],
  'Mattress Deep Cleaning': [
    ServiceVariant('Single', 'Shampoo & extraction', 600, 'per piece'),
    ServiceVariant('Double', 'Shampoo & extraction', 800, 'per piece'),
    ServiceVariant('Queen/King', 'Shampoo & extraction', 1000, 'per piece'),
  ],
  'Upholstery Deep Cleaning': [
    ServiceVariant('Stool (Bar Stool)', 'Shampoo & extraction', 350, 'per piece'),
    ServiceVariant('Dining Chair', 'Shampoo & extraction', 350, 'per seat'),
    ServiceVariant('Office Chair', 'Deep clean & extraction', 650, 'per chair'),
    ServiceVariant('1-Seater Sofa', 'Full shampoo & extraction', 900, 'per sofa'),
    ServiceVariant('2-Seater Sofa', 'Full shampoo & extraction', 1200, 'per sofa'),
    ServiceVariant('3-Seater Sofa', 'Full shampoo & extraction', 1500, 'per sofa'),
  ],
  'Steaming Only': [
    ServiceVariant('Steaming Service', 'Steam only', 50, 'per item'),
  ],
  'Greasetrap Cleaning': [
    ServiceVariant('Standard Greasetrap', 'Complete clean', 800, 'per unit'),
  ],
  'Vehicle Interior Detailing': [
    ServiceVariant('Sedan', 'Full interior detail', 2800, 'per vehicle'),
    ServiceVariant('SUV', 'Full interior detail', 3500, 'per vehicle'),
  ],
};

class CartItem {
  final String category;
  final ServiceVariant variant;
  int quantity;
  CartItem(this.category, this.variant, this.quantity);
}

class HouseholdServiceSelectionScreen extends StatefulWidget {
  final String? preSelectedProviderId;

  const HouseholdServiceSelectionScreen({
    super.key,
    this.preSelectedProviderId,
  });

  @override
  State<HouseholdServiceSelectionScreen> createState() => _HouseholdServiceSelectionScreenState();
}

class _HouseholdServiceSelectionScreenState extends State<HouseholdServiceSelectionScreen> {
  // Cart items
  List<CartItem> _cart = [];

  double get _totalPrice {
    double total = 0;
    for (var item in _cart) {
      total += item.variant.price * item.quantity;
    }
    return total;
  }

  int get _totalItems {
    int total = 0;
    for (var item in _cart) {
      total += item.quantity;
    }
    return total;
  }

  void _showVariantBottomSheet(String category) {
    final variants = householdCategories[category]!;
    // Track local quantities for this bottom sheet session
    Map<String, int> localQuantities = {};
    for (var item in _cart) {
      if (item.category == category) {
        localQuantities[item.variant.name] = item.quantity;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            double modalTotal = 0;
            variants.forEach((v) {
              int qty = localQuantities[v.name] ?? 0;
              modalTotal += v.price * qty;
            });

            IconData categoryIcon = Icons.cleaning_services;
            if (category.toLowerCase().contains('aircon')) categoryIcon = Icons.ac_unit;
            if (category.toLowerCase().contains('mattress') || category.toLowerCase().contains('upholstery')) categoryIcon = Icons.bed;
            if (category.toLowerCase().contains('vehicle') || category.toLowerCase().contains('car')) categoryIcon = Icons.directions_car;
            if (category.toLowerCase().contains('steam') || category.toLowerCase().contains('greasetrap')) categoryIcon = Icons.air;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                          child: Icon(categoryIcon, color: Colors.grey.shade700),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                              const Text('Select specific options', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Variants List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: variants.length,
                      separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 24),
                      itemBuilder: (context, index) {
                        final variant = variants[index];
                        final qty = localQuantities[variant.name] ?? 0;
                        final isSelected = qty > 0;

                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              if (isSelected) {
                                localQuantities[variant.name] = 0;
                              } else {
                                localQuantities[variant.name] = 1;
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? const Color(0xFF1E2432) : Colors.transparent,
                                    border: Border.all(color: isSelected ? const Color(0xFF1E2432) : Colors.grey.shade300, width: 2),
                                  ),
                                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(variant.name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.black87 : Colors.grey.shade700, fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(variant.description, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₱${variant.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                    Text(variant.unit, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Quantity Editor
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (variants.any((v) => (localQuantities[v.name] ?? 0) > 0)) ...[
                            ...variants.where((v) => (localQuantities[v.name] ?? 0) > 0).map((v) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    Container(
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 16),
                                            onPressed: () {
                                              setModalState(() {
                                                if (localQuantities[v.name]! > 0) {
                                                  localQuantities[v.name] = localQuantities[v.name]! - 1;
                                                }
                                              });
                                            },
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(8),
                                          ),
                                          Text('${localQuantities[v.name]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 16),
                                            onPressed: () {
                                              setModalState(() {
                                                localQuantities[v.name] = (localQuantities[v.name] ?? 0) + 1;
                                              });
                                            },
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: modalTotal > 0 ? () {
                                // Save back to cart
                                setState(() {
                                  _cart.removeWhere((item) => item.category == category);
                                  variants.forEach((v) {
                                    int qty = localQuantities[v.name] ?? 0;
                                    if (qty > 0) {
                                      _cart.add(CartItem(category, v, qty));
                                    }
                                  });
                                });
                                Navigator.pop(context);
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E2432),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: Text(
                                modalTotal > 0 ? 'Add to booking — ₱${modalTotal.toStringAsFixed(0)}' : 'Add to booking', 
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.backgroundDark : AppTheme.background;

    final keys = householdCategories.keys.toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        centerTitle: true,
        title: Text(
          'Household Services',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final category = keys[index];
                    final variants = householdCategories[category]!;
                    final basePrice = variants.map((v) => v.price).reduce((a, b) => a < b ? a : b); // Min price
                    
                    final isSelected = _cart.any((item) => item.category == category);

                    IconData iconData = Icons.cleaning_services;
                    if (category.toLowerCase().contains('aircon')) iconData = Icons.ac_unit;
                    if (category.toLowerCase().contains('mattress') || category.toLowerCase().contains('upholstery')) iconData = Icons.bed;
                    if (category.toLowerCase().contains('vehicle') || category.toLowerCase().contains('car')) iconData = Icons.directions_car;
                    if (category.toLowerCase().contains('steam') || category.toLowerCase().contains('greasetrap')) iconData = Icons.air;

                    return GestureDetector(
                      onTap: () => _showVariantBottomSheet(category),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF0F4F8) : (isDark ? AppTheme.surfaceDark : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1E2432).withValues(alpha: 0.3) : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            width: isSelected ? 1 : 1,
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                iconData, 
                                size: 20, 
                                color: isDark ? Colors.white : Colors.grey.shade700
                              ),
                            ),
                            const Spacer(),
                            Text(
                              category,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : AppTheme.textSlateDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'From ₱${basePrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, 
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Sticky Bottom Floating Bar
          if (_cart.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to Step 2
                      Map<String, int> selectedServicesMap = {};
                      Map<String, double> selectedPricesMap = {};
                      for (var item in _cart) {
                        String key = item.variant.name;
                        selectedServicesMap[key] = item.quantity;
                        selectedPricesMap[key] = item.variant.price;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingScreen(
                            serviceType: 'Household',
                            preSelectedProviderId: widget.preSelectedProviderId,
                            preSelectedSubServices: selectedServicesMap,
                            preSelectedPrices: selectedPricesMap,
                            preSelectedTotalCost: _totalPrice,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2432), // Dark slate blue
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_totalItems items booked',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    // Summarize first item, or just "Tap to continue"
                                    _cart.first.variant.name + (_cart.length > 1 ? '...' : ''),
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            '₱${_totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
