import 'package:flutter/material.dart';

class AccountAvatar extends StatelessWidget {
  final String? photoUrl;
  final double size;
  const AccountAvatar({super.key, this.photoUrl, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Icon(
      Icons.account_circle_outlined,
      size: size * .65,
      color: scheme.onPrimaryContainer,
    );
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: photoUrl == null || photoUrl!.trim().isEmpty
              ? fallback
              : Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, error, stackTrace) => fallback,
                ),
        ),
      ),
    );
  }
}
