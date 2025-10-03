
import 'visit_flutter_sdk_platform_interface.dart';

class VisitFlutterSdk {
  Future<String?> getPlatformVersion() {
    return VisitFlutterSdkPlatform.instance.getPlatformVersion();
  }
}
