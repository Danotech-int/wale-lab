import 'package:firebase_core/firebase_core.dart';

import '../services/api_service.dart';

String authErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'email-already-in-use' =>
        'An account already uses this email. Please sign in or reset your password.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' =>
        'Choose a stronger password with at least 8 characters.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'The email or password is incorrect.',
      'user-disabled' =>
        'This account has been disabled. Contact your administrator.',
      'too-many-requests' =>
        'Too many attempts. Please wait before trying again.',
      'network-request-failed' ||
      'unavailable' =>
        'Unable to connect. Check your internet connection and try again.',
      'operation-not-allowed' =>
        'Email/password sign-in is not enabled in Firebase. Contact your administrator.',
      'permission-denied' =>
        'Your account could not access its profile. Contact your administrator to check database permissions.',
      _ => 'Unable to complete this request. Please try again.',
    };
  }
  return 'Unable to complete this request. Check your connection and try again.';
}
