import 'package:flutter/material.dart';
import '../../models/service_definition_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/service_templates.dart';

class ComplexServiceSheet extends StatefulWidget {
  final String serviceName;
  final ServiceDefinition serviceDef;
  final Map<String, dynamic>? initialDetails;

  const ComplexServiceSheet({
    super.key,
    required this.serviceName,
    required this.serviceDef,
    this.initialDetails,
  });

  @override
  State<ComplexServiceSheet> createState() => _ComplexServiceSheetState();
}

class _ComplexServiceSheetState extends State<ComplexServiceSheet> {
  late Map<String, dynamic> _details;

  @override
  void initState() {
    super.initState();
    _details = widget.initialDetails != null 
        ? Map<String, dynamic>.from(widget.initialDetails!) 
        : {};
        
    if (widget.serviceDef.type == ServicePricingType.areaBased) {
      if (!_details.containsKey('sqm')) _details['sqm'] = 0.0;
      if (!_details.containsKey('addons')) _details['addons'] = <String>[];
    }
  }

  void _saveAndClose() {
    Navigator.pop(context, _details);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDark : AppTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.serviceName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textSlateDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.serviceDef.type == ServicePricingType.areaBased)
            _buildAreaBasedContent(isDark)
          else if (widget.serviceDef.type == ServicePricingType.subtypeBased)
            _buildSubtypeBasedContent(isDark),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saveAndClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Confirm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaBasedContent(bool isDark) {
    final minPrice = widget.serviceDef.minPrice ?? 0.0;
    final pricePerSqm = widget.serviceDef.pricePerSqm ?? 0.0;
    final minSqm = widget.serviceDef.minSqm ?? 0;

    double currentSqm = (_details['sqm'] as num).toDouble();
    List<String> selectedAddons = List<String>.from(_details['addons'] as List);

    double calculatedBase = minPrice;
    if (currentSqm > minSqm) {
      calculatedBase = currentSqm * pricePerSqm;
      if (calculatedBase < minPrice) calculatedBase = minPrice;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AREA SIZE',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: currentSqm == 0 ? '' : currentSqm.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _details['sqm'] = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('sqm', style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Min ₱${minPrice.toStringAsFixed(0)} · ₱${pricePerSqm.toStringAsFixed(0)}/sqm for ${minSqm}sqm+',
                style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Base rate', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
                    const SizedBox(height: 4),
                    Text(
                      '₱${calculatedBase.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark),
                    ),
                    const SizedBox(height: 2),
                    Text('Minimum rate applies', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.serviceDef.addons != null && widget.serviceDef.addons!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'ADD-ONS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Column(
              children: widget.serviceDef.addons!.map((addon) {
                final isSelected = selectedAddons.contains(addon.name);
                final isFixed = addon.pricingType == 'fixed';
                int qty = (_details['addon_qty_${addon.name}'] as num?)?.toInt() ?? 1;

                return Column(
                  children: [
                    CheckboxListTile(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedAddons.add(addon.name);
                            if (!isFixed) _details['addon_qty_${addon.name}'] = 1;
                          } else {
                            selectedAddons.remove(addon.name);
                            _details.remove('addon_qty_${addon.name}');
                          }
                          _details['addons'] = selectedAddons;
                        });
                      },
                      title: Text(addon.name, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppTheme.textSlateDark)),
                      subtitle: Text(
                        isFixed ? '₱${addon.price.toStringAsFixed(0)}' : '₱${addon.price.toStringAsFixed(0)} ${addon.pricingType == 'per_hour' ? '/ hr' : '/ unit'}',
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppTheme.primaryBlue,
                    ),
                    if (isSelected && !isFixed)
                      Padding(
                        padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
                        child: Row(
                          children: [
                            Text('Quantity:', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
                            const Spacer(),
                            _buildQtyButton(Icons.remove, () {
                              if (qty > 1) {
                                setState(() => _details['addon_qty_${addon.name}'] = qty - 1);
                              }
                            }, isDark),
                            SizedBox(
                              width: 32,
                              child: Text(
                                qty.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark),
                              ),
                            ),
                            _buildQtyButton(Icons.add, () {
                              setState(() => _details['addon_qty_${addon.name}'] = qty + 1);
                            }, isDark),
                          ],
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubtypeBasedContent(bool isDark) {
    if (widget.serviceDef.subtypes == null || widget.serviceDef.subtypes!.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT TYPE & QUANTITY',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            children: widget.serviceDef.subtypes!.map((subtype) {
              int qty = (_details[subtype.name] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subtype.name, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppTheme.textSlateDark)),
                          const SizedBox(height: 4),
                          Text('₱${subtype.price.toStringAsFixed(0)}/unit', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _buildQtyButton(Icons.remove, () {
                          if (qty > 0) {
                            setState(() => _details[subtype.name] = qty - 1);
                          }
                        }, isDark),
                        SizedBox(
                          width: 32,
                          child: Text(
                            qty.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark),
                          ),
                        ),
                        _buildQtyButton(Icons.add, () {
                          setState(() => _details[subtype.name] = qty + 1);
                        }, isDark),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Icon(icon, size: 20, color: isDark ? Colors.white : AppTheme.textSlateDark),
      ),
    );
  }
}
