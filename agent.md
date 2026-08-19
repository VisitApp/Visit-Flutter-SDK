# Agent Guide — Visit Flutter SDK

## Current branch context

- Branch: `main` (currently aligned with `origin/main`).
- Treat this branch as the release-ready baseline. Keep changes focused, avoid unrelated reformatting, and do not change versions or changelog entries unless the task explicitly includes a release.
- The package version is defined in `pubspec.yaml`; release notes belong in `CHANGELOG.md` under the matching version heading.

## Project overview

`visit_flutter_sdk` is a Flutter plugin that presents the Visit SSO flow in an in-app WebView, with platform-specific handling for permissions, downloads, file sharing, location, and external URL actions.

Key areas:

- `lib/visit_flutter_sdk.dart` — public `VisitFlutterSdk` widget and Android/iOS WebView selection.
- `lib/visit_android_webview/` — Android WebView UI and behavior.
- `lib/visitwebview_ios/` — iOS WebView UI and behavior.
- `lib/visit_flutter_sdk_platform_interface.dart` and `lib/visit_flutter_sdk_method_channel.dart` — plugin platform-interface and method-channel scaffold.
- `android/` — Kotlin plugin registration and Android configuration.
- `ios/` — Swift plugin registration, podspec, and privacy manifest.
- `example/` — integration/example app; use it for manual platform verification.
- `test/` — Dart unit tests.

## Implementation guidance

- Preserve the public API unless the requested change explicitly requires a breaking change. The main entry point accepts `ssoUrl` and an optional `isLoggingEnabled` flag.
- Keep Android- and iOS-only code in their existing platform-specific WebView modules. When behavior must match, implement and verify both sides deliberately.
- If adding a MethodChannel method, update the Dart API, Android Kotlin implementation, iOS Swift implementation, and tests together. Keep the channel name `visit_flutter_sdk` compatible with existing clients.
- Permission, download, share, and external-app changes often require corresponding Android manifest, iOS Info.plist guidance in `README.md`, podspec, or privacy-manifest updates. Review these artifacts whenever native capabilities change.
- Do not log sensitive URLs, authentication parameters, local file paths, or permission data. Respect `isLoggingEnabled` for diagnostic output.
- Retain existing assets and the Mulish font configuration in `pubspec.yaml` when modifying UI.

## Validation

Run the smallest relevant checks first:

```sh
flutter analyze
flutter test
```

For Android or iOS changes, also validate the affected example-app platform build when the local toolchain is available. Manually cover the changed WebView flow, including relevant permission prompts, back navigation, downloads/uploads, sharing, or external links.

## Change hygiene

- Follow `analysis_options.yaml` (`flutter_lints`) and existing local style.
- Add or update focused tests for Dart and MethodChannel behavior. Native changes should include platform build verification where practical.
- Keep `README.md` setup instructions current when a consumer must add a new permission, provider, entitlement, or configuration value.
- Before handoff, review `git diff` and ensure generated platform files, credentials, and local build output are not included.
