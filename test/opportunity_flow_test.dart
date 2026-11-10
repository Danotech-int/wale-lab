import 'package:excelerate_talent_hub/main.dart';
import 'package:excelerate_talent_hub/services/api_service.dart';
import 'package:excelerate_talent_hub/services/mock_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MockApi mock;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2030, 1, 1);
    mock = MockApi(latency: Duration.zero, now: () => now);
  });

  Future<ApiService> signIn(String account) async {
    final api = ApiService(baseUrl: MockApi.baseUrl, client: mock.client);
    addTearDown(api.dispose);
    final session = await api.post('/auth/login', {
      'email': '$account@example.com',
      'password': '${account}123',
    }) as Map;
    api.sessionToken = session['token'] as String;
    return api;
  }

  Map<String, dynamic> opportunity() => {
        'title': 'Junior analyst',
        'company': 'Excelerate',
        'location': 'Lagos',
        'description': 'Help our team understand customer data.',
        'deadline': now.add(const Duration(days: 1)).toIso8601String(),
      };

  Matcher status(int code) => throwsA(isA<ApiException>()
      .having((error) => error.statusCode, 'HTTP status', code));

  test(
      'publishing, applying and shortlisting connects both roles with scoped data',
      () async {
    final admin = await signIn('admin');
    final member = await signIn('member');
    final other = await signIn('learner');
    await other.put('/profiles/me', {});
    final published = await admin.post('/opportunities', opportunity()) as Map;
    final id = published['id'];
    final listed = await member.get('/opportunities') as List;
    expect(listed.single['title'], 'Junior analyst');
    expect(listed.single['has_applied'], isFalse);

    // The backend derives candidate identity and status, ignoring supplied values.
    final application = await member.post('/opportunities/$id/apply', {
      'learner_id': 'another-user',
      'status': 'shortlisted',
    }) as Map;
    expect(application['candidate_name'], 'Kofi Member');
    expect(application['candidate_email'], 'member@example.com');
    expect(application['status'], 'submitted');
    expect((await other.get('/applications/me') as List), isEmpty);
    expect((await admin.get('/applications') as List).single['id'],
        application['id']);
    expect((await member.get('/opportunities') as List).single['has_applied'],
        isTrue);
    expect((await other.get('/opportunities') as List).single['has_applied'],
        isFalse);
    await expectLater(member.post('/opportunities/$id/apply', {}), status(409));
    expect(await admin.get('/applications?status=shortlisted'), isEmpty);
    await admin
        .put('/applications/${application['id']}', {'status': 'shortlisted'});
    expect((await admin.get('/applications?status=shortlisted') as List),
        hasLength(1));
    expect((await member.get('/applications/me') as List).single['status'],
        'shortlisted');
    await other.post('/opportunities/$id/apply', {});
    expect((await admin.get('/applications') as List), hasLength(2));
    expect((await member.get('/applications/me') as List), hasLength(1));
  });

  test('recruitment endpoints enforce authentication, roles and onboarding',
      () async {
    final guest = ApiService(baseUrl: MockApi.baseUrl, client: mock.client);
    addTearDown(guest.dispose);
    await expectLater(guest.get('/opportunities'), status(401));
    final admin = await signIn('admin');
    final member = await signIn('member');
    final learner = await signIn('learner');
    await expectLater(
        member.post('/opportunities', opportunity()), status(403));
    final published = await admin.post('/opportunities', opportunity()) as Map;
    final path = '/opportunities/${published['id']}/apply';
    await expectLater(admin.post(path, {}), status(403));
    await expectLater(learner.post(path, {}), status(403));
    await expectLater(member.get('/applications'), status(403));
    await expectLater(
        member.put('/applications/any', {'status': 'shortlisted'}),
        status(403));
    await expectLater(
        member.post('/opportunities/missing/apply', {}), status(404));
    await expectLater(
        admin.put('/applications/missing', {'status': 'shortlisted'}),
        status(404));
  });

  test('invalid publication and closed or duplicate applications are rejected',
      () async {
    final admin = await signIn('admin');
    final member = await signIn('member');
    await expectLater(admin.post('/opportunities', {}), status(400));
    await expectLater(
        admin.post('/opportunities', {...opportunity(), 'deadline': 'invalid'}),
        status(400));
    await expectLater(
        admin.post('/opportunities', {
          ...opportunity(),
          'deadline': now.subtract(const Duration(days: 1)).toIso8601String(),
        }),
        status(400));
    final published = await admin.post('/opportunities', opportunity()) as Map;
    final path = '/opportunities/${published['id']}/apply';
    final application = await member.post(path, {}) as Map;
    await expectLater(member.post(path, {}), status(409));
    await expectLater(
        admin.put('/applications/${application['id']}', {'status': 'unknown'}),
        status(400));
    now = now.add(const Duration(days: 2));
    await expectLater(member.post(path, {}), status(410));
    expect((await admin.get('/applications') as List), hasLength(1));
  });

  testWidgets(
      'admin publishes, learner applies, admin shortlists and learner sees status',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ExcelerateApp(
      preferences: await SharedPreferences.getInstance(),
      apiBaseUrl: MockApi.baseUrl,
      apiClient: MockApi(latency: Duration.zero).client,
    ));
    await tester.pumpAndSettle();

    Future<void> login(String account) async {
      await tester.enterText(
          find.byType(TextFormField).at(0), '$account@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), '${account}123');
      await tester.ensureVisible(find.text('LOGIN'));
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle();
    }

    Future<void> open(String label) async {
      final target = find.text(label).last;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> logout() async {
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
    }

    await login('admin');
    await open('Post an opportunity');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Junior analyst');
    await tester.enterText(fields.at(1), 'Excelerate');
    await tester.enterText(fields.at(2), 'Lagos');
    await tester.enterText(
        fields.at(3), 'Help our team understand customer data.');
    await open('Choose application deadline');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await open('Publish opportunity');
    expect(find.text('Your opportunity was published.'), findsOneWidget);
    await logout();

    await login('member');
    await open('Job opportunities');
    expect(find.text('Junior analyst'), findsOneWidget);
    expect(find.text('Excelerate • Lagos'), findsOneWidget);
    await open('Apply now');
    expect(find.text('Applied'), findsOneWidget);
    await open('Your applications');
    expect(find.text('Submitted'), findsOneWidget);
    await logout();

    await login('admin');
    await open('Review applications');
    expect(find.text('Kofi Member'), findsOneWidget);
    expect(find.text('member@example.com'), findsOneWidget);
    await open('Shortlist candidate');
    expect(find.text('Shortlisted'), findsWidgets);
    await logout();

    await login('member');
    await open('Your applications');
    expect(find.text('Shortlisted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
