# Android health bridge regression fixture

The fixture uses the production `VisitAndroidWebView`, a loopback HTML page, and the real Android method channel. It does
not require an SSO URL or sync health records to a server. Run it on an emulator
with Health Connect available.

The example resolves its native SDK from JitPack. Its debug manifest allows the
fixture's loopback HTTP server.

From `example/`, after granting the example app's six requested Health Connect
permissions:

```sh
fvm flutter test integration_test/health_bridge_integration_test.dart -d emulator-5554
```

To also exercise the actual permission prompt, revoke those permissions first
and run:

```sh
fvm flutter test integration_test/health_bridge_integration_test.dart -d emulator-5554 \
  --dart-define=VISIT_TEST_PERMISSION_FLOW=true
```

Allow all requested permissions in the system dialog. The first test sends two
connect calls plus dashboard and graph calls while that prompt is pending. All
four callers must finish after the single permission decision. The remaining
tests cover duplicate and overlapping native requests, integer timestamps,
invalid arguments, and duplicate JavaScript events through a local WebView.
