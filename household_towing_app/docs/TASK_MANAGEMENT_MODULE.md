# Task and Schedule Management Module

## Overview
Complete task assignment, scheduling, and availability management system for the household towing service app. Enables admins to assign tasks efficiently and providers to manage their availability and assigned work.

## Components Built

### 1. **Data Model** (`lib/models/task_model.dart`)
- **Task Class**: Core data structure with fields for:
  - Task identification (id, customerId, assignedProviderId)
  - Service details (serviceType, location, description)
  - Scheduling (scheduledDate, estimatedDurationMinutes)
  - Status tracking (status, priority, createdAt, updatedAt)
  - Cost estimation (estimatedCost)
- **Enums**:
  - `TaskStatus`: unassigned → assigned → inProgress → completed/cancelled
  - `TaskPriority`: low, medium, high, urgent
- **Features**:
  - Firestore serialization/deserialization
  - Copy-with pattern for immutability

### 2. **Task Service** (`lib/services/task_service.dart`)
Business logic layer handling all task operations:

#### CRUD Operations
- `createTask()`: Create new task
- `getTask()`: Fetch single task
- `deleteTask()`: Delete unassigned tasks only

#### Task Queries
- `getUnassignedTasks()`: Stream of unassigned tasks (sorted by priority)
- `getProviderTasks()`: Provider's assigned/in-progress tasks
- `getCustomerTasks()`: Customer's task history
- `getTasksByDateRange()`: Filter tasks by date

#### Task Management
- `assignTask()`: Assign to provider (updates status to 'assigned')
- `updateTaskStatus()`: Progress through task lifecycle
- `rescheduleTask()`: Change scheduled date
- `updateTaskPriority()`: Adjust priority level
- `cancelTask()`: Mark as cancelled

#### Analytics
- `isProviderAvailable()`: Check provider availability for date
- `getProviderTaskCountForDate()`: Count tasks for provider on specific date

### 3. **Admin Task Assignment Screen** (`lib/screens/admin/pages/task_assignment_page.dart`)
Allows admins/managers to efficiently assign unassigned tasks:

**Features**:
- Real-time list of unassigned tasks sorted by priority
- Task cards showing:
  - Priority indicator (colored badge)
  - Service type
  - Location
  - Scheduled date/time
- Provider selector dropdown
- Assignment validation
- Success feedback via SnackBar

**UI Elements**:
- Task list with priority color coding
- Selected task highlighting
- Provider selection with ratings display
- Assign button with loading state

### 4. **Provider Availability Screen** (`lib/screens/provider/provider_availability_screen.dart`)
Enables providers to set their weekly availability:

**Features**:
- Weekly schedule with time slots (8 AM - 5 PM, hourly)
- Toggle availability for each day
- Visual feedback:
  - Selected slots highlighted in green
  - Slot count per day
  - Task count per day (if applicable)
- Availability sync with Firestore
- Info card explaining purpose

**UI Elements**:
- Day-wise collapsible sections
- Time slot grid with toggle buttons
- Save button with loading state

### 5. **Provider Tasks Screen** (`lib/screens/provider/provider_tasks_screen.dart`)
Task dashboard for service providers:

**Features**:
- Filter by status (Assigned, In Progress, Completed)
- Real-time task list stream
- Task cards showing:
  - Service type and location
  - Status badge with color coding
  - Schedule and priority
  - Action buttons

**Task Lifecycle**:
- Assigned → Start Task → In Progress
- In Progress → Complete Task → Completed

**Actions**:
- View full task details (bottom sheet)
- Update task status
- See estimated duration and notes

**UI Elements**:
- Filter chips for status filtering
- Expandable task cards
- Bottom sheet for task details
- Color-coded status/priority badges

## Data Structure (Firestore)

### Tasks Collection
```
tasks/{taskId}
  ├── customerId: string
  ├── assignedProviderId: string (optional)
  ├── serviceType: string
  ├── location: string
  ├── latitude: number
  ├── longitude: number
  ├── scheduledDate: timestamp
  ├── description: string (optional)
  ├── status: string (enum)
  ├── priority: string (enum)
  ├── createdAt: timestamp
  ├── updatedAt: timestamp
  ├── estimatedCost: number (optional)
  └── estimatedDurationMinutes: number (optional)
```

### Provider Schedule
```
providers/{providerId}/schedule/weekly
  ├── Monday: [time slots]
  ├── Tuesday: [time slots]
  ├── ...
  └── Sunday: [time slots]
```

## Key Features

### 1. Smart Task Assignment
- View unassigned tasks filtered by priority
- Easy provider selection
- Real-time status updates
- Assignment validation

### 2. Availability Management
- Weekly schedule setup
- Hourly time slots
- Sync with Firestore
- Task count visualization

### 3. Task Tracking
- Real-time task updates
- Status progression tracking
- Priority-based sorting
- Date-based filtering

### 4. Provider Dashboard
- View all assigned tasks
- Update task status
- See task details
- Filter by status

## Integration Points

### Required Screens to Update
1. **Admin Home** (`lib/screens/admin/admin_home.dart`):
   - Add "Task Management" navigation to task_assignment_page

2. **Provider Home** (`lib/screens/provider/provider_home.dart`):
   - Add "My Tasks" navigation to provider_tasks_screen
   - Add "Manage Availability" navigation to provider_availability_screen

### Collections Dependencies
- `tasks`: Main collection for all tasks
- `providers/{providerId}/schedule/weekly`: Provider availability
- `customers`: For customer lookup (optional)

## Status Flow Diagram
```
UNASSIGNED
    ↓
    └─→ ASSIGNED (admin assigns to provider)
            ↓
            └─→ IN_PROGRESS (provider starts task)
                    ↓
                    ├─→ COMPLETED (provider finishes)
                    └─→ CANCELLED (either party cancels)
```

## Future Enhancements
1. Geolocation-based task assignment
2. Auto-assignment based on availability
3. Task routing optimization
4. Real-time provider tracking
5. Customer notifications on status changes
6. Performance metrics and analytics
7. Task history and reports
8. Bulk task assignment
9. Recurring tasks
10. Task categories/types

## Testing Scenarios
1. Create task → Verify unassigned status
2. Assign task → Verify provider receives it
3. Provider accepts → Updates to assigned
4. Provider starts → Updates to in progress
5. Provider completes → Updates to completed
6. Set availability → Verify saved to Firestore
7. Filter tasks by status → Verify filtering works
8. Reassign task → Verify old assignment cleared
