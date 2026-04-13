import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visit_flutter_sdk/visit_flutter_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger;

  MethodChannelVisitFlutterSdk platform = MethodChannelVisitFlutterSdk();
  const MethodChannel channel = MethodChannel('visit_flutter_sdk');

  setUp(() {
    messenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
