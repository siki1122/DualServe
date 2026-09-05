import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:household_towing_app/utils/app_theme.dart';

class CustomDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool Function(DateTime)? selectableDayPredicate;

  const CustomDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.selectableDayPredicate,
  });

  @override
  State<CustomDatePickerDialog> createState() => _CustomDatePickerDialogState();
}

class _CustomDatePickerDialogState extends State<CustomDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  int get _daysInMonth {
    final nextMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    return nextMonth.day;
  }

  int get _firstDayOffset {
    // 1 for Monday, 7 for Sunday
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    // We want Sunday = 0
    return firstDay == 7 ? 0 : firstDay;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Build years list
    final years = <int>[];
    for (int y = widget.firstDate.year; y <= widget.lastDate.year; y++) {
      years.add(y);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildDropdown<String>(
                            value: _months[_displayedMonth.month - 1],
                            items: _months,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _displayedMonth = DateTime(_displayedMonth.year, _months.indexOf(val) + 1);
                                });
                              }
                            },
                            isDark: isDark,
                          ),
                          _buildDropdown<int>(
                            value: _displayedMonth.year,
                            items: years,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _displayedMonth = DateTime(val, _displayedMonth.month);
                                });
                              }
                            },
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Stylized Calendar Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.8),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Container(width: 6, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 4)),
                            Container(width: 6, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 4)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _selectedDate.day.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Weekdays Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((day) {
                return SizedBox(
                  width: 32,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: day == 'SUN' ? AppTheme.primaryBlue : (isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Calendar Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 42, // 6 weeks
              itemBuilder: (context, index) {
                final dayOffset = index - _firstDayOffset;
                if (dayOffset < 0 || dayOffset >= _daysInMonth) {
                  return const SizedBox();
                }
                
                final date = DateTime(_displayedMonth.year, _displayedMonth.month, dayOffset + 1);
                
                // Truncate time for comparison
                final normalizedDate = DateTime(date.year, date.month, date.day);
                final normalizedFirstDate = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
                final normalizedLastDate = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
                
                bool isSelectable = !normalizedDate.isBefore(normalizedFirstDate) && !normalizedDate.isAfter(normalizedLastDate);
                if (isSelectable && widget.selectableDayPredicate != null) {
                  isSelectable = widget.selectableDayPredicate!(normalizedDate);
                }
                final isSelected = _selectedDate.year == date.year && _selectedDate.month == date.month && _selectedDate.day == date.day;
                
                return InkWell(
                  onTap: isSelectable ? () {
                    setState(() {
                      _selectedDate = date;
                    });
                  } : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: isSelected ? const Border(bottom: BorderSide(color: AppTheme.primaryBlue, width: 2)) : null,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : (isSelectable
                                  ? (isDark ? Colors.white : AppTheme.textSlateDark)
                                  : (isDark ? Colors.white30 : Colors.grey.shade300)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(_selectedDate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3342) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
          dropdownColor: isDark ? AppTheme.cardDark : Colors.white,
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textSlateDark,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
