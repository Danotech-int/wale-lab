import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../models/user.dart';
import 'mock_data.dart';
import 'mock_recruitment_store.dart';

class _Account {
  _Account({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.role = UserRole.learner,
    this.profileCompleted = false,
  });

  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  bool profileCompleted;

  Map<String, dynamic> toJson() => AppUser(
        id: id,
        name: name,
        email: email,
        role: role,
        profileCompleted: profileCompleted,
      ).toJson();
}

/// Demo backend. An optional store persists recruitment records locally;
/// authentication and programme registrations remain in memory.
class MockApi {
  MockApi({
    this.latency = const Duration(milliseconds: 250),
    Future<List<Map<String, dynamic>>> Function()? programLoader,
    DateTime Function()? now,
    MockRecruitmentStore? recruitmentStore,
  })  : _programLoader = programLoader ?? _defaultLoader,
        _now = now ?? DateTime.now,
        _recruitmentStore = recruitmentStore;

  static const baseUrl = 'https://mock.excelerate.local/api';
  static const invitationCode = 'EXCEL2026';

  static List<Map<String, dynamic>>? _cachedPrograms;

  /// Reads the programs asset ahead of time for tests that cannot wait on file I/O.
  static Future<void> preloadPrograms() async =>
      _cachedPrograms = await loadMockPrograms();

  static Future<List<Map<String, dynamic>>> _defaultLoader() async =>
      _cachedPrograms ?? await loadMockPrograms();

  final Duration latency;
  final DateTime Function() _now;
  final MockRecruitmentStore? _recruitmentStore;
  Future<void>? _pending;
  final Future<List<Map<String, dynamic>>> Function() _programLoader;
  List<Map<String, dynamic>>? _programs;
  Set<String> _defaultRegistered = {};
  final Map<String, _Account> _accounts = {
    'learner@example.com': _Account(
      id: 'u-learner',
      name: 'Ada Learner',
      email: 'learner@example.com',
      password: 'learner123',
    ),
    'member@example.com': _Account(
      id: 'u-member',
      name: 'Kofi Member',
      email: 'member@example.com',
      password: 'member123',
      profileCompleted: true,
    ),
    'admin@example.com': _Account(
      id: 'u-admin',
      name: 'Zainab Admin',
      email: 'admin@example.com',
      password: 'admin123',
      role: UserRole.admin,
      profileCompleted: true,
    ),
  };
  final Map<String, _Account> _tokens = {};
  final Map<String, Set<String>> _registrations = {};
  final Map<String, Map<String, dynamic>> _opportunities = {};
  final Map<String, Map<String, dynamic>> _applications = {};
  var _nextId = 1;

  http.Client get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) {
    if (_recruitmentStore == null) return _handleRequest(request);
    // Keep reads and writes ordered inside this mock instance.
    final response =
        _pending?.then((_) => _handleStored(request)) ?? _handleStored(request);
    _pending = response.then<void>((_) {},
        onError: (Object error, StackTrace stack) {});
    return response;
  }

  Future<http.Response> _handleStored(http.Request request) async {
    final store = _recruitmentStore;
    if (store == null) return _handleRequest(request);
    await store.reload();
    _opportunities.addAll(store.read('opportunities'));
    _applications.addAll(store.read('applications'));
    final oldApplications = {
      for (final item in _applications.entries)
        item.key: Map<String, dynamic>.of(item.value),
    };
    final oldOpportunities =
        Map<String, Map<String, dynamic>>.of(_opportunities);
    final response = await _handleRequest(request);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        !{'POST', 'PUT'}.contains(request.method)) {
      return response;
    }
    final path = request.url.path.replaceFirst(RegExp(r'^/api'), '');
    final collection = path == '/opportunities'
        ? 'opportunities'
        : path.endsWith('/apply') || path.startsWith('/applications/')
            ? 'applications'
            : null;
    if (collection == null) return response;
    try {
      await store.save(
          collection, jsonDecode(response.body) as Map<String, dynamic>);
      return response;
    } catch (_) {
      _applications
        ..clear()
        ..addAll(oldApplications);
      _opportunities
        ..clear()
        ..addAll(oldOpportunities);
      return _error(503, 'Unable to save your changes. Please try again.');
    }
  }

  Future<http.Response> _handleRequest(http.Request request) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final path = request.url.path.replaceFirst(RegExp(r'^/api'), '');
    final route = '${request.method} $path';

    switch (route) {
      case 'POST /auth/login':
        return _login(_body(request));
      case 'POST /auth/signup':
        return _signup(_body(request));
    }

    final account = _authenticate(request);
    if (account == null) return _error(401, 'Please sign in again.');
    final admin = account.role == UserRole.admin;

    switch (route) {
      case 'GET /auth/me':
        return _json(account.toJson());
      case 'PUT /profiles/me':
        account.profileCompleted = true;
        return _json({'user_id': account.id, ..._body(request)});
      case 'POST /profiles/me/cv':
        return http.Response('', 204);
      case 'GET /programs':
        return _json(await _programsFor(account));
      case 'GET /announcements':
        return _json([
          for (final announcement in mockAnnouncements)
            if (announcement['audience'] == 'all' ||
                announcement['audience'] == account.role.name)
              announcement,
        ]);
      case 'GET /assessments/me':
      case 'GET /badges/me':
        return _json([]);
      case 'GET /opportunities':
        return _json([
          for (final opportunity in _opportunities.values.toList().reversed)
            {
              ...opportunity,
              'has_applied': _applications.values.any((application) =>
                  application['opportunity_id'] == opportunity['id'] &&
                  application['learner_id'] == account.id),
            },
        ]);
      case 'GET /applications/me':
        if (admin) return _error(403, 'Learners only.');
        return _json(_applications.values
            .where((application) => application['learner_id'] == account.id)
            .toList()
            .reversed
            .toList());
      case 'GET /applications':
        if (!admin) return _error(403, 'Admins only.');
        final status = request.url.queryParameters['status'];
        return _json(_applications.values
            .where((application) =>
                status == null || application['status'] == status)
            .toList()
            .reversed
            .toList());
      case 'POST /opportunities':
        return admin
            ? _publishOpportunity(account, _body(request))
            : _error(403, 'Admins only.');
      case 'POST /interviews':
        return admin ? _json({}, 201) : _error(403, 'Admins only.');
    }

    final segments = path.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.length == 3 &&
        segments.first == 'opportunities' &&
        segments[2] == 'apply' &&
        request.method == 'POST') {
      if (admin) return _error(403, 'Only learners can apply.');
      if (!account.profileCompleted) {
        return _error(403, 'Complete your profile before applying.');
      }
      return _apply(account, segments[1]);
    }
    if (segments.length >= 2 && segments.first == 'programs') {
      final program = (await _programsFor(account))
          .where((p) => p['id']?.toString() == segments[1])
          .firstOrNull;
      if (program == null) return _error(404, 'Program not found.');
      if (segments.length == 2 && request.method == 'GET') {
        return _json(program);
      }
      if (segments.length == 3 &&
          (segments[2] == 'register' || segments[2] == 'registrations') &&
          request.method == 'POST') {
        if (admin) {
          return _error(403, 'Admins cannot register for programs.');
        }
        if (!_registrationsFor(account).add(segments[1])) {
          return _error(409, 'Already registered for this program.');
        }
        // This fake backend owns IDs, status and timestamps, just as a real
        // trusted registration operation will. The Flutter request sends {}.
        return _json({
          ...program,
          'is_registered': true,
          'registration': {
            'id': 'registration-${_nextId++}',
            'programId': segments[1],
            'learnerId': account.id,
            'status': 'registered',
            'registeredAt': DateTime.now().toUtc().toIso8601String(),
          },
        });
      }
    }
    if (request.method == 'PUT' &&
        segments.length == 2 &&
        segments.first == 'applications') {
      if (!admin) return _error(403, 'Admins only.');
      final application = _applications[segments[1]];
      if (application == null) return _error(404, 'Application not found.');
      final status = _body(request)['status'];
      if (!{'submitted', 'reviewing', 'shortlisted', 'rejected'}
          .contains(status)) {
        return _error(400, 'Choose a valid application status.');
      }
      application['status'] = status;
      return _json(application);
    }
    return _error(404, 'Not found.');
  }

  http.Response _publishOpportunity(_Account admin, Map<String, dynamic> body) {
    const fields = ['title', 'company', 'description', 'location'];
    if (fields.any((key) =>
        body[key] is! String || (body[key] as String).trim().isEmpty)) {
      return _error(400, 'Enter a title, company, description and location.');
    }
    final deadline = body['deadline'] is String
        ? DateTime.tryParse(body['deadline'] as String)
        : null;
    if (deadline == null || !deadline.isAfter(_now())) {
      return _error(400, 'Choose an application deadline in the future.');
    }
    final id = _uniqueId('opportunity');
    final opportunity = {
      'id': id,
      for (final key in fields) key: (body[key] as String).trim(),
      'deadline': deadline.toUtc().toIso8601String(),
      'published_by': admin.id,
      'created_at': _now().toUtc().toIso8601String(),
    };
    _opportunities[id] = opportunity;
    return _json(opportunity, 201);
  }

  http.Response _apply(_Account learner, String opportunityId) {
    final opportunity = _opportunities[opportunityId];
    if (opportunity == null) return _error(404, 'Opportunity not found.');
    if (!DateTime.parse(opportunity['deadline'] as String).isAfter(_now())) {
      return _error(410, 'Applications for this opportunity have closed.');
    }
    if (_applications.values.any((application) =>
        application['opportunity_id'] == opportunityId &&
        application['learner_id'] == learner.id)) {
      return _error(409, 'You have already applied for this opportunity.');
    }
    // One persistent record per learner and role, even when two tabs submit.
    final id = 'application-$opportunityId-${learner.id}';
    final application = {
      'id': id,
      'opportunity_id': opportunityId,
      'opportunity_title': opportunity['title'],
      'company': opportunity['company'],
      'learner_id': learner.id,
      'candidate_name': learner.name,
      'candidate_email': learner.email,
      'status': 'submitted',
      'created_at': _now().toUtc().toIso8601String(),
    };
    _applications[id] = application;
    return _json(application, 201);
  }

  http.Response _login(Map<String, dynamic> body) {
    final email = (body['email'] as String? ?? '').trim().toLowerCase();
    final account = _accounts[email];
    if (account == null || account.password != body['password']) {
      return _error(401, 'Invalid email or password.');
    }
    return _session(account);
  }

  http.Response _signup(Map<String, dynamic> body) {
    final email = (body['email'] as String? ?? '').trim().toLowerCase();
    if (body['invitation_code'] != invitationCode) {
      return _error(400, 'Invalid invitation code.');
    }
    if (_accounts.containsKey(email)) {
      return _error(409, 'An account with this email already exists.');
    }
    final account = _Account(
      id: _uniqueId('u-new'),
      name: (body['name'] as String? ?? '').trim(),
      email: email,
      password: body['password'] as String? ?? '',
    );
    _accounts[email] = account;
    _registrations[account.id] = {};
    return _session(account);
  }

  http.Response _session(_Account account) {
    final token = 'mock-token-${_nextId++}-${account.id}';
    _tokens[token] = account;
    return _json({'token': token, 'user': account.toJson()});
  }

  String _uniqueId(String prefix) {
    final random = Random.secure();
    final suffix = List.generate(
            4,
            (_) =>
                random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'))
        .join();
    return '$prefix-$suffix';
  }

  _Account? _authenticate(http.Request request) {
    final header = request.headers['Authorization'] ?? '';
    return header.startsWith('Bearer ')
        ? _tokens[header.substring('Bearer '.length)]
        : null;
  }

  Future<List<Map<String, dynamic>>> _loadPrograms() async {
    final loaded = _programs;
    if (loaded != null) return loaded;
    final data = await _programLoader();
    _defaultRegistered = {
      for (final json in data)
        if (json['is_registered'] == true && json['id'] != null)
          json['id'].toString(),
    };
    return _programs = data;
  }

  Set<String> _registrationsFor(_Account account) => _registrations.putIfAbsent(
      account.id,
      () => account.role == UserRole.learner ? {..._defaultRegistered} : {});

  Future<List<Map<String, dynamic>>> _programsFor(_Account account) async {
    final programs = await _loadPrograms();
    final registered = _registrationsFor(account);
    return [
      for (final json in programs)
        {...json, 'is_registered': registered.contains(json['id']?.toString())},
    ];
  }

  Map<String, dynamic> _body(http.Request request) => request.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(request.body) as Map<String, dynamic>;

  http.Response _json(Object? body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  http.Response _error(int status, String message) =>
      _json({'message': message}, status);
}
