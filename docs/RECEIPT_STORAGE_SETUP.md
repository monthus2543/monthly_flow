# Receipt storage

Cloud receipt uploads are currently paused. Builds default to local receipt saving, including signed-in accounts. After completing Storage setup and deploying rules, enable uploads with `--dart-define=ENABLE_RECEIPT_CLOUD=true`. Existing private cloud references can still be read.

When a signed-in user saves an entry, its new local receipt uploads to Firebase Storage at `users/{uid}/receipts/{random-id}.{jpg|png|webp}`. Images must be JPEG, PNG or WebP and no larger than 5 MB. Firestore sync carries a private Storage reference, never the device file path or a public download URL. Only the owner can read the file. Downloaded images are cached for offline viewing.

Offline accounts keep receipts on the device. Existing local attachments upload when edited and saved after signing in; there is no automatic bulk migration. Failed uploads keep the local image and the form open for retry. Removing an attachment syncs the removal but retains the Storage object because repeating entries may share it.

## Firebase setup

Create or enable the project's default Storage bucket in the Firebase console. Check the `storage_bucket` in `android/app/google-services.json` (and the iOS configuration if used) against that bucket. This app initializes Firebase from the native configuration files. Authenticate the Firebase CLI, then deploy the repository's `storage.rules`:

```powershell
node .dart_tool/report-email-cli/node_modules/firebase-tools/lib/bin/firebase.js login
node .dart_tool/report-email-cli/node_modules/firebase-tools/lib/bin/firebase.js deploy --only storage --project monthly-flow-75287
```

Local rule changes are not active on Firebase until deployment succeeds. After deployment, verify attaching and saving a receipt on one signed-in device, syncing and opening it on another, and denying access from a different account.
