# Smart Attendance — QR & Geo-Verified Workforce Tracking App

A polished, enterprise-style **Smart QR-Based Attendance Management Mobile Application** built with **Flutter**, **BLoC (`flutter_bloc`)**, **Dio**, **SQLite (`sqflite`)**, **Geolocator**, and **Mobile Scanner / QR Flutter**.

---

## 1. Architecture Overview

The codebase follows **Feature-Based Clean Architecture** with strict separation between presentation (BLoC/Cubit + reusable UI components), domain entities/repositories, and data sources (Dio REST API + SQLite local persistence + SharedPreferences session cache).

### Folder Structure

```text
lib/
├── app/
│   └── app.dart                             # Root SmartAttendanceApp & Auth routing
├── core/
│   ├── config/
│   │   └── api_config.dart                  # Single configurable Postman Mock Server URL
│   ├── constants/
│   │   └── app_constants.dart               # App keys, roles, attendance & sync constants
│   ├── database/
│   │   └── app_database.dart                # SQLite schema (attendance & qr_sessions)
│   ├── network/
│   │   ├── api_exception.dart               # Typed HTTP/network exception categories
│   │   └── dio_client.dart                  # Reusable Dio client, timeouts, debug logger
│   ├── theme/
│   │   ├── app_colors.dart                  # Deep Navy, Modern Blue, Emerald Green tokens
│   │   ├── app_spacing.dart                 # Spacing, radii, elevation shadows
│   │   ├── app_typography.dart              # Enterprise typography scale
│   │   └── app_theme.dart                   # Material 3 ThemeData
│   ├── utils/
│   │   ├── app_date_utils.dart              # Date keys, clocks, working hours formatting
│   │   └── token_generator.dart             # Secure random session ID & QR token generator
│   └── widgets/                             # Reusable Enterprise Design System
│       ├── app_bottom_nav_bar.dart
│       ├── app_button.dart
│       ├── app_confirm_dialog.dart
│       ├── app_loading_indicator.dart
│       ├── app_state_views.dart
│       ├── app_text_field.dart
│       ├── attendance_status_card.dart
│       ├── core_widgets.dart
│       ├── custom_app_bar.dart
│       ├── employee_profile_card.dart
│       ├── stat_card.dart
│       └── sync_status_badge.dart
├── features/
│   ├── admin/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── admin_api_service.dart
│   │   │   │   └── qr_session_api_service.dart
│   │   │   └── repositories/
│   │   │       └── admin_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/employee_attendance_summary.dart
│   │   │   └── repositories/admin_repository.dart
│   │   └── presentation/
│   │       ├── bloc/admin_bloc.dart
│   │       └── pages/
│   │           ├── admin_employees_page.dart
│   │           ├── admin_overview_page.dart
│   │           ├── admin_qr_generator_page.dart
│   │           └── admin_shell_page.dart
│   ├── attendance/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── attendance_api_service.dart
│   │   │   │   └── attendance_local_datasource.dart
│   │   │   ├── models/attendance_model.dart
│   │   │   └── repositories/attendance_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/attendance_entity.dart
│   │   │   └── repositories/attendance_repository.dart
│   │   └── presentation/
│   │       ├── bloc/attendance_bloc.dart
│   │       └── pages/attendance_history_page.dart
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_api_service.dart
│   │   │   │   └── dummy_users.dart
│   │   │   ├── models/user_model.dart
│   │   │   └── repositories/auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/user_entity.dart
│   │   │   └── repositories/auth_repository.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── authentication_bloc.dart
│   │       │   └── login_form_cubit.dart
│   │       └── pages/
│   │           ├── login_page.dart
│   │           └── splash_page.dart
│   ├── dashboard/
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── clock_cubit.dart
│   │       │   └── dashboard_bloc.dart
│   │       └── pages/
│   │           ├── employee_dashboard_page.dart
│   │           └── employee_shell_page.dart
│   ├── profile/
│   │   └── presentation/pages/employee_profile_page.dart
│   └── qr_scanner/
│       ├── data/services/location_service.dart
│       ├── domain/entities/qr_payload.dart
│       └── presentation/
│           ├── bloc/qr_scanner_bloc.dart
│           └── pages/qr_scanner_page.dart
└── main.dart
```

### State Management (100% BLoC & Cubit)
- `AuthenticationBloc`: Session restoration (`SharedPreferences`), login, logout.
- `LoginFormCubit`: Password visibility state.
- `DashboardBloc` & `ClockCubit` & `EmployeeNavCubit`: Employee KPI summary, live clock, bottom navigation.
- `QRScannerBloc`: QR parsing, token/expiry verification, duplicate/rule enforcement, GPS capture, SQLite persistence, and Dio sync + retry.
- `AttendanceBloc`: SQLite history querying, date filtering, individual/batch server sync retry.
- `AdminBloc` & `AdminNavCubit`: Employee metrics, search, date/status filters, dynamic QR generation, live QR expiry countdown.

---

## 2. Setup & Run Instructions

### Prerequisites
- Flutter SDK (`3.11+` Dart SDK; verified on Flutter `3.41.1`)
- Android Studio / Xcode / Physical Device or Emulator with Camera & Location permissions enabled

### Install Dependencies & Verify
```bash
flutter pub get
flutter analyze
flutter test
```

### Run the App
```bash
# Run with default configured Postman Mock Server URL (in ApiConfig._defaultBaseUrl)
flutter run

# Force offline SQLite / Demo Credential mode without HTTP requests
flutter run --dart-define=API_BASE_URL=demo

# Or override with another Postman Mock Server URL at runtime
flutter run --dart-define=API_BASE_URL=https://YOUR-MOCK-ID.mock.pstmn.io
```

### Configuring the Postman Mock Server
1. Import [`postman/Smart_Attendance_Postman_Collection.json`](postman/Smart_Attendance_Postman_Collection.json) into Postman and attach it to your Mock Server so all 7 endpoints return valid JSON responses.
2. Open `lib/core/config/api_config.dart` and verify or update `_defaultBaseUrl` (currently set to `https://acac5be5-b85b-49a0-8d65-83a0f6c3f812.mock.pstmn.io`):
```dart
static const String _defaultBaseUrl =
    'https://acac5be5-b85b-49a0-8d65-83a0f6c3f812.mock.pstmn.io';
```
When running in `demo` mode (`API_BASE_URL=demo`), the app clearly indicates **Local Only (Pending Sync)** / **Demo Mode** and never falsely labels local records as server-confirmed. Once your Postman Mock Server endpoints return valid JSON, Dio sends real HTTP requests and updates records to **Server Confirmed**.

---

## 3. Demo Test Credentials

| Role | ID | Email | Password |
| :--- | :--- | :--- | :--- |
| Employee 1 | `EMP001` | `rahul@gmail.com` | `123456` |
| Employee 2 | `EMP002` | `anjali@gmail.com` | `123456` |
| Admin | `ADM001` | `admin@gmail.com` | `admin123` |

*Quick-fill chips are also available on the Login screen for rapid testing.*

---

## 4. Security & Demo Validation Disclaimer

> **Important:** Client-side QR payload validation (JSON schema verification, expiry timestamp check, and local SQLite `qr_sessions` cross-check) is strictly for **offline demonstration and mock simulation**. Client-side checks can be bypassed on rooted/tampered devices and are **not production-secure**. In production, the backend server must generate cryptographically signed or opaque one-time QR tokens, enforce expiry and duplicate checks server-side using server time, and validate GPS geofencing.

---

## 5. Postman Mock Server API Endpoints

Configure these 7 endpoints in your Postman Mock Server:

### 1. `POST /login`
**Request:**
```json
{
  "identifier": "rahul@gmail.com",
  "email": "rahul@gmail.com",
  "password": "123456"
}
```
**Response (`200 OK`):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock",
  "user": {
    "id": "EMP001",
    "name": "Rahul",
    "email": "rahul@gmail.com",
    "role": "employee",
    "department": "Engineering",
    "designation": "Software Engineer"
  }
}
```

### 2. `GET /attendance?employee_id=EMP001`
**Response (`200 OK`):**
```json
{
  "data": {
    "id": 1,
    "employee_id": "EMP001",
    "employee_name": "Rahul",
    "session_id": "SES-20261112-A9F3K2",
    "attendance_type": "check_in",
    "check_in_time": "2026-11-12T09:10:00.000Z",
    "check_out_time": null,
    "latitude": 12.9716,
    "longitude": 77.5946,
    "status": "present",
    "date_key": "2026-11-12",
    "created_at": "2026-11-12T09:10:00.000Z"
  }
}
```

### 3. `POST /attendance/check-in`
**Request:**
```json
{
  "employee_id": "EMP001",
  "employee_name": "Rahul",
  "session_id": "SES-20261112-A9F3K2",
  "qr_token": "x8Kp2mQz9Lw4Rt7Vn1Bc5Yh3",
  "attendance_type": "check_in",
  "check_in_time": "2026-11-12T09:10:00.000Z",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "status": "present",
  "date": "2026-11-12"
}
```
**Response (`201 Created`):**
```json
{
  "success": true,
  "message": "Check-in confirmed by server",
  "record_id": "ATT-90821"
}
```

### 4. `POST /attendance/check-out`
**Request:**
```json
{
  "employee_id": "EMP001",
  "employee_name": "Rahul",
  "session_id": "SES-20261112-B3C4D5",
  "qr_token": "m9Np3qRs8Tv2Wx6Yz1Ab4Cd7",
  "attendance_type": "check_out",
  "check_out_time": "2026-11-12T18:05:00.000Z",
  "latitude": 12.9718,
  "longitude": 77.5949,
  "status": "checked_out",
  "date": "2026-11-12"
}
```
**Response (`200 OK`):**
```json
{
  "success": true,
  "message": "Check-out confirmed by server"
}
```

### 5. `GET /attendance/history?employee_id=EMP001`
**Response (`200 OK`):**
```json
{
  "data": [
    {
      "id": 1,
      "employee_id": "EMP001",
      "employee_name": "Rahul",
      "session_id": "SES-20261112-A9F3K2",
      "attendance_type": "check_out",
      "check_in_time": "2026-11-12T09:10:00.000Z",
      "check_out_time": "2026-11-12T18:05:00.000Z",
      "latitude": 12.9716,
      "longitude": 77.5946,
      "status": "checked_out",
      "date_key": "2026-11-12",
      "created_at": "2026-11-12T09:10:00.000Z"
    }
  ]
}
```

### 6. `POST /admin/qr-session`
**Request:**
```json
{
  "session_id": "SES-20261112-A9F3K2",
  "qr_token": "x8Kp2mQz9Lw4Rt7Vn1Bc5Yh3",
  "attendance_type": "check_in",
  "expires_at": "2026-11-12T09:15:00.000Z",
  "issued_at": "2026-11-12T09:10:00.000Z",
  "generated_by": "ADM001"
}
```
**Response (`201 Created`):**
```json
{
  "success": true,
  "session_id": "SES-20261112-A9F3K2"
}
```

### 7. `GET /admin/employees`
**Response (`200 OK`):**
```json
{
  "employees": [
    {
      "id": "EMP001",
      "name": "Rahul",
      "email": "rahul@gmail.com",
      "role": "employee",
      "department": "Engineering",
      "designation": "Software Engineer"
    },
    {
      "id": "EMP002",
      "name": "Anjali",
      "email": "anjali@gmail.com",
      "role": "employee",
      "department": "Product Design",
      "designation": "UX Designer"
    }
  ]
}
```

---

## 6. Demo Video Recording Guide

1. **Splash & Login**: Launch the app to show the animated Splash Screen and session verification, then show empty-field validation and invalid password error handling.
2. **Admin QR Generation**: Sign in as **Admin** (`admin@gmail.com` / `admin123`), inspect the KPI dashboard (`Total`, `Present`, `Absent`, `Late`), open **Generate QR**, pick `Check-In` + `5 min`, generate the QR code, and show the live countdown timer (plus copy JSON if demonstrating on a single emulator).
3. **Employee Check-In & GPS**: Sign out and sign in as **Rahul** (`rahul@gmail.com` / `123456`). Show the live clock, `Not Checked In` status, open **Scan QR**, scan (or paste) the Admin Check-In QR, grant Camera & GPS permissions, and show the GPS coordinates, timestamp, and SQLite sync status badge.
4. **Duplicate Prevention & Check-Out Validation**: Scan the Check-In QR again to demonstrate **Duplicate Check-In Prevention**. Then generate a **Check-Out** QR from Admin and scan it as Rahul to show calculated working hours.
5. **History & Persistence**: Open **History**, filter by date, inspect record details, restart the app to verify SQLite & SharedPreferences persistence, and verify Admin's **Employees** tab reflects Rahul's updated status.
