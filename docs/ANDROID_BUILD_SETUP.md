# Android build configuration

Monthly Flow uses Flutter 3.47 or later, Android Gradle Plugin 9.1.0, Gradle 9.3.1, and built-in Kotlin. The application version remains in `pubspec.yaml`; changing build tooling does not create a release.

## Kotlin

- `android.builtInKotlin=true` enables Kotlin through AGP instead of applying `org.jetbrains.kotlin.android` to the app.
- The Kotlin compiler remains pinned to 2.4.0 with `apply false` in `android/settings.gradle`. Without that declaration, this AGP setup resolves Kotlin 2.2.10, below Flutter's required 2.2.20. The declaration makes the compiler available without applying the legacy plugin to a module.
- JVM target remains Java 17, configured through `kotlin.compilerOptions`.
- `android.newDsl=false` remains for the current Flutter/plugin compatibility layer. Migration to the new Android DSL is a separate change.
- `file_picker` 13.1.0 and `share_plus` 13.3.1 support built-in Kotlin. JSON backup selection uses the new `FilePicker.pickFile()` API.

## Java native access

`--enable-native-access=ALL-UNNAMED` is supplied to both the Gradle launcher scripts and daemon. This permits Gradle's native library loader on newer JDKs and removes the restricted `System.load` warning. The launcher scripts are kept in the repository so the configuration is reproducible; the generated wrapper JAR remains ignored and Flutter supplies it when needed.

## Verification and remaining warnings

- Android Debug APK compiles successfully with these settings.
- Source analysis and all 29 tests pass.
- A temporary Gradle init script checked the actual applied plugins after evaluation: `app`, `firebase_core`, `firebase_auth`, `share_plus`, and `android_file_picker` all reported `builtIn=true` and `legacyApplied=false`.
- Flutter 3.47.5 still warns about legacy KGP in `firebase_core` and `firebase_auth`. Its `FlutterPluginUtils.kt` checker scans build-file declarations and sees the conditional `apply plugin: 'kotlin-android'` retained for older AGP versions. That branch is not executed in this build. Do not patch the global Flutter SDK or Pub cache merely to remove this warning.
- Existing SDK XML compatibility/deprecation warnings may still appear and are separate from Java native access and Kotlin migration.

References: [Flutter built-in Kotlin migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers), [Android built-in Kotlin migration](https://developer.android.com/build/migrate-to-built-in-kotlin), [file_picker changelog](https://pub.dev/packages/file_picker/changelog), [share_plus changelog](https://pub.dev/packages/share_plus/changelog).
