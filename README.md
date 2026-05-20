# Visit Flutter Plugin

### Latest Version 2.0.8

A Flutter plugin that provides WebView access with permissions for location, file read/write, and more.

## Getting Started

This plugin allows you to easily embed a WebView in your Flutter application while managing permissions for location access and file operations.

### Installation

Add the following dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  visit_flutter_sdk: ^2.0.8
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
<key>NSHealthShareUsageDescription</key>
<string>We use Apple Health data to show your steps, distance, calories, and sleep insights.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We request Apple Health access to sync your fitness information with Visit.</string>

<key>LSApplicationQueriesSchemes</key>
<array>
	<string>tel</string>
</array>
```

Add the HealthKit entitlement to your iOS target as well:

```
<key>com.apple.developer.healthkit</key>
<true/>
```

On iOS, the webview event `CONNECT_TO_GOOGLE_FIT` now triggers the Apple Health permission flow through the plugin. After access is granted, the plugin serves the same graph and daily fitness data callbacks used by the Android/web bridge.

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

2. Add your company's privacy policy URL inside the app-level
   `android/app/src/main/AndroidManifest.xml` file, under the `<application>`
   tag. Android Health Connect uses this page when it shows the permission
   usage/rationale screen.

```
        <meta-data
            android:name="visit_flutter_sdk.health_connect_privacy_policy_url"
            android:value="https://your-company.example.com/privacy-policy" />
```

   Replace the example value with your public privacy policy URL. The URL must
   be a valid `https` or `http` URL.

3. The plugin declares its own file-share provider for downloaded files, and
   Flutter should merge it into your app automatically. Do not add the old
   `flutter_inappwebview_android` provider for Visit SDK downloads.

   If your app has custom manifest merging and needs to declare the provider
   manually, use the Visit SDK provider below:

```
        <provider
            android:name="com.example.visit_flutter_sdk.VisitFlutterSdkFileProvider"
            android:authorities="${applicationId}.visit_flutter_sdk.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/visit_flutter_sdk_file_paths" />
        </provider>
```
