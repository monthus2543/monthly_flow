import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../receipts/receipt_cloud.dart';
import '../l10n/app_localizations.dart';

class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({super.key, required this.path});
  final String path;
  Widget _image(BuildContext context) => isCloudReceipt(path)
      ? Consumer(
          builder: (context, ref, _) => ref
              .watch(receiptImageProvider(path))
              .when(
                data: (bytes) => Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) => Center(
                    child: Text(context.l10n.t('receipt_unavailable')),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, stack) =>
                    Center(child: Text(context.l10n.t('receipt_unavailable'))),
              ),
        )
      : Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.t('receipt_unavailable'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      button: true,
      label: context.l10n.t('view_receipt'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              appBar: AppBar(title: Text(context.l10n.t('view_receipt'))),
              body: Center(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 5,
                  child: _image(context),
                ),
              ),
            ),
          ),
        ),
        child: Container(
          height: 160,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: _image(context),
        ),
      ),
    ),
  );
}
