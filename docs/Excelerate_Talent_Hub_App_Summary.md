# Excelerate Talent Hub
## Application overview, current stage and future development

Prepared 10 November 2026 · Version 1.0.0+1

### Purpose of the application

Excelerate Talent Hub is a private talent development and recruitment application. It brings learning opportunities, learner profiles and recruitment activity into one place, giving learners a clear route from building skills to applying for work and giving administrators a workspace for finding and progressing candidates.

The application has two main audiences. Learners explore development programmes, review eligibility and schedules, register interest, maintain their professional information and apply for published roles. Administrators publish job opportunities, review applications, identify candidates and prepare the next recruitment steps.

### Current stage

**Working prototype with local mock data.** The application has progressed beyond an initial folder structure: it contains branded screens, protected learner and administrator routes, a reusable data layer, programme discovery and a demonstrable publish–apply–shortlist journey. It is suitable for demonstrations, workflow feedback and further device testing.

The next major milestone is a shared backend pilot. Recruitment records currently persist on the browser or device used for the demo. They do not synchronise between a phone and a computer, or between unrelated browser profiles. Firebase configuration is present, but production authentication and Firestore operations are not complete.

### Value it is intended to provide

- For learners: a single place to discover learning and work opportunities and follow their application progress.
- For administrators: a central view of candidate submissions, organised by opportunity, with shortlisting and activity counts.
- For the organisation: a foundation for connecting training participation, demonstrated skills and recruitment outcomes.

### A practical example

An administrator publishes two roles. A learner sees both open opportunities and applies to each. Another learner can apply to the same roles. The administrator sees all four submissions, grouped by role, with two distinct applicants. Shortlisting a submission updates the affected learner's application status in the same local demo data store.

This report describes the current local workspace, including recent recruitment fixes. Proposed improvements are recommendations, not features already delivered or a committed release schedule.

<!-- pagebreak -->

# What users can do today

### Learner and administrator journeys

**Learner:** sign in or use an invitation to sign up → complete profile onboarding where required → explore programmes and roles → register for programmes or apply for jobs → track submitted applications and shortlisting status.

**Administrator:** sign in to the recruitment dashboard → publish an opportunity with a future deadline → review submissions grouped by role → shortlist candidates → open the interview scheduling form.

### Feature status

| Area | Current behaviour | Completion level |
| --- | --- | --- |
| Login and onboarding | Demo accounts, invitation signup, required-field validation and role-aware routing. The profile form collects a headline, biography and skills. | Working mock flow; durable account/profile storage remains to be built. |
| Learner dashboard | Displays programme registration, badge and application counts, announcements and quick links. | Implemented against the selected data source. |
| Programme discovery | Lists bundled programmes with search and category filters; details show schedules, eligibility and outcomes. Learners can register and duplicate registrations are rejected. | Working mock flow with replaceable service adapters. |
| Job opportunities | Administrators can publish multiple roles. Learners can see Open and All counts, read role details and apply once per role. Deadlines are checked. | Working local demo with persistent recruitment records. |
| Application review | Learners see their own history. Administrators see all submissions grouped by opportunity, applicant details, totals and the shortlist action. | Working local demo; multiple roles and applicants are covered by tests. |
| Announcements | Dashboards display notices for the relevant audience, with loading, empty and retry states. | Sample notices are available; publishing/editing tools are not implemented. |
| CV upload | Selects PDF, DOC or DOCX files up to 5 MB, sends a multipart upload request and remembers the filename locally. | Client implemented; the mock accepts the upload without retaining the document. |
| Assessments and badges | Models and display screens exist. | Current mock endpoints return empty lists; assessment delivery and badge-awarding logic are not implemented. |
| Interview scheduling | A form submits an application reference, location or meeting link, and date/time. | Form/API boundary exists; mock interviews are not saved and there is no calendar integration. |
| Password recovery | The login screen explains that password reset is unavailable. | Placeholder awaiting backend implementation. |

The feature labels above describe actual implementation scope. A successful mock response for CV upload or interview scheduling does not establish that a document or appointment has been stored in a live service.

<!-- pagebreak -->

# How the application works

### Application startup and navigation

The Flutter entry point initialises local preferences and selects a data source. With USE_MOCK=true it connects to an in-process MockApi. Without that flag, it initialises Firebase and follows the existing HTTP service path, which needs a compatible API address. Firebase initialisation alone does not supply the application's authentication or database operations.

Provider makes the selected services and shared state available to screens. AuthService maintains the signed-in user, while SessionGate chooses login, onboarding or the appropriate dashboard. AuthGuard checks access to private screens and administrator-only routes.

### Main information paths

<!-- architecture -->

The programme service contract lets the team replace the data source while retaining the programme screens. Programme details loaders and dashboard counts can also read directly through the repository. Recruitment and authentication currently use ApiService directly.

### Technologies and responsibilities

| Technology | Role in this project |
| --- | --- |
| Flutter and Dart | Build the shared interface and application logic. Native runner folders support Android, iOS, web, Linux, macOS and Windows projects. |
| Provider | Supplies shared services and observable state to widgets. |
| http / ApiService | Sends JSON requests and multipart CV uploads; attaches session tokens and handles unsuccessful responses and timeouts. |
| SharedPreferences | Stores the session token, CV filename and locally persisted mock recruitment records. |
| file_picker, flutter_svg and intl | Provide document selection, SVG badge rendering and date formatting. |
| Firebase packages | Supply the configuration and libraries for planned cloud work. The Firebase programme service remains a non-operational placeholder. |

### Code organisation

The code separates data models, services, shared state, screens and reusable widgets. Routes, validation and theme settings are centralised under lib/utils. Shared styling applies Excelerate orange branding, consistent spacing and responsive layouts. Native platform targets still require their own build tools and acceptance tests.

<!-- pagebreak -->

# Current development stage

### What has been achieved

The project now has a functioning application structure, branded learner/admin experiences, programme discovery and registration, and the core recruitment demonstration. Recent changes preserve multiple opportunities and submissions, group administrator reviews by opportunity, display counts and repair list refresh behaviour. Recruitment lists refresh every 15 seconds while active, on app resume and through manual controls.

### Where information currently lives

| Information | Current storage and behaviour |
| --- | --- |
| Programme catalogue | Bundled assets/data/programs.json, loaded by the mock data service. Editing it changes the sample catalogue, not a cloud database. |
| Programme registrations | Per-learner sets in mock memory. These reset when the mock backend restarts. |
| Opportunities and job applications | Separate locally saved records through MockRecruitmentStore. IDs distinguish roles; application records identify a learner-role pair. These survive reloads within the same browser/device storage. |
| Demo sessions and new signup accounts | Accounts and token validity live in mock memory. A stored token can become invalid after a restart; demo users may need to sign in again. Newly created mock accounts reset. |
| Profiles and CVs | Mock onboarding marks the profile complete in memory. Full profile content and CV documents are not durably stored by the mock. Only the CV filename is remembered locally. |
| Interviews, assessments and earned badges | No completed persistent backend implementation. Interview requests are acknowledged; assessment and badge lists are empty in the mock. |

### Validation and readiness

The latest completed checks in this collaboration reported clean Flutter static analysis and 157 passing automated tests. Coverage includes login and role restrictions, programme parsing/search/registration, multiple roles and applicants, local recruitment persistence, duplicate prevention, deadlines, failed saves and manual/automatic refresh.

The Android build guide records a successful debug APK build on 23 October 2026. That record predates the newest recruitment changes and does not certify the latest version on a physical device. A complete acceptance run on the intended phones and browsers is still a release milestone.

This document is a source review and summary of previously completed validation; the application test suite and device builds were not rerun solely to create this report.

### Readiness assessment

**Current assessment: local demonstration and functional prototype testing.** A multi-user pilot requires shared persistent storage, trusted authentication and authorisation, durable profiles/documents and verified cross-device workflows. Production release additionally needs operational monitoring, privacy controls, release signing and a documented support process.

<!-- pagebreak -->

# Further implementations and priorities

The following sequence is proposed to move from a local demonstration to a shared platform. No dates or delivery estimates are implied.

### Priority 1 — Establish a shared backend pilot

- Complete authentication, account persistence, invitation validation, password recovery and session lifecycle handling. Replace development token storage with an appropriate production session approach.
- Implement the intended Firestore service or a compatible trusted HTTP backend. Persist users, profiles, programmes, registrations, opportunities, applications and interview records.
- Enforce learner/admin permissions and record ownership in the backend. Make duplicate registration/application checks atomic and let the backend own identifiers, status changes and timestamps.
- Add protected document storage for CVs, link uploaded documents to applications and provide authorised recruiter access.
- Preserve mock mode for development while checking that the live adapter follows the same service contracts.

**Acceptance milestone:** an administrator publishes on a computer, a learner sees and applies on a phone, and the administrator receives the application. Data and account access remain correct after restart and across devices.

### Priority 2 — Complete learning and recruitment workflows

- Add administrator tools to create, edit, close and archive opportunities and manage programme availability, capacity and eligibility.
- Add richer candidate profiles, controlled CV review, notes, applicant search and role/status filters, plus a clear application lifecycle through interview and outcome.
- Build persistent interview scheduling with time-zone handling, rescheduling, reminders and optional calendar integration.
- Implement assessment questions, submissions, scoring and reviewer feedback; award badges from defined achievement rules.
- Add announcement management and notification preferences for new opportunities, application updates and interview reminders.

**Acceptance milestone:** staff can manage an opportunity from publication to outcome, and learners can complete a programme/assessment journey with durable results and clear communication.

### Priority 3 — Prepare for reliable operation and growth

- Extend automated integration tests to the real backend, test common mobile devices, check accessibility and improve slow-network/offline recovery.
- Add crash/error monitoring, audit history, backup/recovery procedures, release automation and environment-specific configuration.
- Define consent, document access, retention, deletion and data-export processes suitable for the organisation's users.
- Add reporting on programme participation, application conversion and placement outcomes. Consider explainable, user-controlled opportunity matching after sufficient reliable data exists.

**Acceptance milestone:** the team can deploy, monitor and support the platform, recover data and demonstrate that access controls and important user journeys work under realistic conditions.

<!-- pagebreak -->

# Test run and handoff notes

### Run the mock version on a phone

Connect an Android phone with USB debugging enabled, authorise the computer and select its device ID:

```sh
flutter devices
flutter run -d YOUR_PHONE_DEVICE_ID --dart-define=USE_MOCK=true
```

### Run a browser demo with a stable local store

```sh
flutter run -d web-server --web-port=7357 --dart-define=USE_MOCK=true
```

Open http://localhost:7357 in a regular Chrome window. Reuse the same URL and browser profile to retain recruitment records. Different ports, browser profiles and devices use different local stores. The phone's local records are separate from the browser's. Plain flutter run does not enable mock mode.

### Development accounts

| Demo role | Email | Password |
| --- | --- | --- |
| Learner, profile complete | member@example.com | member123 |
| Learner, onboarding required | learner@example.com | learner123 |
| Administrator | admin@example.com | admin123 |

The mock invitation code is EXCEL2026. These accounts are for development demonstrations.

### Suggested acceptance exercise

1. Publish two distinct roles with future deadlines as the administrator.
2. Apply to both as the member account and confirm two entries in Your applications.
3. Complete onboarding for the second learner and apply to both roles.
4. Return to administrator review: confirm four applications from two applicants, grouped into the two roles.
5. Shortlist one submission and confirm the affected learner sees the new status.
6. Reload the application, sign in again and verify locally persisted recruitment records. Separately verify that expired roles reject applications and repeated applications are blocked.

### Source basis

This report reflects the local workspace reviewed on 10 November 2026, including recent changes that may not yet be published to GitHub. Project repository: https://github.com/Ruby160612/excelerate-engagement-app.

- Startup, navigation and roles: lib/main.dart; lib/utils/app_router.dart; lib/services/auth_service.dart.
- Data and persistence: lib/services/mock_api.dart; lib/services/mock_recruitment_store.dart; lib/services/program_repository.dart; lib/services/firebase_program_service.dart.
- Scope and verification: docs/OPPORTUNITIES_DEMO.md; docs/PROGRAM_API_CONTRACT.md; docs/ANDROID_BUILD.md; test/recruitment_persistence_test.dart; test/opportunity_flow_test.dart.

The roadmap is an assessment based on this implementation. Live backend compatibility, production readiness and physical-device results require their own verification.
