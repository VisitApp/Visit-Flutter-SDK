package com.example.visit_flutter_sdk

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import org.mockito.Mockito

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class VisitFlutterSdkPluginTest {
  @Test
  fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
    val plugin = VisitFlutterSdkPlugin()

    val call = MethodCall("getPlatformVersion", null)
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.RELEASE)
  }

  @Test
  fun integerGraphArgumentsReachTheActivityCheckWithoutCastingToLong() {
    val plugin = VisitFlutterSdkPlugin()
    val result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(MethodCall("requestActivityDataFromHealthConnect", mapOf(
      "type" to "steps", "frequency" to "day", "timestamp" to 1,
    )), result)
    Mockito.verify(result).error("activity_unavailable", "No activity is attached.", null)
    Mockito.verifyNoMoreInteractions(result)
  }

  @Test
  fun malformedGraphArgumentsReceiveExactlyOneError() {
    val plugin = VisitFlutterSdkPlugin()
    val result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(MethodCall("requestActivityDataFromHealthConnect", mapOf(
      "type" to "steps", "frequency" to "day", "timestamp" to 1.5,
    )), result)
    Mockito.verify(result).error("invalid_arguments", "Expected integer timestamp.", null)
    Mockito.verifyNoMoreInteractions(result)
  }

  @Test
  fun settingsWithoutAnActivityAndUnknownMethodsCompleteOnce() {
    val plugin = VisitFlutterSdkPlugin()
    val settings = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(MethodCall("openHealthConnectApp", null), settings)
    Mockito.verify(settings).error("activity_unavailable", "No activity is attached.", null)
    Mockito.verifyNoMoreInteractions(settings)
    val unknown = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(MethodCall("unknown", null), unknown)
    Mockito.verify(unknown).notImplemented()
    Mockito.verifyNoMoreInteractions(unknown)
  }
}
