import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/auth_repository.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';
import '../widgets/account_avatar.dart';
import '../widgets/sync_status_card.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final action = ref.watch(authActionProvider);
    final account = session.asData?.value;
    final busy = action.isLoading || session.isLoading;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('auth_account'))),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: SizedBox.expand(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Surface(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: AccountAvatar(photoUrl: account?.photoUrl)),
                const SizedBox(height: 16),
                Text(
                    account == null
                        ? context.l10n.t('google_login_title')
                        : account.name ?? context.l10n.t('google_account'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                    account?.email ??
                        context.l10n.t('google_login_description'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (busy) ...[
                  const Center(
                      child: SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  const SizedBox(height: 12),
                  Text(context.l10n.t('auth_working'),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                ],
                if (session.hasError || action.hasError) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(
                        context.l10n.t(session.hasError
                            ? 'auth_unavailable'
                            : authErrorKey(action.error!)),
                        style: TextStyle(color: scheme.onErrorContainer)),
                  ),
                  const SizedBox(height: 16),
                ],
                if (session.hasError)
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () {
                              ref.invalidate(authRepositoryProvider);
                              ref.invalidate(authSessionProvider);
                            },
                      child: Text(context.l10n.t('retry')))
                else if (account == null)
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final success = await ref
                                  .read(authActionProvider.notifier)
                                  .signIn();
                              if (success && context.mounted) {
                                showAppAlert(context,
                                    context.l10n.t('google_login_success'));
                              }
                            },
                      child: Text(context.l10n.t('continue_google')))
                else
                  OutlinedButton(
                      onPressed: busy ? null : () => _signOut(context, ref),
                      child: Text(context.l10n.t('sign_out'))),
                const SizedBox(height: 20),
                if (account != null) const SyncStatusCard(),
                if (account == null) Text(context.l10n.t('account_local_data_note'),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
                if (account == null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed:
                          busy ? null : () => Navigator.of(context).maybePop(),
                      child: Text(context.l10n.t('continue_offline'))),
                ],
              ],
            )),
          )),
        )),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(context.l10n.t('sign_out')),
              content: Text(context.l10n.t('sign_out_confirm')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.t('cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.l10n.t('sign_out'))),
              ],
            ));
    if (confirmed != true || !context.mounted) return;
    final success = await ref.read(authActionProvider.notifier).signOut();
    if (success && context.mounted)
      showAppAlert(context, context.l10n.t('signed_out'));
  }
}
