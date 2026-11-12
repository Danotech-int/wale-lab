import '../models/profile.dart';
import '../models/user.dart';

/// Identity and onboarding operations independent of the demo HTTP backend.
abstract interface class AuthBackend {
  Stream<void> get signedOut;
  bool get emailVerified;
  Future<AppUser?> restoreSession();
  Future<AppUser> login(String email, String password);
  Future<AppUser> signup(String name, String email, String password);
  Future<AppUser> createProfile(Profile profile);
  Future<AppUser> refreshUser();
  Future<void> sendEmailVerification();
  Future<void> resetPassword(String email);
  Future<void> logout();
}
