# Visit Flutter Plugin

### Latest Version 1.0.5

A Flutter plugin that provides WebView access with permissions for location, file read/write, and more.

## Getting Started

This plugin allows you to easily embed a WebView in your Flutter application while managing permissions for location access and file operations.

### Installation

Add the following dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_plugin_name: ^1.0.1
```

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
```

### Android Setup

1. Add these permission in Manifest.xml

```
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.INTERNET" />
```

2. Add this File Provider if already not present:

```
        <provider
            android:name="com.pichillilorenzo.flutter_inappwebview.InAppWebViewFileProvider"
            android:authorities="${applicationId}.flutter_inappwebview.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/provider_paths" />
        </provider>
```
