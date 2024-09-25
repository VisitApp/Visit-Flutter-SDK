import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'visit_flutter_sdk_platform_interface.dart';

/// An implementation of [VisitFlutterSdkPlatform] that uses method channels.
class MethodChannelVisitFlutterSdk extends VisitFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('visit_flutter_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
