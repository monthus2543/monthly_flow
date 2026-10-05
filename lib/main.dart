import 'color/color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_store.dart';
import 'sync/sync_providers.dart';
import 'auth/auth_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Prompt',
    ], await rootBundle.loadString('assets/fonts/OFL-Prompt.txt'));
  });
  runApp(const ProviderScope(child: MonthlyFlowApp()));
}

class MonthlyFlowApp extends ConsumerStatefulWidget {
  const MonthlyFlowApp({super.key});
  @override
  ConsumerState<MonthlyFlowApp> createState() => _MonthlyFlowAppState();
}

class _MonthlyFlowAppState extends ConsumerState<MonthlyFlowApp> with WidgetsBindingObserver {
  bool unlocked = false;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(syncCoordinatorProvider.notifier).request();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      appStoreProvider.select(
        (state) => (
          state.languageCode,
          state.darkMode,
          state.themeColor,
          state.pinHash,
          state.onboardingCompleted,
        ),
      ),
    );
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.asData?.value?.id != next.asData?.value?.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      }
    });
    final startup = ref.watch(appStartupProvider);
    ref.watch(syncCoordinatorProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Monthly Flow',
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.$1),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: settings.$2 ? ThemeMode.dark : ThemeMode.light,
      theme: appTheme(Brightness.light, settings.$3),
      darkTheme: appTheme(Brightness.dark, settings.$3),
      home: startup.when(
        loading: () => const SplashScreen(),
        error: (error, stack) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Builder(
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.t('open_failed')),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(appStartupProvider),
                      child: Text(context.l10n.t('retry')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        data: (_) => settings.$4.isNotEmpty && !unlocked
            ? _PinLock(onUnlocked: () => setState(() => unlocked = true))
            : settings.$5
                ? const HomeShell()
                : const OnboardingScreen(),
      ),
    );
  }
}

class _PinLock extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  const _PinLock({required this.onUnlocked});
  @override
  ConsumerState<_PinLock> createState() => _PinLockState();
}

class _PinLockState extends ConsumerState<_PinLock> {
  final controller = TextEditingController();
  String error = '';
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 54,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.t('unlock_app'),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 18),
                    Pinput(
                      controller: controller,
                      length: 6,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      defaultPinTheme: _pinTheme(context),
                      focusedPinTheme: _pinTheme(context).copyWith(
                        decoration: _pinTheme(context).decoration?.copyWith(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                      ),
                      errorText: error.isEmpty ? null : error,
                      onCompleted: (_) => _unlock(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _unlock,
                      child: Text(context.l10n.t('unlock')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  void _unlock() {
    if (ref.read(appStoreProvider.notifier).verifyPin(controller.text))
      widget.onUnlocked();
    else
      setState(() => error = context.l10n.t('wrong_pin'));
  }

  PinTheme _pinTheme(BuildContext context) => PinTheme(
        width: 46,
        height: 54,
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
      );
}

ThemeData appTheme(Brightness brightness, [String themeColor = 'teal']) {
  final dark = brightness == Brightness.dark;
  final accent = switch (themeColor) {
    'blue' => AppColors.blue,
    'purple' => AppColors.purple,
    'orange' => AppColors.orange,
    'rose' => AppColors.rose,
    _ => AppColors.teal,
  };
  final darkAccent = switch (themeColor) {
    'blue' => AppColors.blueDark,
    'purple' => AppColors.purpleDark,
    'orange' => AppColors.orangeDark,
    'rose' => AppColors.roseDark,
    _ => AppColors.tealDark,
  };
  final scheme =
      ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
    primary: dark ? darkAccent : accent,
    secondary: dark ? AppColors.secondaryDark : AppColors.secondary,
    tertiary: dark ? AppColors.accentBlueDark : AppColors.accentBlue,
    error: dark ? AppColors.errorDark : AppColors.error,
    surface: dark ? AppColors.surfaceDark : AppColors.surface,
  );
  GoogleFonts.config.allowRuntimeFetching = false;
  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Prompt',
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? Colors.black : AppColors.scaffold,
    cardColor: scheme.surface,
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: scheme.primary.withValues(alpha: .09),
      barrierColor: Colors.black.withValues(alpha: dark ? .32 : .18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.primary.withValues(alpha: .08)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? Colors.black : AppColors.scaffold,
      foregroundColor: dark ? AppColors.textDark : AppColors.text,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Prompt',
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: dark ? AppColors.textDark : AppColors.text,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? AppColors.navigationDark : Colors.white,
      indicatorColor: dark
          ? AppColors.navigationIndicatorDark
          : AppColors.navigationIndicator,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.secondary,
      foregroundColor: AppColors.onSecondary,
      elevation: 8,
      shape: const CircleBorder(),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: dark ? AppColors.navigationDark : Colors.white,
      elevation: 14,
      shadowColor: Colors.black.withValues(alpha: .22),
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      modalBarrierColor: Colors.black.withValues(alpha: .42),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      dragHandleSize: const Size(42, 4),
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: .35),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(
          fontFamily: 'Prompt',
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        side: BorderSide(color: scheme.primary.withValues(alpha: .35)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 6,
      iconColor: dark ? darkAccent : accent,
    ),
    chipTheme: ChipThemeData(
      selectedColor: scheme.primary,
      secondarySelectedColor: scheme.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: dark ? AppColors.dividerDark : AppColors.divider,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.inputDark : Colors.white,
      prefixIconColor: scheme.primary,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: dark ? AppColors.inputBorderDark : AppColors.divider,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: dark ? AppColors.inputBorderDark : AppColors.divider,
        ),
      ),
    ),
  );
  const semiBold = TextStyle(fontWeight: FontWeight.w600);
  const regular = TextStyle(fontWeight: FontWeight.w400);
  const medium = TextStyle(fontWeight: FontWeight.w500);
  const bold = TextStyle(fontWeight: FontWeight.w700);
  return baseTheme.copyWith(
    textTheme: GoogleFonts.promptTextTheme(
      baseTheme.textTheme.merge(
        const TextTheme(
          displayLarge: bold,
          displayMedium: bold,
          displaySmall: bold,
          headlineLarge: semiBold,
          headlineMedium: semiBold,
          headlineSmall: semiBold,
          titleLarge: semiBold,
          titleMedium: semiBold,
          titleSmall: semiBold,
          bodyLarge: regular,
          bodyMedium: regular,
          bodySmall: regular,
          labelLarge: medium,
          labelMedium: medium,
          labelSmall: medium,
        ),
      ),
    ),
  );
}
