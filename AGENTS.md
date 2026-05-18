# Agent Notes

## Project Overview

This repository is a Flutter plugin package named `visit_flutter_sdk`. It exposes a `VisitFlutterSdk` widget that embeds an in-app webview and bridges web JavaScript events to Flutter and native Android/iOS behavior.

Main capabilities:

- WebView loading for Visit SSO URLs.
- Location permission and GPS prompts.
- Phone dialer launching.
- PDF/file download and native share-sheet handoff.
- Android Health Connect integration.
- iOS HealthKit integration exposed through the same web bridge callbacks.

## Environment

Use FVM for all Flutter commands. Plain `flutter` may not be on PATH.

```sh
fvm flutter --version
fvm flutter pub get
fvm flutter test
fvm flutter analyze
```

The repo is pinned to Flutter `3.41.9` in `.fvmrc`, with package constraints in `pubspec.yaml`:

- Dart SDK: `>=3.11.0 <4.0.0`
- Flutter: `>=3.41.9 <3.42.0`

## Important Paths

- `lib/visit_flutter_sdk.dart`: public widget entry point.
- `lib/visit_android_webview/visit_android_webview.dart`: Android webview bridge.
- `lib/visitwebview_ios/visit_ios_webview.dart`: iOS webview bridge.
- `lib/visit_flutter_sdk_method_channel.dart`: Dart method-channel wrapper.
- `lib/visit_flutter_sdk_platform_interface.dart`: platform-interface abstraction.
- `android/src/main/kotlin/com/example/visit_flutter_sdk/VisitFlutterSdkPlugin.kt`: Android native method-channel implementation.
- `ios/Classes/VisitFlutterSdkPlugin.swift`: iOS native method-channel implementation.
- `example/`: example Flutter app for plugin integration checks.

## Native Integration Notes

Android depends on:

- `com.github.VisitApp:VisitAndroidSDK:v3.01-alpha`
- `androidx.health.connect:connect-client`
- JitPack, Google Maven, and Maven Central repositories.

Android file sharing uses:

- Provider class: `com.example.visit_flutter_sdk.VisitFlutterSdkFileProvider`
- Authority: `${applicationId}.visit_flutter_sdk.fileprovider`
- Paths resource: `@xml/visit_flutter_sdk_file_paths`

iOS depends on HealthKit and declares a privacy manifest bundle in `ios/visit_flutter_sdk.podspec`.

## Verification Commands

For plugin-level checks:

```sh
fvm flutter pub get
fvm flutter test
fvm flutter analyze
```

For Android example build:

```sh
cd example
fvm flutter build apk --debug
```

For iOS compile validation without signing:

```sh
cd example
fvm flutter build ios --no-codesign
```

Note: Flutter may auto-migrate files under `example/ios` during iOS builds. Treat those as generated framework migrations unless the task explicitly asks to edit iOS project settings.

## Current Quality Notes

At the time this file was created:

- `fvm flutter test` passed.
- `fvm flutter analyze` reported lint/info issues, mostly deprecated Flutter/webview APIs, production `print` calls, private state types in public widget APIs, and async `BuildContext` warnings.
- The Android and iOS example builds completed successfully.

## Editing Guidance

- Keep plugin API changes backward-compatible unless the task explicitly requests a breaking change.
- Keep Android and iOS web bridge behavior aligned when adding or renaming JavaScript callback methods.
- Be careful with method-channel method names; they are shared between Dart, Android, and iOS.
- Do not replace the Health Connect or HealthKit flows without checking the web callback expectations.
- Do not commit real SSO URLs, user tokens, auth tokens, or client-specific secrets in the example app or docs.
- Leave unrelated generated files and user changes untouched.
