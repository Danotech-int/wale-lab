# Excelerate Talent Hub

**A Flutter-based engagement platform connecting Excelerate learners with programmes, achievements, and career opportunities.**

## 1. Project Overview

Excelerate Talent Hub is a Flutter application designed to support onboarding, programme discovery, and role-based engagement for learners and administrators in the Excelerate community.

The application provides separate learner and admin experiences, authentication flows, programme listings, programme details, and a structured data layer that supports mock and backend integrations.

The project aims to provide a centralized platform where learners can explore programmes, track their engagement, and access opportunities while administrators manage programme-related activities.

## 2. Purpose

The main purpose of Excelerate Talent Hub is to bridge the gap between learning and career opportunities.

The application aims to:

- Simplify learner onboarding and programme discovery.
- Provide role-based access for learners and administrators.
- Help learners explore programme information and eligibility.
- Support programme registration and engagement tracking.
- Provide administrators with tools to manage learner and programme activities.
- Create a foundation for future backend and Firebase integration.

## 3. Features

### Learner Features

- Login and sign-up flows.
- Learner dashboard.
- Programme listing and search.
- Programme details, including eligibility, outcomes, and schedules.
- Programme registration through the mock data flow.
- Learner-specific programme information.
- Loading, error, empty, and retry states.

### Admin Features

- Role-aware admin dashboard.
- Admin authentication flow.
- Programme-related management interface, according to the current implementation.
- Foundation for future learner and programme administration features.

### Application Features

- Role-based navigation.
- Responsive user interface.
- Mock API support for local development.
- Reusable programme models and services.
- Repository-based data management.
- Search and category filtering.
- State management using Provider.

## 4. Technologies Used

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application development |
| Dart | Main programming language |
| Provider | State management |
| SharedPreferences | Local session storage |
| Firebase Core | Firebase initialization |
| Firebase Authentication | Authentication integration |
| Cloud Firestore | Planned cloud database integration |
| Mock API | Local development and testing |
| Git | Version control |
| GitHub | Repository hosting |
| VS Code | Development environment |

## 5. Prerequisites

Install the following tools before running the application:

- Flutter SDK
- Dart SDK (included with Flutter)
- Android Studio
- Android SDK and Android Emulator, or a physical Android device
- Visual Studio Code (recommended)
- Git

Verify your Flutter installation:

```bash
flutter --version
flutter doctor
```

Resolve the required Android toolchain issues reported by Flutter Doctor before running on Android.

## 6. Getting Started

### Step 1: Clone the repository

```bash
git clone https://github.com/Ruby160612/excelerate-engagement-app.git
```

### Step 2: Navigate to the project directory

```bash
cd excelerate-engagement-app
```

### Step 3: Install dependencies

```bash
flutter pub get
```

### Step 4: Run the application in mock mode

Use the mock backend for local development and testing:

```bash
flutter run --dart-define=USE_MOCK=true
```

### Step 5: Run against a configured backend

If a compatible backend is configured, use:

```bash
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://your-api-url
```

Replace `https://your-api-url` with the actual backend URL.

### Step 6: Run automated tests

```bash
flutter test
```

### Step 7: Analyze the application

```bash
flutter analyze
```

## 7. Mock Mode Login Credentials

To test the application in mock mode, run:

```bash
flutter run --dart-define=USE_MOCK=true
```

Use the following development credentials:

| Role | Email | Password |
|---|---|---|
| Learner (profile step required) | learner@example.com | learner123 |
| Learner (profile completed) | member@example.com | member123 |
| Admin | admin@example.com | admin123 |

**Mock sign-up invitation code:** `EXCEL2026`

**Note:** These are development-only mock credentials, not production accounts. Mock data is maintained in memory, so sessions and registrations reset when the application restarts or the browser page is refreshed.

## 8. Application Architecture

The programme data layer follows a service-based architecture:

```text
UI Screens
    |
    v
ProgramStore
    |
    v
ProgramRepository
    |
    v
ProgramService
    |
    +----------------------+
    |          |           |
    v          v           v
Mock       API Service   Firebase Service
Service                  (Future implementation)
    |
    v
Mock API and Local Programme Data
```

### Main Components

- **ProgramStore:** Manages UI-facing programme state.
- **ProgramRepository:** Connects application state with the selected data service.
- **ProgramService:** Defines the backend-facing service contract.
- **MockProgramService:** Provides mock programme data for local development.
- **ApiProgramService:** Supports the HTTP API integration path.
- **FirebaseProgramService:** Provides the planned boundary for Firestore integration.

The application is designed to allow different programme service implementations without requiring major changes to the programme screens.

### Programme Data Handling

The data layer supports:

- Programme listing and details.
- Search and category filtering.
- Programme registration.
- Learner-specific registration state.
- Loading and error handling.
- Empty states and manual retry controls.
- Duplicate registration handling through a typed `alreadyRegistered` error.

The mock registration state resets when the application restarts.

## 9. Firebase Integration

Firebase-related dependencies and platform configuration have been added to the project.

The intended Firebase integration includes:

- Firebase Core initialization.
- Firebase Authentication for user authentication.
- Cloud Firestore for programme and registration data.
- Firebase-compatible document identifiers.
- A service-based architecture for future Firestore implementation.

**Current integration status:** The Firebase service is a planned integration boundary. The mock implementation remains available for local development. Do not assume that live Firestore operations or production authentication are fully implemented.

### Proposed Firestore Collections

Programme collection:

```text
programs/{programId}
```

Programme registration collection:

```text
program_registrations/{registrationId}
```

A registration is expected to contain:

```text
programId
learnerId
status
registeredAt
```

The future Firebase implementation should preserve the existing `ProgramService` contract so that the UI and `ProgramStore` can continue using the same architecture.

## 10. Project Structure

The main Flutter application code is organized around the following areas. Check the actual repository for the complete directory structure.

```text
excelerate-engagement-app/
|
├── android/
├── lib/
├── test/
├── assets/
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

| File or directory | Description |
|---|---|
| `lib/` | Main Flutter application source code |
| `test/` | Unit and widget tests |
| `assets/` | Application resources, if configured |
| `android/` | Android platform configuration |
| `pubspec.yaml` | Project dependencies and configuration |
| `README.md` | Project documentation |

## 11. Testing and Validation

The following commands can be used to validate the application:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

To test the mock application:

```bash
flutter run --dart-define=USE_MOCK=true
```

Run these checks in your current development environment and update this section with the actual results before submission.

## 12. Future Improvements

Planned improvements include:

1. Complete Firebase Authentication integration.
2. Implement real Firestore programme and registration operations.
3. Improve learner profile management.
4. Add complete admin programme management functionality.
5. Add application tracking and notifications.
6. Improve CV and document upload functionality.
7. Add interview scheduling and offer management.
8. Improve application security and role-based access control.
9. Expand automated testing and error handling.
10. Improve accessibility and responsive UI design.

## 13. Contribution

Contributions from project collaborators are welcome.

Suggested contribution workflow:

1. Clone the repository.
2. Create a feature branch.
3. Implement your changes.
4. Test the application.
5. Commit and push your changes.
6. Submit a pull request for review.

## 14. Repository

**GitHub Repository:**  
https://github.com/Ruby160612/excelerate-engagement-app

---

**Excelerate Talent Hub — Connecting learners, talent, and opportunities.**
