import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../models/user.dart';
import '../utils/auth_errors.dart';
import 'api_service.dart';
import 'auth_backend.dart';
import 'storage_service.dart';

class AuthService extends ChangeNotifier {
  AuthService(this._api, this._storage, {AuthBackend? backend})
      : _backend = backend {
    _signedOut = backend?.signedOut.listen((_) {
      if (_user == null) return;
      _user = null;
      _api.sessionToken = null;
      notifyListeners();
    });
  }

  final ApiService _api;
  final StorageService _storage;
  final AuthBackend? _backend;
  StreamSubscription<void>? _signedOut;
  AppUser? _user;
  bool _initialized = false;
  String? _initializationError;

  AppUser? get user => _user;
  bool get initialized => _initialized;
  String? get initializationError => _initializationError;
  bool get requiresInvitation => _backend == null;
  bool get supportsEmailActions => _backend != null;
  bool get emailVerified => _backend?.emailVerified ?? true;

  Future<void> restoreSession() async {
    try {
      if (_backend != null) {
        _user = await _backend.restoreSession();
        return;
      }
      final token = _storage.sessionToken;
      if (token != null) {
        _api.sessionToken = token;
        _user = AppUser.fromJson(
          await _api.get('/auth/me') as Map<String, dynamic>,
        );
      }
    } catch (error) {
      _api.sessionToken = null;
      _user = null;
      _initializationError = _backend == null
          ? 'Your saved session could not be restored. Please sign in again.'
          : authErrorMessage(error);
      if (error is ApiException && error.statusCode == 401) {
        try {
          await _storage.clearSession();
        } catch (_) {/* Retry on login. */}
      }
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    if (_backend != null) {
      _user = await _backend.login(email.trim(), password);
      _initializationError = null;
      notifyListeners();
      return;
    }
    await _acceptSession(await _api.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    }) as Map<String, dynamic>);
  }

  Future<void> signup(String name, String email, String password,
      [String invitationCode = '']) async {
    if (_backend != null) {
      _user = await _backend.signup(name.trim(), email.trim(), password);
      _initializationError = null;
      notifyListeners();
      return;
    }
    await _acceptSession(await _api.post('/auth/signup', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'invitation_code': invitationCode.trim(),
    }) as Map<String, dynamic>);
  }

  Future<void> _acceptSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    if (token.isEmpty) {
      throw const ApiException('The session token is missing.');
    }
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveSession(token);
    _api.sessionToken = token;
    _user = user;
    _initializationError = null;
    notifyListeners();
  }

  Future<void> createProfile(Profile profile) async {
    if (_backend != null) {
      _user = await _backend.createProfile(profile);
      notifyListeners();
      return;
    }
    await _api.put('/profiles/me', profile.toJson());
    // Refresh authoritative user state after the server completes onboarding.
    _user =
        AppUser.fromJson(await _api.get('/auth/me') as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> logout() async {
    // Do not clear the visible account if Firebase could not sign it out.
    if (_backend != null) {
      await _backend.logout();
      _user = null;
      _initializationError = null;
      notifyListeners();
      return;
    }
    try {
      await _storage.clearSession();
    } finally {
      _api.sessionToken = null;
      _user = null;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    if (_backend == null) {
      throw const ApiException(
          'Password reset is not available in the mock demo.');
    }
    await _backend.resetPassword(email.trim());
  }

  Future<void> sendEmailVerification() async {
    await _backend?.sendEmailVerification();
  }

  Future<void> refreshUser() async {
    if (_backend == null) return;
    _user = await _backend.refreshUser();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_signedOut?.cancel());
    super.dispose();
  }
}
