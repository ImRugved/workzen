# Script to Update All Files to Use getTextTheme() and ScreenUtil

## Files that need updating:

### Admin Screens:
- lib/screens/admin/admin_home.dart (IN PROGRESS)
- lib/screens/admin/admin_attendance_screen.dart
- lib/screens/admin/leave_requests_screen.dart
- lib/screens/admin/employee_onboarding_screen.dart
- lib/screens/admin/employee_management_screen.dart
- lib/screens/admin/admin_home.dart (demo_page.dart if exists)

### User Screens:
- lib/screens/user/user_home.dart
- lib/screens/user/user_dashboard_screen.dart
- lib/screens/user/apply_leave_screen.dart
- lib/screens/user/attendance_screen.dart
- lib/screens/user/leave_history_screen.dart
- lib/screens/user/attendance_history_screen.dart

### Auth Screens:
- lib/screens/auth/login_screen.dart
- lib/screens/auth/signup_screen.dart

### Common Screens:
- lib/screens/profile_screen.dart
- lib/screens/splash_scren.dart
- lib/screens/update_check_screen.dart

### Widgets:
- lib/widgets/app_drawer.dart
- lib/widgets/custom_button.dart
- lib/widgets/custom_text_field.dart
- lib/widgets/leave_card.dart
- lib/widgets/request_card.dart

## Required Changes:

### 1. Add Imports:
```dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:workzen/constants/const_textstyle.dart';
```

### 2. Replace TextStyle patterns:

| Old Pattern | New Pattern | Use Case |
|------------|-------------|-----------|
| `TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: X)` | `getTextTheme().displayLarge?.copyWith(color: X)` | Large Display Text |
| `TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: X)` | `getTextTheme().titleLarge?.copyWith(color: X)` | Titles |
| `TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: X)` | `getTextTheme().titleMedium?.copyWith(color: X)` | Medium Titles |
| `TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: X)` | `getTextTheme().bodyLarge?.copyWith(color: X)` | Body Large |
| `TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: X)` | `getTextTheme().bodyMedium?.copyWith(color: X)` | Body Medium |
| `TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: X)` | `getTextTheme().bodySmall?.copyWith(color: X)` | Body Small |
| `TextStyle(fontSize: 10, color: X)` | `getTextTheme().labelSmall?.copyWith(color: X)` | Labels |

### 3. Replace Size patterns:

| Old Pattern | New Pattern |
|------------|-------------|
| `const EdgeInsets.all(20)` | `EdgeInsets.all(20.w)` |
| `const EdgeInsets.symmetric(vertical: 15, horizontal: 20)` | `EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w)` |
| `const SizedBox(height: X)` | `SizedBox(height: X.h)` |
| `const SizedBox(width: X)` | `SizedBox(width: X.w)` |
| `fontSize: 16` | `fontSize: 16.sp` |
| `radius: 30` | `radius: 30.r` |
| `BorderRadius.circular(16)` | `BorderRadius.circular(16.r)` |
| `const Offset(0, 5)` | `Offset(0, 5.h)` |
| `size: 20` | `size: 20.r` |

### 4. Remove `const` from widgets when using ScreenUtil:
- Cannot use `const` with .h, .w, .sp, .r

## Manual Review Needed:
- Colors should remain as is (no ScreenUtil)
- Boolean values remain as is
- String values remain as is
- Only numbers for sizing/spacing need ScreenUtil
- Check each TextStyle mapping for appropriate semantic meaning

