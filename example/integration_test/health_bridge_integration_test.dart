import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visit_flutter_sdk/visit_android_webview/visit_android_webview.dart';

// This local fixture contains no SSO URL, token, or server-sync operation.
const fixture = '''<!doctype html><html><body><h1>Health bridge fixture</h1>
<pre id="results"></pre><script>
window.fixtureUpdates = [];
function record(kind, args) {
  fixtureUpdates.push({kind: kind, args: Array.from(args)});
  document.getElementById('results').textContent = JSON.stringify(fixtureUpdates);
  fetch('/report?kind=' + encodeURIComponent(kind) + '&args=' + encodeURIComponent(JSON.stringify(Array.from(args))));
}
window.updateFitnessPermissions = function() { record('dashboard', arguments); };
window.healthConnectNotSupported = function() { record('unsupported', arguments); };
window.healthConnectNotInstall = function() { record('not-installed', arguments); };
window.healthConnectAvailable = function() { record('available', arguments); };
window.DetailedGraph = {
  updateData: function() { record(arguments[2], arguments); },
  updateDailySleep: function() { record('sleep', arguments); },
  updateSleepData: function() { record('sleep', arguments); }
};
window.addEventListener('flutterInAppWebViewPlatformReady', function() {
  const timestamp = FIXTURE_TIMESTAMP;
  const send = event => window.flutter_inappwebview.callHandler('FlutterWebView', JSON.stringify(event));
  Promise.all([
    ...Array.from({length: 2}, () => send({name:'GET_HEALTH_CONNECT_STATUS'})),
    ...Array.from({length: 2}, () => send({name:'GET_DATA_TO_GENERATE_GRAPH',type:'steps',frequency:'day',timestamp:timestamp})),
    send({name:'GET_DATA_TO_GENERATE_GRAPH',type:'sleep',frequency:'week',timestamp:timestamp})
  ]);

});
</script></body></html>''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('visit_flutter_sdk');

  if (const bool.fromEnvironment('VISIT_TEST_PERMISSION_FLOW')) {
    testWidgets('one system permission prompt resumes all native waiters', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Grant the fixture Health Connect permissions'),
            ),
          ),
        ),
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final results = await Future.wait([
        channel.invokeMethod<String>('askForFitnessPermission'),
        channel.invokeMethod<String>('askForFitnessPermission'),
        channel.invokeMethod<String>('requestDailyFitnessData'),
        channel.invokeMethod<String>('requestActivityDataFromHealthConnect', {
          'type': 'steps',
          'frequency': 'day',
          'timestamp': timestamp,
        }),
      ]).timeout(const Duration(minutes: 2));
      expect(results.take(2), ['GRANTED', 'GRANTED']);
      expect(results[2], startsWith('window.updateFitnessPermissions('));
      expect(results[3], startsWith('DetailedGraph.updateData('));
    });
  }

  testWidgets(
    'real channel settles duplicate and overlapping native graph calls',
    (tester) async {
      final statuses = await Future.wait(
        List.generate(
          20,
          (_) => channel.invokeMethod<String>('getHealthConnectStatus'),
        ),
      ).timeout(const Duration(seconds: 40));
      expect(
        statuses.toSet(),
        {'CONNECTED'},
        reason:
            'Grant the example Health Connect permissions before running this fixture.',
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final values = await Future.wait([
        for (var i = 0; i < 10; i++)
          channel.invokeMethod<String>('requestDailyFitnessData'),
        for (var i = 0; i < 10; i++)
          channel.invokeMethod<String>('requestActivityDataFromHealthConnect', {
            'type': 'steps',
            'frequency': 'day',
            'timestamp': timestamp,
          }),
        channel.invokeMethod<String>('requestActivityDataFromHealthConnect', {
          'type': 'sleep',
          'frequency': 'week',
          'timestamp': timestamp,
        }),
        channel.invokeMethod<String>('requestActivityDataFromHealthConnect', {
          'type': 'distance',
          'frequency': 'day',
          'timestamp': timestamp,
        }),
      ]).timeout(const Duration(seconds: 40));
      expect(values.take(10).toSet(), hasLength(1));
      expect(values.first, startsWith('window.updateFitnessPermissions('));
      expect(values.skip(10).take(10).toSet(), hasLength(1));
      expect(values[10], contains("'steps', 'day'"));
      expect(values[20], startsWith('DetailedGraph.updateSleepData('));
      expect(values[21], contains("'distance', 'day'"));

      await expectLater(
        channel.invokeMethod<String>('requestActivityDataFromHealthConnect', {
          'type': 'sleep',
          'frequency': 'month',
          'timestamp': 1,
        }),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'invalid_arguments',
          ),
        ),
      );
      // Int32 timestamps must also work through StandardMethodCodec.
      expect(
        await channel.invokeMethod<String>(
          'requestActivityDataFromHealthConnect',
          {'type': 'steps', 'frequency': 'day', 'timestamp': 1},
        ),
        startsWith('DetailedGraph.updateData('),
      );
    },
  );

  testWidgets(
    'real VisitAndroidWebView suppresses duplicate JavaScript effects',
    (tester) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final updates = <(String, dynamic)>[];
      final completed = Completer<void>();
      final html = fixture.replaceAll(
        'FIXTURE_TIMESTAMP',
        '${DateTime.now().millisecondsSinceEpoch}',
      );
      server.listen((request) async {
        if (request.uri.path == '/report') {
          updates.add((
            request.uri.queryParameters['kind']!,
            jsonDecode(request.uri.queryParameters['args']!),
          ));
          if (updates.map((u) => u.$1).toSet().containsAll([
                'dashboard',
                'steps',
                'sleep',
              ]) &&
              !completed.isCompleted) {
            completed.complete();
          }
        } else {
          request.response.headers.contentType = ContentType.html;
          request.response.write(html);
        }
        await request.response.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: VisitAndroidWebView(
            initialUrl: 'http://127.0.0.1:${server.port}/',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await completed.future.timeout(const Duration(seconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(updates.where((u) => u.$1 == 'dashboard'), hasLength(1));
      expect(updates.where((u) => u.$1 == 'steps'), hasLength(1));
      expect(updates.where((u) => u.$1 == 'sleep'), hasLength(1));
      expect(updates.singleWhere((u) => u.$1 == 'dashboard').$2[0], isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
