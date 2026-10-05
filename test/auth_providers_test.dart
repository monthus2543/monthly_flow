import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/auth/auth_repository.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;
  setUp(() {
    repository = FakeAuthRepository();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWith((ref) async => repository),
    ]);
    container.listen(authSessionProvider, (previous, next) {},
        fireImmediately: true);
  });
  tearDown(() async {
    container.dispose();
    await repository.dispose();
  });
  test('restored session, login and logout follow the repository stream',
      () async {
    repository.account =
        const AuthAccount(id: 'restored', email: 'saved@example.com');
    expect((await container.read(authSessionProvider.future))?.id, 'restored');
    final actions = container.read(authActionProvider.notifier);
    expect(await actions.signOut(), isTrue);
    await pumpEventQueue();
    expect(container.read(authSessionProvider).asData?.value, isNull);
    expect(await actions.signIn(), isTrue);
    await pumpEventQueue();
    expect(container.read(authSessionProvider).asData?.value?.id,
        'verified-firebase-uid');
  });
  test('cancel is silent, a failure is visible and retry succeeds', () async {
    final actions = container.read(authActionProvider.notifier);
    repository.failure = const AuthCancelled();
    expect(await actions.signIn(), isFalse);
    expect(container.read(authActionProvider).hasError, isFalse);
    repository.failure = const AuthFailure(AuthFailureReason.network);
    expect(await actions.signIn(), isFalse);
    expect(authErrorKey(container.read(authActionProvider).error!),
        'auth_network_error');
    expect(repository.account, isNull);
    repository.failure = null;
    expect(await actions.signIn(), isTrue);
    expect(container.read(authActionProvider).hasError, isFalse);
  });
  test('duplicate taps do not launch two login prompts', () async {
    repository.pending = Completer<void>();
    final actions = container.read(authActionProvider.notifier);
    final first = actions.signIn();
    await pumpEventQueue();
    expect(container.read(authActionProvider).isLoading, isTrue);
    expect(await actions.signIn(), isFalse);
    expect(repository.signIns, 1);
    repository.pending!.complete();
    expect(await first, isTrue);
  });
  test('failed logout keeps the authenticated account visible', () async {
    repository.account = const AuthAccount(id: 'restored');
    await container.read(authSessionProvider.future);
    repository.failure = const AuthFailure(AuthFailureReason.network);
    expect(
        await container.read(authActionProvider.notifier).signOut(), isFalse);
    expect(container.read(authSessionProvider).asData?.value?.id, 'restored');
  });
  test('repository setup failure is handled without blocking local app state',
      () async {
    final unavailable = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWith((ref) async =>
          throw const AuthFailure(AuthFailureReason.configuration)),
    ]);
    expect(
        await unavailable.read(authActionProvider.notifier).signIn(), isFalse);
    expect(unavailable.read(authActionProvider).hasError, isTrue);
    unavailable.dispose();
  });
}
