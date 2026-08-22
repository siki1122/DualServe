import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/booking_model.dart';
import 'package:household_towing_app/services/booking_service.dart';
import 'package:household_towing_app/services/provider_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/utils/error_handler.dart';
import 'package:household_towing_app/services/logging_service.dart';
import 'package:household_towing_app/services/in_app_notification_service.dart';
import '../chat/chat_screen.dart';
import '../../widgets/asset_selection_dialog.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final BookingService _bookingService = BookingService();
  final ProviderService _providerService = ProviderService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _customerName = 'Loading...';
  String _customerPhone = '';
  String? _providerNotes;

  String? _loadedCustomerId;
  Booking? _cachedBooking;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    if (_cachedBooking == null) {
      final booking = await _getBooking();
      if (booking != null) {
        _cachedBooking = booking;
        await _loadCustomerData(booking.customerId);
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<Booking?> _getBooking() async {
    return await _bookingService.getBooking(widget.bookingId);
  }

  Future<void> _loadCustomerData(String customerId) async {
    try {
      if (customerId.isEmpty) {
        if (mounted) {
          setState(() {
            _customerName = 'Unknown Customer';
            _customerPhone = 'No phone available';
          });
        }
        return;
      }

      final customerDoc = await _firestore
          .collection('users')
          .doc(customerId)
          .get();

      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>;
        final newName = data['name'] ?? 'Unknown Customer';
        final newPhone = data['phone'] ?? 'No phone provided';

        if (mounted) {
          setState(() {
            _customerName = newName;
            _customerPhone = newPhone;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _customerName = 'Unknown User';
            _customerPhone = 'Not available';
          });
        }
      }
    } catch (e) {
      Logger.error('Failed to load customer data', e);
      if (mounted) {
        setState(() {
          _customerName = 'Unknown Customer';
          _customerPhone = 'Unable to load';
        });
      }
    }
  }

  Future<void> _acceptBooking(String providerId, Booking booking) async {
    showDialog(
      context: context,
      builder: (context) => AssetSelectionDialog(
        providerId: providerId,
        providerName: 'Provider',
        preselectedBooking: booking,
      ),
    ).then((_) async {
      // Notify customer that booking was accepted
      await InAppNotificationService().sendNotification(
        userId: booking.customerId,
        title: 'Booking Accepted',
        message: 'A provider has accepted your ${booking.serviceType.toLowerCase()} booking.',
        type: 'booking_update',
        actionData: {'bookingId': widget.bookingId},
      );

      if (mounted) {
        ErrorHandler.showSuccess(
            context, '✓ Booking accepted! Task added to "My Tasks"');
        Navigator.pop(context);
      }
    });
  }

  Future<void> _rejectBooking() async {
    setState(() => _isLoading = true);

    try {
      await _bookingService.rejectBooking(widget.bookingId);

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Booking rejected');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, title: 'Failed to reject booking');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRescheduleDialog(Booking booking) {
    DateTime selectedDate = booking.scheduledDate;
    String selectedTime = booking.scheduledTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Reschedule Booking', style: TextStyle(color: AppTheme.textSlateDark, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Picker
                const Text(
                  'Select New Date',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final todayStart = DateTime(now.year, now.month, now.day);
                    final initial = selectedDate.isBefore(todayStart) ? todayStart : selectedDate;

                    final date = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: todayStart,
                      lastDate: todayStart.add(const Duration(days: 30)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: AppTheme.towingOrange,
                              onPrimary: Colors.white,
                              onSurface: AppTheme.textSlateDark,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.textSlateMedium),
                        const SizedBox(width: 12),
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(fontSize: 16, color: AppTheme.textSlateDark),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Time Picker
                const Text(
                  'Select New Time',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<String>>(
                  future: _getAvailableSlotsForDate(
                    booking.assignedProviderId ?? '',
                    selectedDate,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final slots = snapshot.data ?? [];
                    if (slots.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No available slots for this date',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: slots.map((slot) {
                        final isSelected = selectedTime == slot;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedTime = slot),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.towingOrange : Colors.white,
                              border: Border.all(
                                color: isSelected ? AppTheme.towingOrange : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              slot,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textSlateDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSlateMedium)),
            ),
            ElevatedButton(
              onPressed: () =>
                  _confirmReschedule(booking, selectedDate, selectedTime),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.towingOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reschedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _getAvailableSlotsForDate(
    String providerId,
    DateTime date,
  ) async {
    try {
      final provider = await _providerService.getProvider(providerId);
      if (provider == null) return [];

      final dayName = _getDayName(date.weekday);
      final slots = provider.getAvailableSlotsForDay(dayName);

      if (slots.isEmpty) {
        return [
          '08:00 AM',
          '09:00 AM',
          '10:00 AM',
          '11:00 AM',
          '12:00 PM',
          '01:00 PM',
          '02:00 PM',
          '03:00 PM',
          '04:00 PM',
          '05:00 PM',
        ];
      }

      return slots;
    } catch (e) {
      return [];
    }
  }

  Future<void> _confirmReschedule(
    Booking booking,
    DateTime newDate,
    String newTime,
  ) async {
    try {
      // Validate availability
      final timeStr = newTime.length == 5
          ? newTime
          : '${newTime.padLeft(2, '0')}:00';
      final isAvailable = await _providerService.isProviderAvailable(
        booking.assignedProviderId ?? '',
        newDate,
        timeStr,
      );

      if (!isAvailable) {
        if (mounted) {
          ErrorHandler.showInfo(context, 'Selected time is no longer available');
        }
        return;
      }

      // Reschedule booking
      await _bookingService.rescheduleBooking(
        widget.bookingId,
        newDate,
        timeStr,
      );

      if (mounted) {
        Navigator.pop(context); // Close time picker dialog
        ErrorHandler.showSuccess(
          context,
          '✓ Rescheduled to ${newDate.day}/${newDate.month} at $timeStr',
        );
        // Refresh booking view
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, title: 'Failed to reschedule');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedBooking == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Booking Details', style: TextStyle(color: AppTheme.textSlateDark, fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final booking = _cachedBooking!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Booking Details', style: TextStyle(color: AppTheme.textSlateDark, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Service Info Card
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.serviceType,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSlateDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(booking.status)[1],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                booking.status
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(booking.status)[0],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        booking.serviceType == 'Towing'
                            ? Icons.car_repair
                            : Icons.cleaning_services,
                        size: 48,
                        color: AppTheme.towingOrange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated Cost:',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSlateMedium,
                        ),
                      ),
                      Text(
                        '₱${booking.estimatedCost?.toStringAsFixed(2) ?? '0'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Customer Info Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSlateDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 20,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSlateLight,
                            ),
                          ),
                          Text(
                            _customerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSlateDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 20, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phone',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSlateLight,
                            ),
                          ),
                          Text(
                            _customerPhone,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSlateDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Service Location Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSlateDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 20,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          booking.address,
                          style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textSlateMedium),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Schedule Info Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scheduled Service',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSlateDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: AppTheme.textSlateMedium,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSlateLight,
                            ),
                          ),
                          Text(
                            '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSlateDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 20,
                        color: AppTheme.textSlateMedium,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSlateLight,
                            ),
                          ),
                          Text(
                            booking.scheduledTime,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSlateDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Customer Notes
            if (booking.notes != null && booking.notes!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Notes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSlateDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.notes!,
                      style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textSlateMedium),
                    ),
                  ],
                ),
              ),

            // Action Buttons based on status
            if (booking.status == BookingStatus.pending) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Notes (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSlateDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      maxLines: 3,
                      onChanged: (value) => _providerNotes = value,
                      decoration: InputDecoration(
                        hintText:
                            'Add any notes before accepting/rejecting',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _acceptBooking(
                                booking.assignedProviderId ?? '',
                                booking,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.towingOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Accept Request',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _rejectBooking,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          foregroundColor: AppTheme.textSlateDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Decline Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ] else if (booking.status == BookingStatus.accepted) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            bookingId: booking.id,
                            receiverId: booking.customerId,
                            receiverName: _customerName,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text(
                      'Message Customer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRescheduleDialog(booking),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      foregroundColor: AppTheme.textSlateDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text(
                      'Reschedule Booking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.statusCompletedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.statusCompletedText,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This booking has been ${booking.status.toString().split('.').last}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.statusCompletedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday];
  }

  List<Color> _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return [AppTheme.statusPendingText, AppTheme.statusPendingBg];
      case BookingStatus.accepted:
        return [AppTheme.statusAcceptedText, AppTheme.statusAcceptedBg];
      case BookingStatus.rejected:
        return [Colors.red.shade700, Colors.red.shade100];
      default:
        return [AppTheme.textSlateMedium, Colors.grey.shade100];
    }
  }
}
