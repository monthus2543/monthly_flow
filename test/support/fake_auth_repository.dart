import 'dart:async';
import 'package:monthly_flow/auth/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AuthAccount? account;
  final changes = StreamController<AuthAccount?>.broadcast();
  int signIns = 0;
  int signOuts = 0;
  Object? failure;
  Completer<void>? pending;
  FakeAuthRepository({this.account});
  @override
  Stream<AuthAccount?> watchAccount() async* {
    yield account;
    yield* changes.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    signIns++;
    await pending?.future;
    if (failure != null) throw failure!;
    account = const AuthAccount(
        id: 'verified-firebase-uid',
        name: 'Monthly User',
        email: 'user@example.com');
    changes.add(account);
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    if (failure != null) throw failure!;
    account = null;
    changes.add(null);
  }

  Future<void> dispose() => changes.close();
}
