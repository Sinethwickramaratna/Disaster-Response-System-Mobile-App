# Field Officer Dashboard Integration Guide

## Overview
This guide documents the integration of real-time assignment data into the Field Officer mobile app dashboard. The system provides comprehensive views of alerts, incidents, resources, and reports assigned to field officers.

## Backend API Endpoints Created

All endpoints require JWT authentication via `Authorization: Bearer {token}` header.

### 1. **GET /api/assignments/summary**
Returns a dashboard summary with key metrics.

**Response:**
```json
{
  "criticalAlerts": 8,
  "activeIncidents": 142,
  "assignedResources": 45,
  "readinessScore": 84,
  "breakdown": {
    "assignmentRatio": 0.95,
    "resourceRatio": 0.93,
    "activeAssignments": 19,
    "totalAssignments": 20,
    "readyResources": 42,
    "totalResources": 45
  }
}
```

**Used by:** Dashboard screen to display metric cards

---

### 2. **GET /api/assignments/incidents?status={status}**
Fetches incidents assigned to the field officer.

**Query Parameters:**
- `status` (optional): Filter by incident status (ACTIVE, RESOLVED, UNDER_RESPONSE, CLOSED)

**Response:**
```json
{
  "count": 5,
  "incidents": [
    {
      "assignmentId": "uuid",
      "role": "PRIMARY_RESPONDER",
      "assignmentStatus": "ACTIVE",
      "assignedAt": "2026-05-11T08:30:00Z",
      "incident": {
        "incident_id": 1,
        "title": "Flooding in District A",
        "severity": "HIGH",
        "affected_population": 500,
        "status": "ACTIVE",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "division_id": 1,
        "created_at": "2026-05-11T08:00:00Z",
        "Division": {
          "division_name": "Bangalore South",
          "district": "Bangalore",
          "province": "Karnataka"
        }
      }
    }
  ]
}
```

---

### 3. **GET /api/assignments/alerts?scope={scope}**
Fetches alerts with optional scope filtering.

**Query Parameters:**
- `scope` (optional): 'citizen' (public), 'internal', or 'all' (default: 'all')

**Response:**
```json
{
  "count": 12,
  "alerts": [
    {
      "id": "uuid",
      "type": "FLOOD_WARNING",
      "severity": "CRITICAL",
      "title": "Flash Flood Alert",
      "description": "Heavy rainfall expected in next 2 hours",
      "district": "Bangalore",
      "isPublic": true,
      "isActive": true,
      "source": "WEATHER_SERVICE",
      "createdAt": "2026-05-11T08:45:00Z",
      "expiresAt": "2026-05-11T12:00:00Z"
    }
  ],
  "scope": "all"
}
```

---

### 4. **GET /api/assignments/resources**
Fetches assigned logistics deployments and resource readiness.

**Response:**
```json
{
  "total": 45,
  "ready": 42,
  "deployed": 2,
  "delivered": 1,
  "pending": 0,
  "resources": [
    {
      "deployment_id": "uuid",
      "status": "READY",
      "items_dispatched": {
        "tents": 10,
        "blankets": 50,
        "food_packs": 100
      },
      "dispatched_at": "2026-05-11T09:00:00Z",
      "completed_at": null,
      "delivery_notes": "Awaiting dispatch approval",
      "incident_id": "uuid"
    }
  ]
}
```

---

### 5. **GET /api/assignments/reports**
Fetches incident reports assigned for completion.

**Response:**
```json
{
  "count": 8,
  "reports": [
    {
      "reportId": "uuid",
      "incidentId": "uuid",
      "title": "Landslide in Eastern Zone",
      "disasterType": "LANDSLIDE",
      "severity": "HIGH",
      "status": "ACTIVE",
      "assignedRole": "ASSESSOR",
      "description": "Assessment report pending",
      "district": "Bangalore",
      "affectedPeople": 350,
      "location": {
        "latitude": 12.9352,
        "longitude": 77.6245
      },
      "reportedAt": "2026-05-11T07:30:00Z",
      "updatedAt": "2026-05-11T08:45:00Z",
      "assignedAt": "2026-05-11T08:00:00Z"
    }
  ],
  "categories": {
    "active": 5,
    "completed": 2,
    "pending": 1
  }
}
```

---

## Flutter Models

### Core Models (lib/models/assignment.dart)

1. **AssignmentSummary** - Dashboard summary data
2. **AssignmentIncident** - Incident with assignment details
3. **AlertData** - Active alerts
4. **ResourceDeployment** - Logistics deployment status
5. **ReportData** - Incident reports
6. **LocationData** - Latitude/longitude pairs
7. **DivisionData** - Geographic division info

---

## Flutter Service

### AssignmentService (lib/services/assignment_service.dart)

Main service for all assignment-related API calls.

**Key Methods:**

```dart
// Fetch dashboard summary
Future<AssignmentSummary?> fetchSummary()

// Fetch incidents (optionally filtered by status)
Future<List<AssignmentIncident>> fetchIncidents({String? status})

// Fetch alerts with scope filtering
Future<List<AlertData>> fetchAlerts({String scope = 'all'})

// Fetch assigned resources
Future<ResourcesResponse?> fetchResources()

// Fetch incident reports
Future<ReportsResponse?> fetchReports()
```

All methods automatically handle JWT authentication using the token from AuthService.

---

## Updated Components

### Dashboard Screen (lib/screens/dashboard_screen.dart)

**Changes Made:**
- ✅ Replaced mock data with real API calls
- ✅ Added state variables for summary, alerts, and incidents
- ✅ Implemented `_loadDashboardData()` in initState
- ✅ Added loading and error states
- ✅ Updated metric cards to display real data
- ✅ Updated telemetry section to show active alerts
- ✅ Color coding for alert severity levels

**New UI Features:**
- Dynamic critical alerts count
- Real active incidents display
- Actual readiness score calculation
- Live alert feed with severity indicators
- Error handling with user feedback

---

## Integration Steps for Your Flutter App

### 1. Ensure Environment Configuration
Update `.env` file with your API base URL:
```
API_BASE_URL=https://your-api-domain.com
```

### 2. Import Required Models and Services
```dart
import 'package:command_mobile/models/assignment.dart';
import 'package:command_mobile/services/assignment_service.dart';
```

### 3. Update Auth Service (Done)
The `AuthService.getToken()` method is now available for fetching JWT tokens.

### 4. Use in Other Screens
```dart
// Example usage in any screen
final summary = await AssignmentService.fetchSummary();
final incidents = await AssignmentService.fetchIncidents(status: 'ACTIVE');
final alerts = await AssignmentService.fetchAlerts(scope: 'internal');
final resources = await AssignmentService.fetchResources();
final reports = await AssignmentService.fetchReports();
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                       │
│                                                              │
│  DashboardScreen                                            │
│  ├─ initState() → _loadDashboardData()                     │
│  └─ Calls AssignmentService methods                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ JWT Auth
                      ↓
┌─────────────────────────────────────────────────────────────┐
│              Next.js Backend API                            │
│                                                              │
│  /api/assignments/summary                                   │
│  /api/assignments/incidents                                │
│  /api/assignments/alerts                                   │
│  /api/assignments/resources                                │
│  /api/assignments/reports                                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ Supabase Queries
                      ↓
┌─────────────────────────────────────────────────────────────┐
│                  PostgreSQL Database                        │
│                                                              │
│  PersonnelAssignment    Alert           LogisticsDeployment│
│  ActiveIncident         ConfirmedIncident                  │
│  Division              ...                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Error Handling

All service methods include try-catch blocks. Errors are:
1. Logged to console
2. Re-thrown to caller for handling
3. Dashboard shows error toast notifications

Example error handling:
```dart
try {
  final summary = await AssignmentService.fetchSummary();
} catch (e) {
  print('Error: $e');
  // Show user-friendly error message
}
```

---

## Performance Considerations

1. **Parallel Loading:** Dashboard loads all data in parallel using Future operations
2. **Caching:** Consider implementing caching layer for frequently accessed data
3. **Pagination:** For large datasets (incidents, alerts), implement pagination in future versions
4. **Real-time Updates:** Consider WebSocket integration for live alert updates

---

## Testing the Integration

### Manual Testing Checklist:
- [ ] Login successfully as a field officer
- [ ] Dashboard loads without errors
- [ ] Summary metrics display correctly
- [ ] Alert feed shows active alerts
- [ ] Alert severity colors match expectations
- [ ] Refresh data (add pull-to-refresh gesture)
- [ ] Network errors show appropriate messages

### Example cURL Commands:
```bash
# Get dashboard summary
curl -H "Authorization: Bearer {TOKEN}" \
  https://api-domain.com/api/assignments/summary

# Get active incidents
curl -H "Authorization: Bearer {TOKEN}" \
  https://api-domain.com/api/assignments/incidents?status=ACTIVE

# Get internal alerts only
curl -H "Authorization: Bearer {TOKEN}" \
  https://api-domain.com/api/assignments/alerts?scope=internal
```

---

## Future Enhancements

1. **Push Notifications** - Alert field officers of critical updates
2. **Real-time Sync** - WebSocket for live data updates
3. **Offline Mode** - Cache data locally for offline access
4. **Advanced Filtering** - More granular query filters
5. **Data Refresh** - Pull-to-refresh functionality
6. **Performance Metrics** - Track API response times
7. **Incident Details Screen** - Deep dive into individual incidents
8. **Resource Management** - Update deployment status from app

---

## API Documentation

For complete API documentation and implementation details, refer to the backend route files:
- `src/app/api/assignments/summary/route.ts`
- `src/app/api/assignments/incidents/route.ts`
- `src/app/api/assignments/alerts/route.ts`
- `src/app/api/assignments/resources/route.ts`
- `src/app/api/assignments/reports/route.ts`

---

## Support

For issues or questions:
1. Check that JWT token is valid and not expired
2. Verify API_BASE_URL is correctly configured
3. Check Network tab in browser DevTools for actual API responses
4. Review console logs for error details
