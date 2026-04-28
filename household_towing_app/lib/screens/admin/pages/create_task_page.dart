import 'package:flutter/material.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/utils/app_theme.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final TaskService _taskService = TaskService();
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  String? _serviceType;
  String? _location;
  String? _description;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  TaskPriority _priority = TaskPriority.medium;
  double? _estimatedCost;
  int? _estimatedDuration;

  bool _isLoading = false;
  List<Map<String, dynamic>> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .get();
      if (mounted) {
        setState(() {
          _customers = snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  'name': doc['name'] ?? 'Unknown',
                  'email': doc['email'],
                },
              )
              .toList();
        });
      }
    } catch (e) {
      // Failed to load customers - will show empty list
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
      setState(() => _scheduledDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.towingOrange,
              onPrimary: Colors.white,
              onSurface: AppTheme.textSlateDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _scheduledTime = time);
    }
  }

  void _createTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    if (_scheduledDate == null || _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final scheduledDateTime = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );

      final task = Task(
        id: '', // Firestore will generate
        customerId: _selectedCustomerId!,
        serviceType: _serviceType ?? 'General Service',
        location: _location ?? '',
        latitude: 0.0, // Can be enhanced with geolocation
        longitude: 0.0,
        scheduledDate: scheduledDateTime,
        description: _description,
        priority: _priority,
        status: TaskStatus.unassigned,
        createdAt: DateTime.now(),
        estimatedCost: _estimatedCost,
        estimatedDurationMinutes: _estimatedDuration,
      );

      final taskId = await _taskService.createTask(task);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Create New Task',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textSlateDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textSlateDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Customer Information'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCustomerId,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                    ),
                    hint: const Text(
                      'Choose a customer',
                      style: TextStyle(color: AppTheme.textSlateMedium),
                    ),
                    icon: const Icon(
                      Icons.expand_more,
                      color: AppTheme.textSlateMedium,
                    ),
                    items: _customers
                        .map<DropdownMenuItem<String>>(
                          (customer) => DropdownMenuItem<String>(
                            value: customer['id'] as String,
                            child: Text(
                              '${customer['name']} (${customer['email']})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCustomerId = value),
                    validator: (value) =>
                        value == null ? 'Please select a customer' : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Service Details'),
              const SizedBox(height: 12),
              _buildTextField(
                hintText: 'Service Type (e.g., Towing, Jump Start)',
                icon: Icons.build_circle_outlined,
                onChanged: (value) => _serviceType = value,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter service type' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                hintText: 'Location Address',
                icon: Icons.location_on_outlined,
                onChanged: (value) => _location = value,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter location' : null,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Priority Level'),
              const SizedBox(height: 12),
              Row(
                children: TaskPriority.values.map((priority) {
                  final isSelected = _priority == priority;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = priority),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _getPriorityColor(priority)
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? _getPriorityColor(priority)
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _getPriorityColor(
                                      priority,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          priority.toString().split('.').last.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSlateMedium,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Schedule'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: AppTheme.textSlateMedium,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _scheduledDate == null
                                    ? 'Select Date'
                                    : '${_scheduledDate!.month}/${_scheduledDate!.day}/${_scheduledDate!.year}',
                                style: TextStyle(
                                  color: _scheduledDate == null
                                      ? AppTheme.textSlateMedium
                                      : AppTheme.textSlateDark,
                                  fontWeight: _scheduledDate == null
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: AppTheme.textSlateMedium,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _scheduledTime == null
                                    ? 'Select Time'
                                    : '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: _scheduledTime == null
                                      ? AppTheme.textSlateMedium
                                      : AppTheme.textSlateDark,
                                  fontWeight: _scheduledTime == null
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Additional Details'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      hintText: 'Est. Cost (₱)',
                      keyboardType: TextInputType.number,
                      icon: Icons.attach_money,
                      onChanged: (value) =>
                          _estimatedCost = double.tryParse(value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      hintText: 'Duration (min)',
                      keyboardType: TextInputType.number,
                      icon: Icons.timer_outlined,
                      onChanged: (value) =>
                          _estimatedDuration = int.tryParse(value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Description & Notes (Optional)',
                  hintStyle: const TextStyle(color: AppTheme.textSlateMedium),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                maxLines: 4,
                onChanged: (value) => _description = value,
              ),
              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.towingOrange,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppTheme.towingOrange.withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Create Task',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Created tasks are saved in the Task Management queue.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSlateDark,
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required Function(String) onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppTheme.textSlateMedium,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: AppTheme.textSlateMedium),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return AppTheme.primaryBlue;
      case TaskPriority.medium:
        return AppTheme.towingOrange;
      case TaskPriority.high:
        return Colors.red.shade600;
      case TaskPriority.urgent:
        return Colors.red.shade900;
    }
  }
}
