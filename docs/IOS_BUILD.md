# Building iOS without owning a Mac

The project uses a GitHub Actions macOS runner to compile the iOS application.
The workflow is located at `.github/workflows/build-ios.yml`.

## Run the build

1. Push the project to GitHub.
2. Open the repository on GitHub.
3. Select **Actions**.
4. Select **Build iOS**.
5. Select **Run workflow** and confirm.
6. When the job finishes, download the artifact named
   `monthly-flow-ios-<version>-unsigned`.

The version is read from `pubspec.yaml` automatically.

## Important limitation

The generated ZIP contains an unsigned release `Runner.app`. It verifies that
the Flutter project can compile for a physical iOS device, but it cannot be
installed on an iPhone or uploaded to TestFlight.

To produce an installable `.ipa`, the project additionally needs:

- Apple Developer Program membership
- A unique iOS Bundle ID
- An Apple Distribution certificate
- A matching provisioning profile
- App Store Connect configuration

Keep certificates, passwords, profiles, and API keys in GitHub Actions Secrets.
Never commit them to the repository.
