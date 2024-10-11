import 'package:flutter_test/flutter_test.dart';
import 'package:visit_flutter_sdk/visit_flutter_sdk.dart';
import 'package:visit_flutter_sdk/visit_flutter_sdk_platform_interface.dart';
import 'package:visit_flutter_sdk/visit_flutter_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVisitFlutterSdkPlatform
    with MockPlatformInterfaceMixin
    implements VisitFlutterSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VisitFlutterSdkPlatform initialPlatform = VisitFlutterSdkPlatform.instance;

  test('$MethodChannelVisitFlutterSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVisitFlutterSdk>());
  });

  test('getPlatformVersion', () async {
    VisitFlutterSdk visitFlutterSdkPlugin = VisitFlutterSdk();
    MockVisitFlutterSdkPlatform fakePlatform = MockVisitFlutterSdkPlatform();
    VisitFlutterSdkPlatform.instance = fakePlatform;

    expect(await visitFlutterSdkPlugin.getPlatformVersion(), '42');
  });
}
