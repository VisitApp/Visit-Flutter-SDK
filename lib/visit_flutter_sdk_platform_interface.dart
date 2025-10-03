import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'visit_flutter_sdk_method_channel.dart';

abstract class VisitFlutterSdkPlatform extends PlatformInterface {
  /// Constructs a VisitFlutterSdkPlatform.
  VisitFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static VisitFlutterSdkPlatform _instance = MethodChannelVisitFlutterSdk();

  /// The default instance of [VisitFlutterSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelVisitFlutterSdk].
  static VisitFlutterSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VisitFlutterSdkPlatform] when
  /// they register themselves.
  static set instance(VisitFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
