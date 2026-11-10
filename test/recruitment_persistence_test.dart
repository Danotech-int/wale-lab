import 'package:excelerate_talent_hub/main.dart';
import 'package:excelerate_talent_hub/services/api_service.dart';
import 'package:excelerate_talent_hub/services/mock_api.dart';
import 'package:excelerate_talent_hub/services/mock_recruitment_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  MockApi backend() => MockApi(
      latency: Duration.zero,
      recruitmentStore: MockRecruitmentStore(preferences));

  Future<ApiService> login(MockApi mock, String account) async {
    final api = ApiService(baseUrl: MockApi.baseUrl, client: mock.client);
    addTearDown(api.dispose);
    final session = await api.post('/auth/login', {
      'email': '$account@example.com',
      'password': '${account}123',
    }) as Map;
    api.sessionToken = session['token'] as String;
    return api;
  }

  Map<String, dynamic> role(String title) => {
        'title': title,
        'company': 'Excelerate',
        'location': 'Lagos',
        'description': 'Join our team as $title.',
        'deadline': DateTime.now()
            .add(const Duration(days: 30))
            .toUtc()
            .toIso8601String(),
      };

  test(
      'multiple jobs and applicants survive new backend instances without overwrites',
      () async {
    final admin = await login(backend(), 'admin');
    final anotherAdmin = await login(backend(), 'admin');
    final jobs = await Future.wait([
      admin.post('/opportunities', role('Junior analyst')),
      anotherAdmin.post('/opportunities', role('Support associate')),
      admin.post('/opportunities', role('Project assistant')),
    ]);
    final ids = jobs.map((job) => (job as Map)['id'] as String).toList();
    expect(ids.toSet(), hasLength(3));
    final member = await login(backend(), 'member');
    final learner = await login(backend(), 'learner');
    await learner.put('/profiles/me', {});
    expect(await member.get('/opportunities'), hasLength(3));
    await Future.wait([
      member.post('/opportunities/${ids[0]}/apply', {}),
      member.post('/opportunities/${ids[1]}/apply', {}),
      learner.post('/opportunities/${ids[0]}/apply', {}),
      learner.post('/opportunities/${ids[2]}/apply', {}),
    ]);
    final restoredAdmin = await login(backend(), 'admin');
    final applications = await restoredAdmin.get('/applications') as List;
    expect(applications, hasLength(4));
    expect(applications.map((a) => a['learner_id']).toSet(), hasLength(2));
    expect(applications.map((a) => a['id']).toSet(), hasLength(4));
    expect(await member.get('/applications/me'), hasLength(2));
    expect(await learner.get('/applications/me'), hasLength(2));
    await restoredAdmin.put(
        '/applications/${applications.first['id']}', {'status': 'shortlisted'});
    expect(await admin.get('/applications?status=shortlisted'), hasLength(1));

    final restoredMember = await login(backend(), 'member');
    expect(await restoredMember.get('/applications/me'), hasLength(2));
    final visible = await restoredMember.get('/opportunities') as List;
    expect(visible.where((job) => job['has_applied'] == true), hasLength(2));
    await expectLater(
        restoredMember.post('/opportunities/${ids[0]}/apply', {}),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    await restoredAdmin.post('/opportunities', role('Fourth role'));
    expect(await restoredMember.get('/opportunities'), hasLength(4));
    expect(await restoredAdmin.get('/applications'), hasLength(4));
  });

  test(
      'simultaneous submissions from separate instances retain one application per role and learner',
      () async {
    final admin = await login(backend(), 'admin');
    final job =
        await admin.post('/opportunities', role('Junior analyst')) as Map;
    final first = await login(backend(), 'member');
    final second = await login(backend(), 'member');
    final path = '/opportunities/${job['id']}/apply';
    await Future.wait([first, second].map((api) async {
      try {
        await api.post(path, {});
      } on ApiException catch (error) {
        expect(error.statusCode, 409);
      }
    }));
    expect(await admin.get('/applications'), hasLength(1));
  });

  testWidgets(
      'all opportunities and applications survive reload and admin list refreshes for every applicant',
      (tester) async {
    final admin = await login(backend(), 'admin');
    await admin.post('/opportunities', role('Junior analyst'));
    await admin.post('/opportunities', role('Support associate'));
    final pastBackend = MockApi(
        latency: Duration.zero,
        now: () => DateTime.utc(2000),
        recruitmentStore: MockRecruitmentStore(preferences));
    final pastAdmin = await login(pastBackend, 'admin');
    await pastAdmin.post('/opportunities', {
      ...role('Expired role'),
      'deadline': DateTime.utc(2001).toIso8601String(),
    });

    Future<void> launch(String account) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      // A new MockApi simulates refreshing the page or opening another instance.
      await tester.pumpWidget(ExcelerateApp(
          preferences: preferences,
          apiBaseUrl: MockApi.baseUrl,
          apiClient: backend().client));
      await tester.pumpAndSettle();
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

    await launch('member');
    await open('Job opportunities');
    expect(find.text('Open (2)'), findsOneWidget);
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Expired role'), findsNothing);
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Expired role'), findsOneWidget);
    expect(find.text('Applications closed'), findsOneWidget);
    await tester.tap(find.text('Open (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Junior analyst'), findsOneWidget);
    expect(find.text('Support associate'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Apply now').first);
      await tester.tap(find.text('Apply now').first);
      await tester.pumpAndSettle();
    }
    expect(find.text('Applied'), findsNWidgets(2));
    await open('Refresh opportunities');
    expect(find.text('Applied'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await open('Your applications');
    expect(find.text('2 applications'), findsOneWidget);
    await launch('member');
    await open('Your applications');
    expect(find.text('2 applications'), findsOneWidget);
    expect(find.text('Junior analyst'), findsOneWidget);
    expect(find.text('Support associate'), findsOneWidget);

    await launch('admin');
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('metric-Applications received')))
            .data,
        '2');
    await open('Review applications');
    expect(find.text('2 applications from 1 applicant'), findsOneWidget);

    final learner = await login(backend(), 'learner');
    await learner.put('/profiles/me', {});
    final jobs = await learner.get('/opportunities') as List;
    for (final job in jobs) {
      if (DateTime.parse(job['deadline'] as String).isAfter(DateTime.now())) {
        await learner.post('/opportunities/${job['id']}/apply', {});
      }
    }
    // The open admin page must pick up applications from another mock instance.
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('4 applications from 2 applicants'), findsOneWidget);
    expect(find.text('Junior analyst (2)'), findsOneWidget);
    expect(find.text('Support associate (2)'), findsOneWidget);
    expect(find.text('member@example.com'), findsNWidgets(2));
    expect(find.text('learner@example.com'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Refresh list'));
    await tester.pumpAndSettle();
    expect(find.text('4 applications from 2 applicants'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('a failed save is reported without a phantom published role', () async {
    final broken = MockApi(
        latency: Duration.zero, recruitmentStore: _FailingStore(preferences));
    final admin = await login(broken, 'admin');
    await expectLater(
        admin.post('/opportunities', role('Unsaved role')),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
    expect(await admin.get('/opportunities'), isEmpty);
    expect(
        await (await login(backend(), 'admin')).get('/opportunities'), isEmpty);
  });
}

class _FailingStore extends MockRecruitmentStore {
  _FailingStore(super.preferences);

  @override
  Future<void> save(String collection, Map<String, dynamic> record) async {
    throw StateError('Storage unavailable');
  }
}
