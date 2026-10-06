import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_repository.dart';

/// Firebase owns session persistence. OAuth tokens never enter the local finance database.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  FirebaseAuthRepository._(this._auth);
  static Future<void>? _googleInitialization;

  static Future<void> initializeGoogle() =>
      _googleInitialization ??= GoogleSignIn.instance.initialize();

  static Future<AuthRepository> connect() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const AuthFailure(AuthFailureReason.unavailable);
    }
    try {
      // Uses google-services.json on Android / GoogleService-Info.plist on iOS.
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return FirebaseAuthRepository._(FirebaseAuth.instance);
    } on FirebaseException {
      throw const AuthFailure(AuthFailureReason.configuration);
    } on PlatformException {
      throw const AuthFailure(AuthFailureReason.configuration);
    }
  }

  @override
  Stream<AuthAccount?> watchAccount() =>
      _auth.userChanges().map((user) => user == null
          ? null
          : AuthAccount(
              id: user.uid, name: user.displayName, email: user.email,
              photoUrl: user.photoURL));

  @override
  Future<void> updateProfile({required String name, String? photoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(AuthFailureReason.unavailable);
    final trimmedName = name.trim();
    final trimmedPhoto = photoUrl?.trim();
    final uri = Uri.tryParse(trimmedPhoto ?? '');
    if (trimmedName.isEmpty || trimmedName.length > 80 ||
        (trimmedPhoto != null && trimmedPhoto.isNotEmpty &&
            (uri == null || uri.scheme != 'https' || uri.host.isEmpty))) {
      throw const AuthFailure(AuthFailureReason.failed);
    }
    try {
      await user.updateProfile(displayName: trimmedName,
          photoURL: trimmedPhoto == null || trimmedPhoto.isEmpty ? null : trimmedPhoto);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code == 'network-request-failed'
          ? AuthFailureReason.network : AuthFailureReason.failed);
    } on PlatformException {
      throw const AuthFailure(AuthFailureReason.failed);
    }
  }

  @override
  Future<void> signInWithGoogle({String? defaultName}) async {
    try {
      final google = GoogleSignIn.instance;
      await initializeGoogle();
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(AuthFailureReason.failed);
      }
      // Firebase verifies the Google ID token; profile information alone is not authentication.
      final credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken));
      if (defaultName != null && defaultName.trim().isNotEmpty) {
        try {
          await credential.user!.updateDisplayName(defaultName.trim());
        } catch (_) {
          // Keep the local profile available for retry if linking fails.
          await _auth.signOut();
          rethrow;
        }
      }
    } on GoogleSignInException catch (error) {
      if (kDebugMode) {
        debugPrint('Google sign-in failed: ${error.code.name}');
        if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
            error.code == GoogleSignInExceptionCode.providerConfigurationError) {
          // Configuration diagnostics only; never log credentials or SDK details.
          debugPrint('Google sign-in configuration: ${error.description}');
        }
      }
      if (error.code == GoogleSignInExceptionCode.canceled)
        throw const AuthCancelled();
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const AuthFailure(AuthFailureReason.configuration);
      }
      throw const AuthFailure(AuthFailureReason.failed);
    } on FirebaseAuthException catch (error) {
      if (kDebugMode) debugPrint('Firebase sign-in failed: ${error.code}');
      throw AuthFailure(switch (error.code) {
        'network-request-failed' => AuthFailureReason.network,
        'user-disabled' => AuthFailureReason.disabled,
        'operation-not-allowed' ||
        'invalid-api-key' =>
          AuthFailureReason.configuration,
        _ => AuthFailureReason.failed,
      });
    } on PlatformException {
      throw const AuthFailure(AuthFailureReason.failed);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      final google = GoogleSignIn.instance;
      await initializeGoogle();
      await google.signOut();
    } on GoogleSignInException {
      // The Firebase session has already ended; provider cleanup is best effort.
    } on PlatformException {
      // A provider cleanup failure must not resurrect a signed-out Firebase session.
    }
  }
}
