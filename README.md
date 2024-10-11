# Flutter Plugin

### Latest Version 0.0.10

A Flutter plugin that provides WebView access with permissions for location, file read/write, and more.

## Getting Started

This plugin allows you to easily embed a WebView in your Flutter application while managing permissions for location access and file operations.

### Installation

Add the following dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_plugin_name: ^1.0.0
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

Open the android/app/build.gradle file.
To configure the plugin on Android:

```
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

add this in android AndroidManifest.xml file

android:usesCleartextTraffic="true"

```
