# 📱 QR Attendance Scanner - Project Structure

## 📂 Folder Organization

The project follows a clean, modular architecture with separation of concerns:

```
lib/
├── main.dart                          # App entry point
├── models/                            # Data models
│   ├── student.dart                   # Student data model
│   └── models.dart                    # Barrel file (exports all models)
├── services/                          # Business logic & API calls
│   ├── attendance_service.dart        # Attendance API service
│   └── services.dart                  # Barrel file (exports all services)
├── screens/                           # UI screens/pages
│   ├── qr_scanner_screen.dart         # Main QR scanner screen
│   ├── qr_success_screen.dart         # Success result screen
│   ├── qr_failure_screen.dart         # Error/failure screen
│   ├── qr_duplicate_screen.dart       # Duplicate scan screen
│   └── screens.dart                   # Barrel file (exports all screens)
└── [deprecated]                       # Old files (can be deleted)
    ├── qr_scanner.dart
    ├── qr_success.dart
    ├── qr_failure.dart
    └── qr_duplicate.dart
```

---

## 📋 File Descriptions

### 🎯 **main.dart**
- Application entry point
- Initializes MaterialApp
- Sets up theme and home screen
- Currently points to `QRScannerScreen`

### 📦 **models/** - Data Layer

#### **student.dart**
Student data model with:
- Properties: username, name, batch, mentor, sts, inTime, lastScan, qrToken
- `fromJson()` - Parse from API response
- `toJson()` - Convert to JSON
- `hasLastScan` - Check if student was scanned before
- `isActive` - Check if student status is active
- `displayInfo` - Formatted string for UI display

#### **models.dart** (Barrel file)
Single import point for all models:
```dart
import 'package:qr_attendance_scanner/models/models.dart';
```

---

### 🔧 **services/** - Business Logic Layer

#### **attendance_service.dart**
Handles all backend API communication:

**Methods:**
1. `getStudent(qrToken)` - Fetch student by QR token
2. `activateStudent(qrToken)` - Mark attendance
3. `processAttendance(qrToken)` - Complete flow (get + check + activate)

**Returns:**
```dart
{
  'status': 'success' | 'duplicate' | 'error',
  'student': Student,  // for success/duplicate
  'error': String,     // for error
  'previous_scan_time': String  // for duplicate
}
```

**Backend URL:**
```
https://script.google.com/macros/s/AKfycby2dINhlZviIwcxOIWdvtnBPnhHWaeZ2B1JLxfKcS-7gZEhb_WR1r-hdRqMC26-fXDuDw/exec
```

#### **services.dart** (Barrel file)
Single import point for all services:
```dart
import 'package:qr_attendance_scanner/services/services.dart';
```

---

### 🎨 **screens/** - Presentation Layer

#### **qr_scanner_screen.dart**
Main QR code scanner interface:
- Camera preview with MobileScanner
- Animated scanning frame with glow effect
- Processing indicator
- Calls `AttendanceService.processAttendance()`
- Navigates to result screens based on response

**Key Features:**
- Animated border with rotating glow
- Loading state management
- Prevents multiple simultaneous scans
- Auto-resets after navigation

#### **qr_success_screen.dart**
Successful attendance screen (Blue theme):
- Lottie success animation
- Student details display
- "Scan Again" button
- Returns to scanner on tap

#### **qr_failure_screen.dart**
Error/unknown QR screen (Red theme):
- Lottie error animation
- Error message display
- "Try Again" button
- Returns to scanner on tap

#### **qr_duplicate_screen.dart**
Already scanned warning (Amber theme):
- Lottie warning animation
- Student info + previous scan time
- "Scan Different" button
- Returns to scanner on tap

#### **screens.dart** (Barrel file)
Single import point for all screens:
```dart
import 'package:qr_attendance_scanner/screens/screens.dart';
```

---

## 🔄 Data Flow

```
┌─────────────────────┐
│   QRScannerScreen   │
│   (User scans QR)   │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ AttendanceService   │
│ .processAttendance()│
└──────────┬──────────┘
           │
           ├─→ API: getStudent(qr_token)
           │
           ├─→ Check: has last_scan?
           │
           └─→ API: activateStudent(qr_token)
                    │
    ┌───────────────┼───────────────┐
    ↓               ↓               ↓
┌─────────┐   ┌──────────┐   ┌─────────┐
│ Success │   │ Duplicate│   │  Error  │
│ Screen  │   │  Screen  │   │ Screen  │
└─────────┘   └──────────┘   └─────────┘
```

---

## 🎯 Import Strategy

### ✅ Recommended (Using Barrel Files):
```dart
import 'package:qr_attendance_scanner/models/models.dart';
import 'package:qr_attendance_scanner/services/services.dart';
import 'package:qr_attendance_scanner/screens/screens.dart';
```

### ✅ Also Acceptable (Direct Imports):
```dart
import 'package:qr_attendance_scanner/models/student.dart';
import 'package:qr_attendance_scanner/services/attendance_service.dart';
import 'package:qr_attendance_scanner/screens/qr_scanner_screen.dart';
```

---

## 🧹 Cleanup (Optional)

You can safely delete these old files:
- `lib/qr_scanner.dart`
- `lib/qr_success.dart`
- `lib/qr_failure.dart`
- `lib/qr_duplicate.dart`

The new structured files replace them completely.

---

## 🚀 Usage Examples

### Example 1: Using AttendanceService
```dart
import 'package:qr_attendance_scanner/services/services.dart';

// Process QR scan
final result = await AttendanceService.processAttendance('QR_TOKEN_123');

if (result['status'] == 'success') {
  final student = result['student'];
  print('Welcome ${student.name}!');
} else if (result['status'] == 'duplicate') {
  print('Already scanned at ${result['previous_scan_time']}');
} else {
  print('Error: ${result['error']}');
}
```

### Example 2: Using Student Model
```dart
import 'package:qr_attendance_scanner/models/models.dart';

final student = Student.fromJson({
  'username': 'john_doe',
  'name': 'John Doe',
  'batch': 'Batch A',
  // ... other fields
});

print(student.displayInfo);  // Formatted string
print(student.hasLastScan);  // true/false
print(student.isActive);     // true/false
```

### Example 3: Navigation to Screens
```dart
import 'package:qr_attendance_scanner/screens/screens.dart';

// Navigate to success screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => QRSuccessScreen(
      scannedData: student.displayInfo,
    ),
  ),
);
```

---

## 📊 Benefits of This Structure

### ✅ **Separation of Concerns**
- **Models**: Pure data classes
- **Services**: Business logic & API
- **Screens**: UI presentation only

### ✅ **Maintainability**
- Easy to locate files
- Clear responsibilities
- Reduced coupling

### ✅ **Scalability**
- Add new models → `models/`
- Add new services → `services/`
- Add new screens → `screens/`

### ✅ **Testability**
- Test services independently
- Mock API responses easily
- Test UI with mock data

### ✅ **Reusability**
- Share models across screens
- Reuse services in multiple places
- Consistent UI components

---

## 🧪 Testing Strategy

### Unit Tests (Recommended):
```dart
// test/services/attendance_service_test.dart
// test/models/student_test.dart
```

### Widget Tests:
```dart
// test/screens/qr_scanner_screen_test.dart
// test/screens/qr_success_screen_test.dart
```

### Integration Tests:
```dart
// integration_test/app_test.dart
```

---

## 🔧 Configuration

### Update Backend URL:
Edit `lib/services/attendance_service.dart`:
```dart
static const String baseUrl = 'YOUR_NEW_URL';
```

### Add New Model Field:
1. Update `lib/models/student.dart`
2. Update `fromJson()` and `toJson()`
3. Run to verify no errors

### Add New Screen:
1. Create in `lib/screens/new_screen.dart`
2. Export in `lib/screens/screens.dart`
3. Import and use

---

## ✅ Migration Checklist

- [x] Created `models/` folder with Student model
- [x] Created `services/` folder with AttendanceService
- [x] Created `screens/` folder with all UI screens
- [x] Created barrel files for easy imports
- [x] Updated main.dart to use new structure
- [x] Verified no compilation errors
- [x] All imports working correctly
- [ ] Delete old deprecated files (optional)
- [ ] Run `flutter clean && flutter pub get`
- [ ] Test on device

---

## 🎓 Best Practices Applied

1. **Single Responsibility**: Each file has one clear purpose
2. **DRY (Don't Repeat Yourself)**: Reusable service layer
3. **Clean Code**: Descriptive names, clear structure
4. **Future-Proof**: Easy to extend and maintain
5. **Industry Standard**: Follows Flutter/Dart conventions

---

**Status: ✅ RESTRUCTURED & READY**

Your QR Attendance Scanner now follows professional Flutter architecture! 🎉
