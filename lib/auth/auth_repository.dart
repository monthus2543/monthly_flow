class AuthAccount {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;
  const AuthAccount({required this.id, this.name, this.email, this.photoUrl});
}

enum AuthFailureReason { unavailable, network, disabled, configuration, failed }

class AuthFailure implements Exception {
  final AuthFailureReason reason;
  const AuthFailure(this.reason);
}

class AuthCancelled implements Exception {
  const AuthCancelled();
}

String authErrorKey(Object error) => switch (error) {
      AuthFailure(reason: AuthFailureReason.network) => 'auth_network_error',
      AuthFailure(reason: AuthFailureReason.disabled) => 'auth_disabled',
      AuthFailure(
        reason: AuthFailureReason.configuration || AuthFailureReason.unavailable
      ) =>
        'auth_unavailable',
      _ => 'auth_failed',
    };

abstract interface class AuthRepository {
  Stream<AuthAccount?> watchAccount();
  Future<void> signInWithGoogle({String? defaultName});
  Future<void> signOut();
  Future<void> updateProfile({required String name, String? photoUrl});
}
