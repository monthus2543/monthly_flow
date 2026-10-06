import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_repository.dart';
import '../l10n/app_localizations.dart';
import '../widgets/account_avatar.dart';
import '../widgets/common_widgets.dart';
import '../widgets/app_primary_button.dart';
import '../state/app_store.dart';
import '../auth/profile_photo_storage.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final AuthAccount? account;
  final String localName;
  final bool choosePhotoOnOpen;
  const EditProfileScreen({
    super.key,
    this.account,
    this.localName = '',
    this.choosePhotoOnOpen = false,
  });
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  String? errorKey;
  bool saving = false;
  bool picking = false;
  ProfilePhoto? selectedPhoto;
  double? uploadProgress;

  Future<void> pickPhoto() async {
    if (saving || picking) return;
    setState(() {
      picking = true;
      errorKey = null;
    });
    try {
      final picked = await ref.read(profilePhotoPickerProvider)();
      if (mounted && picked != null) setState(() => selectedPhoto = picked);
    } catch (error) {
      if (mounted)
        setState(
          () => errorKey = error is ProfilePhotoFailure
              ? error.messageKey
              : 'profile_photo_pick_failed',
        );
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.account?.name ?? widget.localName,
    );
    if (widget.choosePhotoOnOpen && widget.account != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) pickPhoto();
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      errorKey = null;
    });
    if (widget.account == null) {
      try {
        await ref
            .read(appStoreProvider.notifier)
            .completeOnboarding(localName: name.text.trim());
        if (mounted) Navigator.pop(context, true);
      } catch (_) {
        if (mounted)
          setState(() {
            saving = false;
            errorKey = 'save_failed';
          });
      }
      return;
    }
    final current = ref.read(authSessionProvider).asData?.value;
    if (current?.id != widget.account!.id) {
      setState(() {
        saving = false;
        errorKey = 'auth_unavailable';
      });
      return;
    }
    UploadedProfilePhoto? uploaded;
    ProfilePhotoStorage? storage;
    String? photoUrl = widget.account?.photoUrl;
    try {
      if (selectedPhoto != null) {
        storage = ref.read(profilePhotoStorageProvider);
        setState(() => uploadProgress = 0);
        uploaded = await storage!.upload(
          widget.account!.id,
          selectedPhoto!,
          onProgress: (value) {
            if (mounted) setState(() => uploadProgress = value);
          },
        );
        photoUrl = uploaded.url;
      }
    } catch (error) {
      if (mounted)
        setState(() {
          saving = false;
          uploadProgress = null;
          errorKey = error is ProfilePhotoFailure
              ? error.messageKey
              : 'profile_photo_upload_failed';
        });
      return;
    }
    if (!mounted) return;
    setState(() => uploadProgress = null);
    if (ref.read(authSessionProvider).asData?.value?.id != widget.account!.id) {
      if (uploaded != null) {
        try {
          await storage!
              .remove(widget.account!.id, uploaded)
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
      if (mounted)
        setState(() {
          saving = false;
          errorKey = 'auth_unavailable';
        });
      return;
    }
    final success = await ref
        .read(authActionProvider.notifier)
        .updateProfile(name: name.text.trim(), photoUrl: photoUrl);
    if (!success && uploaded != null) {
      try {
        await storage!
            .remove(widget.account!.id, uploaded)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        /* A failed cleanup must not hide the profile error. */
      }
    }
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        saving = false;
        errorKey = authErrorKey(
          ref.read(authActionProvider).error ??
              const AuthFailure(AuthFailureReason.failed),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = saving || picking || ref.watch(authActionProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.t('edit_profile'))),
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
          child: SizedBox.expand(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Semantics(
                          button: widget.account != null,
                          label: context.l10n.t('profile_choose_photo'),
                          child: InkWell(
                            key: const ValueKey('edit-profile-photo'),
                            customBorder: const CircleBorder(),
                            onTap: busy || widget.account == null
                                ? null
                                : pickPhoto,
                            child: Stack(
                              children: [
                                selectedPhoto != null
                                    ? ClipOval(
                                        child: Image.memory(
                                          selectedPhoto!.bytes,
                                          width: 88,
                                          height: 88,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, error, stack) =>
                                              const Icon(
                                                Icons.broken_image_outlined,
                                                size: 88,
                                              ),
                                        ),
                                      )
                                    : AccountAvatar(
                                        photoUrl: widget.account?.photoUrl,
                                        size: 88,
                                      ),
                                if (widget.account != null)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: scheme.primaryContainer,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: scheme.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.edit_rounded,
                                        size: 16,
                                        color: scheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (widget.account != null && selectedPhoto != null) ...[
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => selectedPhoto = null),
                          child: Text(context.l10n.t('profile_cancel_photo')),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Surface(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: name,
                              enabled: !busy,
                              maxLength: widget.account == null ? 50 : 80,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: context.l10n.t('profile_name'),
                              ),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? context.l10n.t('profile_name_required')
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            if (widget.account?.email != null)
                              Text(
                                widget.account!.email!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.t(
                                widget.account == null
                                    ? 'account_local_data_note'
                                    : 'profile_google_note',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (errorKey != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.t(errorKey!),
                          style: TextStyle(color: scheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (uploadProgress != null) ...[
                        LinearProgressIndicator(value: uploadProgress),
                        const SizedBox(height: 8),
                        Text(
                          '${context.l10n.t('profile_uploading')} ${(uploadProgress! * 100).round()}%',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                      AppPrimaryButton(
                        onPressed: busy ? null : save,
                        child: busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.l10n.t('save_profile')),
                      ),
                    ],
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
