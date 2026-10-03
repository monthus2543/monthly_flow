import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'state/app_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Prompt'], await rootBundle.loadString('assets/fonts/OFL-Prompt.txt'));
  });
  runApp(const MonthlyFlowApp());
}

class MonthlyFlowApp extends StatefulWidget {
  const MonthlyFlowApp({super.key});
  @override
  State<MonthlyFlowApp> createState() => _MonthlyFlowAppState();
}

class _MonthlyFlowAppState extends State<MonthlyFlowApp> {
  final store = AppStore();
  late Future<void> startup;
  bool unlocked = false;

  @override
  void initState() {
    super.initState();
    startup = store.open();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) => MaterialApp(
          title: 'Monthly Flow',
          debugShowCheckedModeBanner: false,
          locale: Locale(store.languageCode),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: appTheme(Brightness.light, store.themeColor),
          darkTheme: appTheme(Brightness.dark, store.themeColor),
          home: FutureBuilder<void>(
            future: startup,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Scaffold(
                    body: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(context.l10n.t('open_failed')),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () => setState(() {
                              startup = store.open();
                            }),
                        child: Text(context.l10n.t('retry'))),
                  ]),
                )));
              }
              if (snapshot.connectionState != ConnectionState.done)
                return const SplashScreen();
              if (store.pinHash.isNotEmpty && !unlocked) {
                return _PinLock(
                    store: store,
                    onUnlocked: () => setState(() => unlocked = true));
              }
              return HomeShell(store: store);
            },
          ),
        ),
      );
}

class _PinLock extends StatefulWidget {
  final AppStore store;
  final VoidCallback onUnlocked;
  const _PinLock({required this.store, required this.onUnlocked});
  @override
  State<_PinLock> createState() => _PinLockState();
}

class _PinLockState extends State<_PinLock> {
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
                Theme.of(context).scaffoldBackgroundColor
              ])),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.lock_outline,
                            size: 54,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 18),
                        Text(context.l10n.t('unlock_app'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 18),
                        Pinput(
                            controller: controller,
                            length: 6,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            defaultPinTheme: _pinTheme(context),
                            focusedPinTheme: _pinTheme(context).copyWith(
                                decoration: _pinTheme(context)
                                    .decoration
                                    ?.copyWith(
                                        border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            width: 2))),
                            errorText: error.isEmpty ? null : error,
                            onCompleted: (_) => _unlock()),
                        const SizedBox(height: 18),
                        FilledButton(
                            onPressed: _unlock,
                            child: Text(context.l10n.t('unlock'))),
                      ]))))));
  void _unlock() {
    if (widget.store.verifyPin(controller.text))
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
    'blue' => const Color(0xFF2563EB),
    'purple' => const Color(0xFF7C3AED),
    'orange' => const Color(0xFFEA580C),
    'rose' => const Color(0xFFE11D48),
    _ => const Color(0xFF008E7B),
  };
  final darkAccent = switch (themeColor) {
    'blue' => const Color(0xFF78A9FF),
    'purple' => const Color(0xFFB99AFF),
    'orange' => const Color(0xFFFFB274),
    'rose' => const Color(0xFFFF8CA5),
    _ => const Color(0xFF62E6CA),
  };
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(
    primary: dark ? darkAccent : accent,
    secondary: dark ? const Color(0xFFFFC985) : const Color(0xFFF49A3F),
    tertiary: dark ? const Color(0xFF8EABFF) : const Color(0xFF4D7CFE),
    error: dark ? const Color(0xFFFF8B80) : const Color(0xFFFF5F52),
    surface: dark ? const Color(0xFF121212) : const Color(0xFFFFFBF7),
  );
  GoogleFonts.config.allowRuntimeFetching = false;
  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Prompt',
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? Colors.black : const Color(0xFFF4FAF8),
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
      backgroundColor: dark ? Colors.black : const Color(0xFFF4FAF8),
      foregroundColor: dark ? const Color(0xFFF5F5F5) : const Color(0xFF123C39),
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Prompt',
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: dark ? const Color(0xFFF5F5F5) : const Color(0xFF123C39),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF0A0A0A) : Colors.white,
      indicatorColor: dark ? const Color(0xFF24312E) : const Color(0xFFCFF8ED),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color:
                states.contains(WidgetState.selected) ? scheme.primary : null,
          )),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.secondary,
      foregroundColor: const Color(0xFF3A2100),
      elevation: 8,
      shape: const CircleBorder(),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: dark ? const Color(0xFF0A0A0A) : Colors.white,
      elevation: 14,
      shadowColor: Colors.black.withValues(alpha: .22),
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? scheme.surface : Colors.white,
      modalBackgroundColor: dark ? scheme.surface : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textStyle:
          const TextStyle(fontFamily: 'Prompt', fontWeight: FontWeight.w500),
    )),
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
    dividerColor: dark ? const Color(0xFF303030) : const Color(0xFFD7EEE8),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF151515) : Colors.white,
      prefixIconColor: scheme.primary,
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: dark ? const Color(0xFF383838) : const Color(0xFFD7EEE8))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: dark ? const Color(0xFF383838) : const Color(0xFFD7EEE8))),
    ),
  );
  const semiBold = TextStyle(fontWeight: FontWeight.w600);
  const regular = TextStyle(fontWeight: FontWeight.w400);
  const medium = TextStyle(fontWeight: FontWeight.w500);
  const bold = TextStyle(fontWeight: FontWeight.w700);
  return baseTheme.copyWith(
    textTheme: GoogleFonts.promptTextTheme(baseTheme.textTheme.merge(
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
    )),
  );
}
