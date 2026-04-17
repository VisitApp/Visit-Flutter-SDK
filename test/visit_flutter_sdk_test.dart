import 'package:flutter_test/flutter_test.dart';
import 'package:visit_flutter_sdk/visit_flutter_sdk_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVisitFlutterSdkPlatform
    with MockPlatformInterfaceMixin
    implements VisitFlutterSdkPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> shareFile(String filePath, {String? mimeType}) async {}
}

void main() {}
