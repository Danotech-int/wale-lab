# Live Firebase authentication

Email/password authentication and learner profiles are connected to Firebase.
Google sign-in and the recruitment/programme database migration are separate
next steps.

## Run with real accounts

Stop the existing Flutter process and run:

```bash
flutter pub get
flutter run -d chrome --dart-define=USE_MOCK=false
```

For a stable browser address and persistent browser profile:

```bash
flutter run -d web-server --web-port=7357 --dart-define=USE_MOCK=false
```

Open `http://localhost:7357` in your normal browser. For a connected Android
phone, use `flutter devices`, then:

```bash
flutter run -d DEVICE_ID --dart-define=USE_MOCK=false
```

`USE_MOCK` defaults to false. Explicit `USE_MOCK=true` still selects the old
local demo accounts and invitation code; those accounts are not Firebase users.
Changing the flag requires stopping and restarting Flutter, not hot reload.
Linux desktop is not configured in `firebase_options.dart`; use Android or web.

## What is configured

Project: `excellerate-mobile-app`.

- Email/password sign-in is enabled; real signup is open without an invitation.
- `localhost` is included in Firebase Authentication's authorized domains.
- The default Cloud Firestore database uses Standard edition, Native mode,
  in `europe-west1` (Belgium). It is the project's free-tier eligible database;
  actual charges depend on usage and the project's billing configuration.
- `firestore.rules` protects `users/{uid}` and has been deployed.
- Firebase handles passwords, session persistence, and ID-token renewal. App
  code does not store real passwords or Firebase tokens in SharedPreferences.

Console:

- [Authentication users](https://console.firebase.google.com/project/excellerate-mobile-app/authentication/users)
- [Sign-in providers](https://console.firebase.google.com/project/excellerate-mobile-app/authentication/providers)
- [Firestore data](https://console.firebase.google.com/project/excellerate-mobile-app/firestore/databases/-default-/data)

## Signup, login, and names

1. Sign Up collects full name, email, and password (at least eight characters).
2. Firebase Authentication creates the account and saves its `displayName`.
3. Firestore creates a document at `users/{Firebase UID}`:

   ```text
   name, email, role: learner, profile_completed: false,
   created_at, updated_at
   ```

4. A verification email is requested. A notice offers resend and a verification
   status refresh. Email verification is currently encouraged, not a gate:
   users can complete onboarding before verifying. Sending can be throttled or
   delayed; check spam and use resend if needed.
5. Profile onboarding saves headline, bio, skills, and
   `profile_completed: true` on that same document.
6. The dashboard reads `AuthService.user.name`, so it greets the signup name.
7. Later logins and restored Firebase sessions load the same Firestore profile.

If creating the Firestore document fails after the Auth account was created,
sign in with the same email/password to retry profile initialization. The saved
Firebase display name is used to recreate the missing profile. A missing Auth
display name needs administrator correction; the app does not invent a name.

Forgot Password uses the email entered on the login screen and sends Firebase's
reset link. The confirmation does not reveal whether the address is registered.
The links use Firebase's hosted email-action handler; custom deep links are not
required for this first version.

## Access control

New users are learners. Administrators are identified using a Firebase custom
claim `admin: true`, assigned only by a trusted Admin SDK/tool. Editing a
Firestore `role` value does not grant admin access in the app.

Client rules allow reading only one's own account and editing the permitted
onboarding fields. Clients cannot list users, read another user's document,
change role/name/email fields, delete profiles, or access other collections.
Future features need their own deliberate rules and backend implementation.

For future rule changes:

```bash
firebase login
firebase deploy --only firestore:rules --project excellerate-mobile-app
```

Do not put a service-account private key into Flutter assets or source code.
The Firebase client configuration already present in the project is used by
the SDK; access is controlled by Firebase Authentication and security rules.

## What is still separate

Authentication and profile onboarding use Firebase directly and need no
`API_BASE_URL`. Programme listings/registration, opportunities/applications,
badges, announcements, CV uploads, and interview scheduling still use the
existing HTTP/mock service layer. Without a real `API_BASE_URL` those screens
show their configured unavailable/error states; real auth does not make their
mock records shared or migrate them into Firestore.

If connecting a custom HTTP API later, requests now obtain a current Firebase
ID token on every call. That API must verify it using Firebase Admin SDK;
existing demo tokens are not valid production credentials.

## Verify the flow

1. Run without mock mode and create an account using your own real email.
2. Check the new entry in Authentication → Users, and `users/{uid}` in Firestore.
3. Complete onboarding and confirm `Hello, <your signup name>`.
4. Sign out, sign in again, and confirm the name and completed profile persist.
5. Refresh the browser at the same origin and confirm the session restores.
6. Open the verification email and use "I've verified my email" in the app.
7. Sign out, enter your email, and use Forgot Password to test inbox delivery.

Automated service/widget coverage is in `test/firebase_auth_test.dart`. It tests
signup name storage, onboarding, login/restoration, external sign-out, ownership,
trusted admin claims, Firebase error messages, fresh API tokens, and signup
through to the personalized dashboard. These tests use Firebase test doubles;
live backend smoke checks separately exercise Firebase's real Auth REST API
and deployed Firestore rules. Temporary smoke-test accounts are removed.

Validation completed on 12 November 2026: all 167 Flutter tests passed,
`flutter analyze --no-pub` reported no issues, and the non-mock web build
succeeded. A headless Chrome check of that build signed in through real
Firebase, initialized and saved the onboarding profile, displayed
`Hello, Wale Browser Test`, and restored the same session/name after reloading.
The browser test account and profile were removed afterwards. Delivery to a
real inbox still needs a check using your own email address.

Google sign-in can be added to the same backend next: enable Google's provider,
configure its platform credentials, and reuse the UID-based profile flow.
