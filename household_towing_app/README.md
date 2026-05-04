# Household Towing App

Flutter client for the DUALSERVE system.

## App Structure

```text
lib/
|-- main.dart
|-- firebase_options.dart
|-- models/       # Firestore/domain models
|-- providers/    # App state providers
|-- screens/      # Auth, admin, customer, provider, and chat UI
|-- services/     # Firebase and domain service classes
|-- utils/        # Theme, validators, pricing, maps, and error helpers
`-- widgets/      # Shared reusable UI widgets
```

## App Documentation

Feature and workflow notes for the Flutter app live in `docs/`, including task management, provider acceptance, and primary booking flow references.

## Common Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build web
```

Run Firebase deploy commands from the repository root, not from this folder. The root `firebase.json` references this app's Firestore rules, indexes, and web build output.
