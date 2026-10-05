import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth/auth_providers.dart';
import '../auth/auth_repository.dart';
import '../l10n/app_localizations.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;
  String? _errorKey;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start({required bool google}) async {
    if (_saving || ref.read(authActionProvider).isLoading) return;
    if (!google && !_formKey.currentState!.validate()) return;
    final store = ref.read(appStoreProvider.notifier);
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _errorKey = null;
    });
    try {
      if (google) {
        // Allow retry after transient initialization failures.
        if (ref.read(authRepositoryProvider).hasError) {
          ref.invalidate(authRepositoryProvider);
        }
        final success = await ref.read(authActionProvider.notifier).signIn();
        if (!success) return;
      }
      await store.completeOnboarding(localName: google ? null : _name.text);
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'welcome_save_failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = ref.watch(authActionProvider);
    final busy = _saving || action.isLoading;
    final errorKey =
        _errorKey ?? (action.hasError ? authErrorKey(action.error!) : null);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: SizedBox.expand(
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.l10n.t('welcome_title'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 27,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.t('welcome_subtitle'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 64),
                        Icon(
                          LucideIcons.wallet,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.t('welcome_tagline'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onPressed: busy ? null : () => _start(google: true),
                          child: Text(
                            context.l10n.t('welcome_google'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (busy) ...[
                          const SizedBox(height: 16),
                          const Center(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ],
                        if (errorKey != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              context.l10n.t(errorKey),
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.t('welcome_or_name'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _name,
                          enabled: !busy,
                          maxLength: 50,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: context.l10n.t('welcome_name'),
                            hintText: context.l10n.t('welcome_name_hint'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? context.l10n.t('welcome_name_required')
                              : null,
                          onFieldSubmitted: (_) => _start(google: false),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onPressed: busy ? null : () => _start(google: false),
                          child: Text(context.l10n.t('welcome_start')),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.t('welcome_local_note'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
