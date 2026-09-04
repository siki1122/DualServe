import 'package:flutter/material.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'dart:math' as math;

class CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const CustomTimePickerDialog({
    super.key,
    required this.initialTime,
  });

  @override
  State<CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<CustomTimePickerDialog> {
  late int _hour;
  late int _minute;
  late String _period; // 'AM' or 'PM'

  final List<int> _hours = List.generate(12, (i) => i == 0 ? 12 : i);
  final List<int> _minutes = List.generate(60, (i) => i);
  final List<String> _periods = ['AM', 'PM'];

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hourOfPeriod;
    if (_hour == 0) _hour = 12; // Handle midnight/noon
    _minute = widget.initialTime.minute;
    _period = widget.initialTime.period == DayPeriod.am ? 'AM' : 'PM';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Center(
              child: Text(
                'Set Time',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textSlateDark,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Analog Clock
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF2D3342) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    spreadRadius: -2,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : const Color(0xFF333333),
                  width: 12,
                ),
              ),
              child: CustomPaint(
                painter: ClockPainter(
                  hour: _hour,
                  minute: _minute,
                  isDark: isDark,
                  primaryColor: AppTheme.primaryBlue,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Selectors
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDropdown<int>(
                  value: _hour,
                  items: _hours,
                  onChanged: (val) => setState(() => _hour = val!),
                  isDark: isDark,
                  format: (v) => v.toString().padLeft(2, '0'),
                ),
                _buildDropdown<int>(
                  value: _minute,
                  items: _minutes,
                  onChanged: (val) => setState(() => _minute = val!),
                  isDark: isDark,
                  format: (v) => v.toString().padLeft(2, '0'),
                ),
                _buildDropdown<String>(
                  value: _period,
                  items: _periods,
                  onChanged: (val) => setState(() => _period = val!),
                  isDark: isDark,
                  format: (v) => v,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Set Time Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  int finalHour = _hour;
                  if (_period == 'PM' && finalHour != 12) {
                    finalHour += 12;
                  } else if (_period == 'AM' && finalHour == 12) {
                    finalHour = 0;
                  }
                  Navigator.of(context).pop(TimeOfDay(hour: finalHour, minute: _minute));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Set Time',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Cancel Button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 14,
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
    required String Function(T) format,
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
                format(item),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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

class ClockPainter extends CustomPainter {
  final int hour;
  final int minute;
  final bool isDark;
  final Color primaryColor;

  ClockPainter({
    required this.hour,
    required this.minute,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw ticks
    final tickPaint = Paint()
      ..color = isDark ? Colors.grey.shade600 : Colors.grey.shade400
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      final angle = i * 6 * math.pi / 180;
      final isHourTick = i % 5 == 0;
      final tickLength = isHourTick ? 12.0 : 6.0;
      final innerRadius = radius - tickLength - 4;
      final outerRadius = radius - 4;
      
      tickPaint.strokeWidth = isHourTick ? 3.0 : 1.5;
      tickPaint.color = isHourTick 
          ? (isDark ? Colors.white70 : Colors.black87)
          : (isDark ? Colors.grey.shade700 : Colors.grey.shade400);

      canvas.drawLine(
        Offset(center.dx + innerRadius * math.cos(angle), center.dy + innerRadius * math.sin(angle)),
        Offset(center.dx + outerRadius * math.cos(angle), center.dy + outerRadius * math.sin(angle)),
        tickPaint,
      );
    }

    // Draw hands
    final hourAngle = ((hour % 12) + minute / 60) * 30 * math.pi / 180 - math.pi / 2;
    final minuteAngle = minute * 6 * math.pi / 180 - math.pi / 2;
    
    // Minute hand
    final minutePaint = Paint()
      ..color = isDark ? Colors.white : Colors.black87
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx + (radius * 0.7) * math.cos(minuteAngle), center.dy + (radius * 0.7) * math.sin(minuteAngle)),
      minutePaint,
    );

    // Hour hand
    final hourPaint = Paint()
      ..color = isDark ? Colors.white : Colors.black87
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx + (radius * 0.5) * math.cos(hourAngle), center.dy + (radius * 0.5) * math.sin(hourAngle)),
      hourPaint,
    );

    // Second hand (static at 0 or a placeholder)
    final secondAngle = -math.pi / 2; // Pointing to 12
    final secondPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx + (radius * 0.8) * math.cos(secondAngle), center.dy + (radius * 0.8) * math.sin(secondAngle)),
      secondPaint,
    );

    // Center dot
    final dotPaint = Paint()..color = primaryColor;
    canvas.drawCircle(center, 6, dotPaint);
    final innerDotPaint = Paint()..color = isDark ? const Color(0xFF2D3342) : Colors.white;
    canvas.drawCircle(center, 3, innerDotPaint);
  }

  @override
  bool shouldRepaint(ClockPainter oldDelegate) {
    return oldDelegate.hour != hour || 
           oldDelegate.minute != minute || 
           oldDelegate.isDark != isDark ||
           oldDelegate.primaryColor != primaryColor;
  }
}
