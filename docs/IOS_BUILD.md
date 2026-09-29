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

## Build a signed IPA

The manual workflow `.github/workflows/build-ios-signed.yml` can export an IPA
and optionally upload it to TestFlight.

Add these repository secrets under **Settings > Secrets and variables >
Actions**:

| Secret | Value |
| --- | --- |
| `IOS_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution `.p12` file |
| `IOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` file |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store `.mobileprovision` file |
| `IOS_KEYCHAIN_PASSWORD` | A new random password used only by the temporary CI keychain |

To upload to TestFlight, also add:

| Secret | Value |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | Base64-encoded `.p8` API private key |

On Windows PowerShell, encode each file without adding line breaks:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_KEYID.p8"))
```

Copy each command's output into its matching GitHub secret. Then open
**Actions > Build signed iOS IPA > Run workflow**. Leave
`upload_to_testflight` disabled to download only the signed IPA, or enable it
to upload the build to TestFlight after export.
