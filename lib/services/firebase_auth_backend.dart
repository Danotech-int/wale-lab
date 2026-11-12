import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/profile.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'auth_backend.dart';

class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuthBackend(
      {required FirebaseAuth auth, required FirebaseFirestore firestore})
      : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<void> get signedOut =>
      _auth.authStateChanges().where((user) => user == null).map((_) {});

  @override
  bool get emailVerified => _auth.currentUser?.emailVerified ?? false;

  @override
  Future<AppUser?> restoreSession() async {
    final user = await _auth.authStateChanges().first;
    if (user == null) return null;
    await user.reload();
    return _loadUser(_requireUser());
  }

  @override
  Future<AppUser> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    return _loadUser(credential.user!);
  }

  @override
  Future<AppUser> signup(String name, String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    final user = credential.user!;
    try {
      await user.updateDisplayName(name.trim());
      final account = await _loadUser(user, signupName: name.trim());
      // Verification delivery must not turn a successfully created account
      // into a failed signup. The app offers resend and refresh controls.
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException {
        // The user can retry from the verification notice.
      }
      return account;
    } catch (_) {
      throw const ApiException('Your account was created, but setup could not '
          'finish. Please sign in with the same email and password to retry.');
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ApiException('Your session has ended. Please sign in again.');
    }
    return user;
  }

  Future<AppUser> _loadUser(User user, {String? signupName}) async {
    final reference = _firestore.collection('users').doc(user.uid);
    // Transactions avoid overwriting a profile if two sessions initialize it.
    final data = await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) return snapshot.data()!;
      final name = signupName ?? user.displayName?.trim();
      if (name == null || name.isEmpty) {
        throw const ApiException('Your account has no signup name. '
            'Please contact your administrator to complete your account.');
      }
      final document = <String, dynamic>{
        'name': name,
        'email': user.email!,
        'role': 'learner',
        'profile_completed': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      transaction.set(reference, document);
      return document;
    });
    // Administrator access comes only from trusted Firebase custom claims.
    final token = await user.getIdTokenResult();
    return AppUser(
      id: user.uid,
      name: data['name'] as String,
      email: user.email!,
      role: token.claims?['admin'] == true ? UserRole.admin : UserRole.learner,
      profileCompleted: data['profile_completed'] == true,
    );
  }

  @override
  Future<AppUser> createProfile(Profile profile) async {
    final user = _requireUser();
    if (profile.userId != user.uid) {
      throw const ApiException('You can only update your own profile.');
    }
    await _firestore.collection('users').doc(user.uid).update({
      'headline': profile.headline,
      'bio': profile.bio,
      'skills': profile.skills,
      'profile_completed': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
    return _loadUser(user);
  }

  @override
  Future<AppUser> refreshUser() async {
    await _requireUser().reload();
    return _loadUser(_requireUser());
  }

  @override
  Future<void> sendEmailVerification() =>
      _requireUser().sendEmailVerification();

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Use the same confirmation whether or not an account exists.
      if (error.code != 'user-not-found') rethrow;
    }
  }

  @override
  Future<void> logout() => _auth.signOut();
}
