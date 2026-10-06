import 'dart:async';
import 'package:monthly_flow/auth/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AuthAccount? account;
  final changes = StreamController<AuthAccount?>.broadcast();
  int signIns = 0;
  int signOuts = 0;
  int profileUpdates = 0;
  Object? failure;
  String? linkedDefaultName;
  Completer<void>? pending;
  FakeAuthRepository({this.account});
  @override
  Stream<AuthAccount?> watchAccount() async* {
    yield account;
    yield* changes.stream;
  }

  @override
  Future<void> signInWithGoogle({String? defaultName}) async {
    signIns++;
    await pending?.future;
    if (failure != null) throw failure!;
    linkedDefaultName = defaultName;
    account = AuthAccount(
        id: 'verified-firebase-uid',
        name: defaultName ?? 'Monthly User',
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

  @override
  Future<void> updateProfile({required String name, String? photoUrl}) async {
    profileUpdates++;
    await pending?.future;
    if (failure != null) throw failure!;
    final current = account!;
    account = AuthAccount(id: current.id, name: name, email: current.email,
        photoUrl: photoUrl);
    changes.add(account);
  }
}
