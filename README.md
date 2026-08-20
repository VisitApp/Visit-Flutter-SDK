# Visit Flutter Plugin

### Latest Version 3.0.0

A Flutter plugin that provides WebView access with permissions for location, file read/write, and more.

## Getting Started

This plugin allows you to easily embed a WebView in your Flutter application while managing permissions for location access and file operations.

### Installation

Add the following dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  visit_flutter_sdk: ^3.0.0
```

### Compatibility

Version 3.x targets Flutter 3.35.x (Dart 3.9.x) and the following dependency compatibility line:

- `flutter_inappwebview: 6.1.5`
- `flutter_svg: ^1.1.6`
- `geolocator: ^13.0.4`
- `permission_handler: ^11.1.0`
- `url_launcher: ^6.1.8`

This is a major-version compatibility release. Clients using earlier Flutter or third-party plugin versions should remain on the SDK major version that matches their dependency set.

### iOS Setup

Open the ios/Runner/Info.plist file.
Add the following permissions:

```
<key>NSAppTransportSecurity</key>
<dict>
	<key>NSAllowsArbitraryLoads</key>
	<true/>
</dict>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library for uploading images.</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera for scanning QR codes.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app requires access to your location while in use.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app requires access to your location even when not in use.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Your message explaining why the app needs location access.</string>

<key>LSApplicationQueriesSchemes</key>
<array>
	<string>tel</string>
</array>
```

### Android Setup

1. Add these permission in Manifest.xml

```
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.INTERNET" />
    
    

    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="tel" />
        </intent>
    </queries>
```

2. No FileProvider configuration is required. The SDK supplies the current
   InAppWebView FileProvider through Android manifest merging.

### HTML camera and file capture

The bundled FileProvider enables Android HTML file inputs that capture images,
video, or audio (for example, `<input type="file" capture>`). If your hosted
web content uses those features, declare the applicable camera and microphone
permissions in your app and request them at runtime.

Do not add another provider using the
`${applicationId}.flutter_inappwebview_android.fileprovider` authority solely
for this SDK. If your application separately configures InAppWebView with that
same authority, keep a single provider declaration in the merged manifest.
