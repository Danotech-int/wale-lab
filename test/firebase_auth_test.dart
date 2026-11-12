import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excelerate_talent_hub/main.dart';
import 'package:excelerate_talent_hub/models/profile.dart';
import 'package:excelerate_talent_hub/models/user.dart';
import 'package:excelerate_talent_hub/services/api_service.dart';
import 'package:excelerate_talent_hub/services/auth_service.dart';
import 'package:excelerate_talent_hub/services/firebase_auth_backend.dart';
import 'package:excelerate_talent_hub/services/storage_service.dart';
import 'package:excelerate_talent_hub/utils/auth_errors.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase emits the current session immediately to every new subscriber.
// The upstream mock only broadcasts changes, so reproduce the SDK contract.
class _SessionMockAuth extends MockFirebaseAuth {
  _SessionMockAuth() : super(verifyEmailAutomatically: false);

  @override
  Stream<User?> authStateChanges() async* {
    yield currentUser;
    yield* super.authStateChanges();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseAuth firebaseAuth;
  late FakeFirebaseFirestore firestore;
  late FirebaseAuthBackend backend;
  late AuthService auth;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    firebaseAuth = _SessionMockAuth();
    firestore = FakeFirebaseFirestore();
    backend = FirebaseAuthBackend(auth: firebaseAuth, firestore: firestore);
    final api = ApiService(baseUrl: 'https://unused.example');
    auth = AuthService(api, storage, backend: backend);
    addTearDown(auth.dispose);
    addTearDown(api.dispose);
    await auth.restoreSession();
  });

  test(
      'signup saves entered name in Auth and Firestore without storing a token',
      () async {
    expect(auth.requiresInvitation, isFalse);
    await auth.signup('  Wale Ade  ', '  wale@example.com  ', 'password123');
    expect(auth.user!.name, 'Wale Ade');
    expect(auth.user!.email, 'wale@example.com');
    expect(auth.user!.role, UserRole.learner);
    expect(auth.user!.profileCompleted, isFalse);
    expect(firebaseAuth.currentUser!.displayName, 'Wale Ade');
    expect(auth.emailVerified, isFalse);
    expect(storage.sessionToken, isNull);
    final data = (await firestore.doc('users/${auth.user!.id}').get()).data()!;
    expect(data['name'], 'Wale Ade');
    expect(data['role'], 'learner');
    expect(data.containsKey('password'), isFalse);
    expect(data['created_at'], isA<Timestamp>());
  });

  test('profile and signup name survive logout, login and session restoration',
      () async {
    await auth.signup('Wale Ade', 'wale@example.com', 'password123');
    final uid = auth.user!.id;
    await auth.createProfile(Profile(
        userId: uid,
        headline: 'Developer',
        bio: 'Building useful products',
        skills: ['Flutter', 'Dart']));
    expect(auth.user!.profileCompleted, isTrue);
    await auth.logout();
    expect(auth.user, isNull);
    expect(firebaseAuth.currentUser, isNull);
    await auth.login('wale@example.com', 'password123');
    expect(auth.user!.id, uid);
    expect(auth.user!.name, 'Wale Ade');
    expect(auth.user!.profileCompleted, isTrue);
    final restored = await backend.restoreSession();
    expect(restored!.name, 'Wale Ade');
    expect(restored.profileCompleted, isTrue);
  });

  test('client-written admin role cannot grant administrator access', () async {
    await auth.signup('Wale', 'wale@example.com', 'password123');
    await firestore.doc('users/${auth.user!.id}').update({'role': 'admin'});
    await auth.refreshUser();
    expect(auth.user!.role, UserRole.learner);
  });

  test('only a trusted custom claim grants administrator access', () async {
    firebaseAuth.mockUser = MockUser(
        uid: 'administrator',
        email: 'admin@example.com',
        displayName: 'Administrator',
        customClaim: {'admin': true});
    await auth.login('admin@example.com', 'password123');
    expect(auth.user!.role, UserRole.admin);
  });

  test('profile belonging to another account cannot be saved', () async {
    await auth.signup('Wale', 'wale@example.com', 'password123');
    await expectLater(
        auth.createProfile(const Profile(
            userId: 'another-user',
            headline: 'Developer',
            bio: 'About me',
            skills: ['Dart'])),
        throwsA(isA<ApiException>()));
    expect((await firestore.doc('users/another-user').get()).exists, isFalse);
  });

  test('external Firebase sign-out clears app session', () async {
    await auth.signup('Wale', 'wale@example.com', 'password123');
    await firebaseAuth.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(auth.user, isNull);
  });

  test('missing profile is repaired from persisted Firebase displayName',
      () async {
    firebaseAuth.mockUser = MockUser(
        uid: 'partial-signup',
        email: 'wale@example.com',
        displayName: 'Wale Ade');
    await auth.login('wale@example.com', 'password123');
    expect(auth.user!.name, 'Wale Ade');
    expect((await firestore.doc('users/partial-signup').get()).data()!['name'],
        'Wale Ade');
  });

  test('Firebase failures show useful error messages', () {
    expect(
        authErrorMessage(FirebaseAuthException(code: 'email-already-in-use')),
        contains('already uses this email'));
    expect(authErrorMessage(FirebaseAuthException(code: 'invalid-credential')),
        'The email or password is incorrect.');
    expect(
        authErrorMessage(FirebaseException(
            plugin: 'cloud_firestore', code: 'permission-denied')),
        contains('database permissions'));
  });

  test('HTTP requests obtain a fresh Firebase token for each request',
      () async {
    var token = 'first-token';
    final api = ApiService(
        baseUrl: 'https://backend.example',
        tokenProvider: () async => token,
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer $token');
          return http.Response('[]', 200);
        }));
    addTearDown(api.dispose);
    await api.get('/programs');
    token = 'refreshed-token';
    await api.get('/programs');
  });

  testWidgets(
      'real signup needs no invitation and dashboard greets the signup name',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(ExcelerateApp(
        preferences: preferences,
        authBackend: backend,
        apiBaseUrl: 'https://backend.example',
        apiClient: MockClient((_) async => http.Response('[]', 200))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Invitation code'), findsNothing);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Wale Ade');
    await tester.enterText(fields.at(1), 'wale@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your profile'), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget);
    final profileFields = find.byType(TextFormField);
    await tester.enterText(profileFields.at(0), 'Developer');
    await tester.enterText(profileFields.at(1), 'Building useful products');
    await tester.enterText(profileFields.at(2), 'Flutter, Dart');
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Wale Ade'), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
