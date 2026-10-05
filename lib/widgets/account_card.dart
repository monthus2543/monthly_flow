import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../l10n/app_localizations.dart';
import '../state/app_store.dart';
import '../screens/account_screen.dart';
import 'common_widgets.dart';
import 'account_avatar.dart';

class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final account = session.asData?.value;
    void openAccount() => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));
    if (account != null) {
      final theme = Theme.of(context);
      return Column(
        children: [
          AccountAvatar(photoUrl: account.photoUrl),
          const SizedBox(height: 16),
          Surface(
            child: InkWell(
              onTap: openAccount,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text(
                        account.name ?? context.l10n.t('google_account'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (account.email != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          account.email!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final localName = ref.watch(
      appStoreProvider.select((state) => state.localName),
    );
    return Surface(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.account_circle_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 36,
        ),
        title: Text(
          localName.isEmpty ? context.l10n.t('auth_account') : localName,
        ),
        subtitle: Text(account?.email ?? context.l10n.t('google_login_title')),
        trailing: const Icon(Icons.chevron_right),
        onTap: openAccount,
      ),
    );
  }
}
