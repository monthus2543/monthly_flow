import '../color/color.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../l10n/app_localizations.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [
                    AppColors.black,
                    AppColors.backgroundDarkMiddle,
                    AppColors.black
                  ]
                : const [
                    AppColors.splashStart,
                    AppColors.splashMiddle,
                    AppColors.splashEnd
                  ],
          ),
        ),
        child: Stack(children: [
          Positioned(
              top: -85,
              right: -65,
              child: _GlowCircle(
                  size: 230,
                  color:
                      (dark ? AppColors.accentBlue : AppColors.splashBlueGlow)
                          .withValues(alpha: .22))),
          Positioned(
              bottom: -110,
              left: -80,
              child: _GlowCircle(
                  size: 270,
                  color: (dark ? scheme.primary : AppColors.splashTealGlow)
                      .withValues(alpha: .18))),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: Column(children: [
                        const Spacer(),
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.splashLogoStart,
                                AppColors.splashLogoEnd
                              ],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .8),
                                width: 3),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.splashLogoShadow
                                      .withValues(alpha: .28),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14))
                            ],
                          ),
                          child: const Icon(LucideIcons.walletCards,
                              color: Colors.white, size: 52),
                        ),
                        const SizedBox(height: 28),
                        Text(context.l10n.t('app_name'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.7,
                                color: dark
                                    ? AppColors.splashTitleDark
                                    : AppColors.splashTitle)),
                        const SizedBox(height: 8),
                        Text(context.l10n.t('tagline'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: dark
                                    ? AppColors.splashSubtitleDark
                                    : AppColors.splashSubtitle)),
                        const SizedBox(height: 34),
                        const _DashboardSkeleton(),
                        const SizedBox(height: 18),
                        Text(context.l10n.t('loading'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: dark
                                    ? AppColors.splashCaptionDark
                                    : AppColors.splashCaption,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => Skeletonizer(
        enabled: true,
        ignorePointers: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ภาพรวมประจำเดือน',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ยอดคงเหลือทั้งหมด'),
                  SizedBox(height: 8),
                  Text('฿00,000.00',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _skeletonCard(context)),
                const SizedBox(width: 12),
                Expanded(child: _skeletonCard(context)),
              ],
            ),
          ],
        ),
      );

  Widget _skeletonCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('รายรับประจำเดือน'), SizedBox(height: 6), Text('฿0')],
        ),
      );
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      );
}
