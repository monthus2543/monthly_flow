import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/auth_repository.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/account_avatar.dart';
import '../widgets/sync_status_card.dart';
import 'edit_profile_screen.dart';
import '../state/app_store.dart';

class AccountScreen extends ConsumerWidget {
  final bool embedded;
  final bool showSync;
  const AccountScreen({super.key, this.embedded = false, this.showSync = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final action = ref.watch(authActionProvider);
    final account = session.asData?.value;
    final localName = ref.watch(
      appStoreProvider.select((state) => state.localName),
    );
    final localProfile = account == null && localName.isNotEmpty;
    final busy = action.isLoading || session.isLoading;
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      children: [
        Semantics(
          button: account != null,
          label: context.l10n.t('profile_choose_photo'),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy || account == null
                ? null
                : () => _editProfile(
                    context,
                    account,
                    localName,
                    choosePhoto: true,
                  ),
            child: AccountAvatar(photoUrl: account?.photoUrl),
          ),
        ),
        const SizedBox(height: 16),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                account == null
                    ? (localProfile
                          ? localName
                          : context.l10n.t('google_login_title'))
                    : account.name ?? context.l10n.t('google_account'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                account?.email ??
                    context.l10n.t(
                      localProfile
                          ? 'offline_profile'
                          : 'google_login_description',
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (account != null || localProfile) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.l10n.t('edit_profile')),
                  onPressed: busy
                      ? null
                      : () => _editProfile(context, account, localName),
                ),
                if (busy ||
                    session.hasError ||
                    action.hasError ||
                    account == null)
                  const SizedBox(height: 16),
              ],
              if (busy && account != null) ...[
                const Center(
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.t('auth_working'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              if (session.hasError || action.hasError) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    context.l10n.t(
                      session.hasError
                          ? 'auth_unavailable'
                          : authErrorKey(action.error!),
                    ),
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
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
                  child: Text(context.l10n.t('retry')),
                )
              else if (account == null)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          String? defaultName;
                          try {
                            defaultName = await ref
                                .read(appStoreProvider.notifier)
                                .localProfileNameForLink();
                          } catch (_) {
                            if (context.mounted)
                              showAppAlert(
                                context,
                                context.l10n.t('save_failed'),
                                isError: true,
                              );
                            return;
                          }
                          if (!context.mounted) return;
                          final success = await ref
                              .read(authActionProvider.notifier)
                              .signIn(defaultName: defaultName);
                          if (success && defaultName != null) {
                            try {
                              await ref
                                  .read(appStoreProvider.notifier)
                                  .completeLocalProfileLink();
                            } catch (_) {
                              if (context.mounted)
                                showAppAlert(
                                  context,
                                  context.l10n.t('save_failed'),
                                  isError: true,
                                );
                              return;
                            }
                          }
                          if (success && context.mounted) {
                            showAppAlert(
                              context,
                              context.l10n.t('google_login_success'),
                            );
                          }
                        },
                  child: busy
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          context.l10n.t(
                            localProfile ? 'connect_google' : 'continue_google',
                          ),
                        ),
                ),
              if (account == null || showSync) const SizedBox(height: 16),
              if (account != null && showSync) const SyncStatusCard(),
              if (account == null)
                Text(
                  context.l10n.t('account_local_data_note'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              if (account == null && !embedded) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: Text(context.l10n.t('continue_offline')),
                ),
              ],
            ],
          ),
        ),
        if (!embedded && account != null) ...[
          const SizedBox(height: 16),
          const AccountSignOutButton(),
        ],
      ],
    );
    if (embedded) return content;
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
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    AuthAccount? account,
    String localName, {
    bool choosePhoto = false,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          account: account,
          localName: localName,
          choosePhotoOnOpen: choosePhoto,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      showAppAlert(context, context.l10n.t('profile_saved'));
    }
  }
}

class AccountSignOutButton extends ConsumerWidget {
  const AccountSignOutButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(authActionProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;
    final background = scheme.error;
    return AppPrimaryButton(
      color: background,
      foregroundColor: scheme.onError,
      onPressed: busy ? null : () => _signOut(context, ref),
      child: Text(context.l10n.t('sign_out')),
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
            child: Text(context.l10n.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.t('sign_out')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await ref.read(authActionProvider.notifier).signOut();
    if (success && context.mounted)
      showAppAlert(context, context.l10n.t('signed_out'));
  }
}
