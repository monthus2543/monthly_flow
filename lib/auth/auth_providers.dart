import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'firebase_auth_repository.dart';

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  return FirebaseAuthRepository.connect().timeout(const Duration(seconds: 5));
}, retry: (count, error) => null);

final authSessionProvider = StreamProvider<AuthAccount?>((ref) async* {
  final repository = await ref.watch(authRepositoryProvider.future);
  yield* repository.watchAccount();
}, retry: (count, error) => null);

final authActionProvider =
    NotifierProvider<AuthActions, AsyncValue<void>>(AuthActions.new);

class AuthActions extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> signIn() =>
      _perform((repository) => repository.signInWithGoogle());
  Future<bool> signOut() => _perform((repository) => repository.signOut());

  Future<bool> _perform(Future<void> Function(AuthRepository) action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      if (!ref.mounted) return false;
      await action(repository);
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } on AuthCancelled {
      if (ref.mounted) state = const AsyncData(null);
      return false;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      return false;
    }
  }
}
