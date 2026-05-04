# DUALSERVE

DUALSERVE is a Flutter service app with Firebase hosting, Firestore, Authentication, Cloud Messaging, Storage, and Cloud Functions.

## Repository Structure

```text
.
|-- firebase.json                 # Repo-root Firebase deploy config
|-- .firebaserc                   # Firebase project aliases and hosting target
|-- docs/                         # Deployment, setup, and migration docs
|-- functions/                    # Cloud Functions source
|   |-- index.js
|   |-- emailTemplates.js
|   `-- package.json
|-- household_towing_app/         # Flutter application
|   |-- docs/                     # App feature and workflow docs
|   |-- lib/                      # Dart application code
|   |-- test/                     # Flutter tests
|   |-- android/ ios/ web/ ...    # Flutter platform projects
|   |-- firestore.rules           # Firestore security rules
|   |-- firestore.indexes.json    # Firestore composite indexes
|   |-- firebase.json             # FlutterFire generated app metadata
|   `-- pubspec.yaml
`-- storage.rules                 # Firebase Storage security rules
```

## Documentation

Start with these files when setting up or deploying the system:

- `docs/QUICK_REFERENCE.md`
- `docs/DEPLOYMENT_GUIDE.md`
- `docs/ADMIN_SETUP_GUIDE.md`
- `docs/MIGRATION_CHECKLIST.md`

App-specific implementation notes are kept in `household_towing_app/docs/`.

## Working Directories

Use the repo root for Firebase deploys:

```bash
firebase use production
firebase deploy
```

Use the Flutter app folder for app development:

```bash
cd household_towing_app
flutter pub get
flutter run
```

Build web hosting output before deploying hosting:

```bash
cd household_towing_app
flutter build web
cd ..
firebase deploy --only hosting
```

Install Cloud Functions dependencies from the functions folder:

```bash
cd functions
npm install
```

## Deployment Notes

- The root `firebase.json` is the deployment entry point.
- Hosting now points to `household_towing_app/build/web`, which is where Flutter writes web builds.
- Firestore rules and indexes intentionally live with the Flutter app and are referenced by the root Firebase config.
- `household_towing_app/firebase.json` is kept for FlutterFire tooling metadata and should not be used as the main deploy config.
