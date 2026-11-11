import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visit_flutter_sdk/visit_android_webview/visit_android_webview.dart';
import 'package:visit_flutter_sdk/visitwebview_ios/visit_ios_webview.dart';

const _channel = MethodChannel('visit_flutter_sdk');
const _page = '''
<!doctype html><html><body><script>
const report = (kind, value) =>
    fetch('/report?kind=' + kind + '&value=' + encodeURIComponent(JSON.stringify(value)));
const send = event =>
    window.flutter_inappwebview.callHandler('FlutterWebView', JSON.stringify(event));
const calories = () => send({name: 'GET_CALORIE_BURNED'});
window.updateCalorieBurned = kcal => report('calories', kcal);
window.updateFitnessPermissions = connected => report('connected', connected);
window.DetailedGraph = {updateData: (_, values) => report('graph', values)};
window.addEventListener('flutterInAppWebViewPlatformReady', async () => {
  await report('ready', location.pathname);
  for (;;) {
    const action = await (await fetch('/action')).json();
    if (action === 'navigate') {
      location.href = '/next';
      return;
    }
    if (action === 'duplicate') await Promise.all([calories(), calories()]);
    if (action === 'calories') await calories();
    if (action === 'connect') await send({name: 'CONNECT_TO_GOOGLE_FIT'});
    if (action === 'graph') {
      await send({name: 'GET_DATA_TO_GENERATE_GRAPH',
                  type: 'calories', frequency: 'day', timestamp: Date.now()});
    }
    await report('sent', action);
  }
});
</script></body></html>
''';

class _Fixture {
  _Fixture(this.server) {
    server.listen((request) async {
      if (request.uri.path == '/action') {
        final action = Completer<String>();
        actions.add(action);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(await action.future));
      } else if (request.uri.path == '/report') {
        final kind = request.uri.queryParameters['kind']!;
        (reports[kind] ??= []).add(
          jsonDecode(request.uri.queryParameters['value']!),
        );
      } else {
        request.response.headers.contentType = ContentType.html;
        request.response.write(_page);
      }
      await request.response.close();
    });
  }

  final HttpServer server;
  final actions = <Completer<String>>[];
  final reports = <String, List<dynamic>>{};

  Widget get widget {
    final url = 'http://127.0.0.1:${server.port}/';
    return MaterialApp(
      home: Platform.isAndroid
          ? VisitAndroidWebView(initialUrl: url, isLoggingEnabled: true)
          : VisitIosWebView(initialUrl: url, isLoggingEnabled: true),
    );
  }

  List<dynamic> received(String kind) => reports[kind] ?? [];

  Future<void> send(WidgetTester tester, String action) async {
    await _until(tester, () => actions.isNotEmpty);
    actions.removeAt(0).complete(action);
  }
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calorie events update only the current page once per read', (
    tester,
  ) async {
    final fixture = _Fixture(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    addTearDown(() => fixture.server.close(force: true));
    final calls = <MethodCall>[];
    final reads = <Completer<int?>>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) {
      calls.add(call);
      final reply = Completer<int?>();
      reads.add(reply);
      return reply.future;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );

    await tester.pumpWidget(fixture.widget);
    await fixture.send(tester, 'duplicate');
    await _until(
      tester,
      () => reads.isNotEmpty && fixture.received('sent').length == 1,
    );
    expect(reads, hasLength(1));
    reads.single.complete(123);
    await _until(tester, () => fixture.received('calories').length == 1);
    expect(fixture.received('calories'), [123]);

    await fixture.send(tester, 'calories');
    await _until(tester, () => reads.length == 2);
    reads.last.complete(null);
    await tester.pumpAndSettle();
    await fixture.send(tester, 'calories');
    await _until(tester, () => reads.length == 3);
    reads.last.completeError(PlatformException(code: 'permission_denied'));
    await tester.pumpAndSettle();

    await fixture.send(tester, 'calories');
    await _until(tester, () => reads.length == 4);
    reads.last.complete(0);
    await _until(tester, () => fixture.received('calories').length == 2);
    expect(fixture.received('calories'), [123, 0]);

    await fixture.send(tester, 'calories');
    await _until(tester, () => reads.length == 5);
    await fixture.send(tester, 'navigate');
    await _until(tester, () => fixture.received('ready').contains('/next'));
    reads.last.complete(999);
    await tester.pumpAndSettle();

    await fixture.send(tester, 'calories');
    await _until(tester, () => reads.length == 6);
    await tester.pumpWidget(const SizedBox.shrink());
    reads.last.complete(999);
    await tester.pumpAndSettle();
    expect(fixture.received('calories'), [123, 0]);
    expect(calls.map((call) => call.method).toSet(), {
      'getTodayCaloriesBurned',
    });
    expect(calls.every((call) => call.arguments == null), isTrue);
  });

  if (const bool.fromEnvironment('VISIT_TEST_CALORIE_PROVIDER')) {
    testWidgets('today’s card matches the native daily calorie graph', (
      tester,
    ) async {
      final fixture = _Fixture(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      );
      addTearDown(() => fixture.server.close(force: true));
      if (await _channel.invokeMethod<String>('getHealthConnectStatus') !=
          'CONNECTED') {
        expect(
          await _channel.invokeMethod<int>('getTodayCaloriesBurned'),
          isNull,
        );
      }
      await tester.pumpWidget(fixture.widget);

      await fixture.send(tester, 'connect');
      await _until(tester, () => fixture.received('connected').contains(true));

      if (const bool.fromEnvironment('VISIT_TEST_CALORIE_EMPTY')) {
        expect(
          await _channel.invokeMethod<int>('getTodayCaloriesBurned'),
          isNull,
        );
        await fixture.send(tester, 'calories');
        await _until(
          tester,
          () => fixture.received('sent').contains('calories'),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(fixture.received('calories'), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }

      await fixture.send(tester, 'graph');
      await _until(tester, () => fixture.received('graph').isNotEmpty);
      final hours = (fixture.received('graph').single as List<dynamic>)
          .cast<int>();
      expect(hours, isNotEmpty);
      final total = hours.fold(0, (sum, kcal) => sum + kcal);
      const expected = int.fromEnvironment(
        'VISIT_TEST_CALORIE_EXPECTED_KCAL',
        defaultValue: -1,
      );
      if (expected >= 0) expect(total, expected);

      await fixture.send(tester, 'duplicate');
      await _until(tester, () => fixture.received('calories').isNotEmpty);
      expect(fixture.received('calories'), [total]);

      await fixture.send(tester, 'calories');
      await _until(tester, () => fixture.received('calories').length == 2);
      expect(fixture.received('calories'), [total, total]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
