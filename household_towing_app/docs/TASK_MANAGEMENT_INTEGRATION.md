# Task and Schedule Management - Integration Guide

## Step 1: Update Imports in Admin Home
Add to `lib/screens/admin/admin_home.dart`:

```dart
import 'package:household_towing_app/screens/admin/pages/task_assignment_page.dart';
```

Add navigation item in the admin menu/navigation:
```dart
ListTile(
  leading: Icon(Icons.assignment),
  title: Text('Task Management'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => TaskAssignmentScreen()),
  ),
),
```

## Step 2: Update Provider Home
Add to `lib/screens/provider/provider_home.dart`:

```dart
import 'package:household_towing_app/screens/provider/provider_tasks_screen.dart';
import 'package:household_towing_app/screens/provider/provider_availability_screen.dart';
```

Add navigation items:
```dart
// For My Tasks
ListTile(
  leading: Icon(Icons.task_alt),
  title: Text('My Tasks'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProviderTasksScreen()),
  ),
),

// For Manage Availability
ListTile(
  leading: Icon(Icons.schedule),
  title: Text('Manage Availability'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProviderAvailabilityScreen()),
  ),
),
```

## Step 3: Update Pubspec Dependencies
Ensure you have these in `pubspec.yaml`:
```yaml
dependencies:
  cloud_firestore: ^4.x.x
  firebase_auth: ^4.x.x
  flutter:
    sdk: flutter
```

## Step 4: Firestore Security Rules
Add these rules to your Firestore for proper access control:

```javascript
// Tasks collection
match /tasks/{taskId} {
  // Users can read their own tasks
  allow read: if request.auth.uid == resource.data.customerId ||
                 request.auth.uid == resource.data.assignedProviderId;
  
  // Admins can create and assign tasks
  allow create: if request.auth.token.role == 'admin';
  allow update: if request.auth.token.role == 'admin';
  
  // Providers can update their own task status
  allow update: if request.auth.uid == resource.data.assignedProviderId &&
                   (request.resource.data.status == 'inProgress' ||
                    request.resource.data.status == 'completed');
}

// Provider schedule
match /providers/{providerId}/schedule/{document=**} {
  allow read: if request.auth.uid == providerId;
  allow write: if request.auth.uid == providerId;
}
```

## Step 5: Create a Task in Admin Dashboard

Admin creates new task flow:
```dart
// Example - add this to admin dashboard
Future<void> createNewTask() async {
  final task = Task(
    id: '', // Firestore generates ID
    customerId: selectedCustomer.id,
    serviceType: 'Towing',
    location: 'Main Street, Downtown',
    latitude: 40.7128,
    longitude: -74.0060,
    scheduledDate: DateTime.now().add(Duration(hours: 2)),
    description: 'Vehicle breakdown on main street',
    priority: TaskPriority.high,
    status: TaskStatus.unassigned,
    createdAt: DateTime.now(),
  );
  
  final taskId = await TaskService().createTask(task);
  print('Task created: $taskId');
}
```

## Step 6: Hook Up Provider Availability Display

In `ProviderAvailabilityScreen`, the task count can be shown:

```dart
int _getTaskCountForDay(String day) {
  // Get tasks for this specific day
  final providerId = FirebaseAuth.instance.currentUser!.uid;
  
  // Calculate date from day name
  DateTime dayDate = _getDateFromDayName(day);
  
  // Use TaskService to count tasks
  return TaskService().getProviderTaskCountForDate(providerId, dayDate);
}
```

## Step 7: Add Task Creation Screen (Optional)

Create `lib/screens/admin/pages/create_task_screen.dart`:

```dart
class CreateTaskScreen extends StatefulWidget {
  @override
  _CreateTaskScreenState createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TaskService _taskService = TaskService();
  
  String? _serviceType;
  String? _location;
  DateTime? _scheduledDate;
  TaskPriority _priority = TaskPriority.medium;
  String? _customerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create New Task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Service type dropdown
            DropdownButtonFormField<String>(
              items: ['Towing', 'Jump Start', 'Lockout', 'Fuel Delivery']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) => _serviceType = value,
              decoration: InputDecoration(labelText: 'Service Type'),
            ),
            // Location field
            TextFormField(
              onChanged: (value) => _location = value,
              decoration: InputDecoration(labelText: 'Location'),
            ),
            // Schedule picker
            TextFormField(
              readOnly: true,
              onTap: _pickDateTime,
              decoration: InputDecoration(
                labelText: 'Scheduled Date & Time',
                hintText: _scheduledDate?.toString() ?? 'Select date',
              ),
            ),
            // Priority dropdown
            DropdownButtonFormField<TaskPriority>(
              value: _priority,
              items: TaskPriority.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.toString().split('.').last)))
                  .toList(),
              onChanged: (value) => _priority = value ?? TaskPriority.medium,
              decoration: InputDecoration(labelText: 'Priority'),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitForm,
              child: Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }

  void _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
    );
    if (date != null) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() => _scheduledDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    final task = Task(
      id: '',
      customerId: _customerId ?? '',
      serviceType: _serviceType ?? '',
      location: _location ?? '',
      latitude: 0.0,
      longitude: 0.0,
      scheduledDate: _scheduledDate ?? DateTime.now(),
      priority: _priority,
      status: TaskStatus.unassigned,
      createdAt: DateTime.now(),
    );
    
    try {
      await _taskService.createTask(task);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task created!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
```

## Testing Checklist

- [ ] Admin can view unassigned tasks
- [ ] Admin can select a task and provider
- [ ] Admin can assign task to provider
- [ ] Provider sees task in "My Tasks"
- [ ] Provider can start task (status → inProgress)
- [ ] Provider can complete task (status → completed)
- [ ] Provider can set availability for each day
- [ ] Availability saves to Firestore
- [ ] Tasks filter by status correctly
- [ ] Task details show all information
- [ ] Real-time updates work (Firestore streams)

## Troubleshooting

### Tasks not appearing
- Check Firestore rules allow read access
- Verify task status is not 'cancelled'
- Check provider ID matches in database

### Availability not saving
- Verify user is authenticated
- Check Firestore collection path: `providers/{uid}/schedule/weekly`
- Ensure rule allows write to schedule

### Status updates not showing
- Verify task ID is correct
- Check Firestore update operation completed
- Streams should auto-refresh

## Next Steps
1. Integrate screens into app navigation
2. Add task creation form to admin panel
3. Test with real data
4. Add customer notifications when task assigned
5. Implement geolocation for task assignment
