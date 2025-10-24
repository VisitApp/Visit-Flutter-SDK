import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../alert_dialog.dart';
import '../colored_safe_area_widget.dart';

class VisitAndroidWebView extends StatefulWidget {
  const VisitAndroidWebView({
    super.key,
    required this.initialUrl,
    this.isLoggingEnabled = false,
  });

  final String initialUrl;
  final bool isLoggingEnabled;

  @override
  _VisitAndroidWebViewState createState() => _VisitAndroidWebViewState();
}

class _VisitAndroidWebViewState extends State<VisitAndroidWebView> {
  static const platform = MethodChannel('visit_flutter_sdk');
  String _batteryLevel = 'Unknown battery level.';

  late InAppWebViewController _webViewController;
  String TAG = "mytag";
  bool _isLoading = false;

  Future<bool> _onWillPop() async {
    if (await _webViewController.canGoBack()) {
      _webViewController.goBack();
      return false; // Prevent the default back action
    }
    return true; // Allow the default back action
  }

  Future<void> _makePhoneCall(int phoneNumber) async {
    final Uri telUri = Uri(scheme: 'tel', path: phoneNumber.toString());

    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch the dialer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    InAppWebViewSettings settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      allowFileAccessFromFileURLs: true,
      transparentBackground: true,
      useWideViewPort: true,
      builtInZoomControls: true,
      geolocationEnabled: true,
      allowFileAccess: true,
      allowsInlineMediaPlayback: true,
    );

    return ColoredSafeArea(
      color: Colors.white,
      child: Stack(
        children: [
          WillPopScope(
            onWillPop: _onWillPop,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: InAppWebView(
                initialSettings: settings,
                initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                onWebViewCreated: (InAppWebViewController controller) {
                  _webViewController = controller;

                  _webViewController.addJavaScriptHandler(
                    handlerName: 'FlutterWebView',
                    callback: (List<dynamic> args) {
                      // Get message from JavaScript code, which could be the result of some operation.
                      try {
                        String jsonString = args[0];

                        Map<String, dynamic> callbackResponse = jsonDecode(
                          jsonString,
                        );

                        if (widget.isLoggingEnabled) {
                          log("$TAG: callbackResponse: $callbackResponse");
                        }

                        String methodName = callbackResponse['name']!;

                        if (methodName == "GET_LOCATION_PERMISSIONS") {
                          _checkForLocationAndGPSPermission();
                        } else if (methodName == "DOWNLOAD_PDF") {
                          String pdfLink = callbackResponse['link']!;
                          _openPDF(pdfLink);
                        } else if (methodName == "CLOSE_VIEW") {
                          Navigator.pop(context);
                          // SystemNavigator.pop();
                        } else if (methodName == "OPEN_DAILER") {
                          int? phone = callbackResponse['number'];
                          _makePhoneCall(phone!);
                        } else if (methodName == "BATTERY_STATUS") {
                          _getBatteryLevel();
                        } else if (methodName == "GET_HEALTH_CONNECT_STATUS") {
                          _getHealthConnectStatus();
                        } else if (methodName == "CONNECT_TO_GOOGLE_FIT") {
                          _askForHealthConnectPermission();
                        } else if (methodName == "UPDATE_PLATFORM") {
                          _updatePlatform();
                        } else if (methodName == "UPDATE_API_BASE_URL") {
                          _updateApiBaseUrl(callbackResponse);
                        } else if (methodName == "GET_DATA_TO_GENERATE_GRAPH") {
                          _getDataToGenerateDetailedGraph(callbackResponse);
                        }
                      } catch (e) {
                        log("$TAG: args: $e");
                      }
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    print('Page started loading: $url');
                    // _isLoading = true;
                  });
                },
                onLoadStop: (controller, url) {
                  setState(() {
                    // _isLoading = false;
                  });
                },
                onGeolocationPermissionsShowPrompt: (controller, origin) async {
                  // Ask runtime permission first (using permission_handler)
                  var status = await Permission.locationWhenInUse.status;
                  if (!status.isGranted) {
                    status = await Permission.locationWhenInUse.request();
                  }

                  final allow = status.isGranted;
                  // If permanently denied, consider guiding the user to settings:
                  if (status.isPermanentlyDenied) {
                    // await openAppSettings(); // optional: prompt user to open settings
                  }

                  return GeolocationPermissionShowPromptResponse(
                    origin: origin,
                    allow: allow,
                    retain: true, // remember this decision for this origin
                  );
                },
              ),
            ),
          ),
          if (_isLoading)
            const Align(
              alignment: Alignment(0.0, 0.7),
              // Align at 0.8 part of the screen height
              child: CircularProgressIndicator(color: Color(0xFFEC6625)),
            ),

          Align(
            alignment: Alignment(0.0, 0.7),
            // Align at 0.8 part of the screen height
            child: Text("Battery Level: $_batteryLevel"),
          ),
        ],
      ),
    );
  }

  Future<void> _getHealthConnectStatus() async {
    log("$TAG: _getHealthConnectStatus() called");

    String? healthConnectStatus;
    try {
      healthConnectStatus = await platform.invokeMethod<String?>(
        'getHealthConnectStatus',
      );

      if (healthConnectStatus != null) {
        if (healthConnectStatus == 'NOT_SUPPORTED') {
          _webViewController.evaluateJavascript(
            source: 'window.healthConnectNotSupported()',
          );
        } else if (healthConnectStatus == 'NOT_INSTALLED') {
          _webViewController.evaluateJavascript(
            source: 'window.healthConnectNotInstall()',
          );
          _webViewController.evaluateJavascript(
            source: 'window.updateFitnessPermissions(false,0,0)',
          );
        } else if (healthConnectStatus == 'INSTALLED') {
          _webViewController.evaluateJavascript(
            source: 'window.healthConnectAvailable()',
          );

          _webViewController.evaluateJavascript(
            source: 'window.updateFitnessPermissions(false,0,0)',
          );
        } else if (healthConnectStatus == 'CONNECTED') {
          _getDailyFitnessData();
        }
      }
      log("$TAG: callbackResponse: $healthConnectStatus");
    } on PlatformException catch (e) {
      log("$TAG:Failed to get Health Connect Status: '${e.message}'.");
    }
  }

  Future<void> _getDailyFitnessData() async {
    log("$TAG: _getDailyFitnessData() called");

    String? dailyFitnessData;
    try {
      dailyFitnessData = await platform.invokeMethod<String?>(
        'requestDailyFitnessData',
      );

      log("$TAG: callbackResponse: $dailyFitnessData");

      if (dailyFitnessData != null) {
        _webViewController.evaluateJavascript(source: dailyFitnessData);
      }
    } on PlatformException catch (e) {
      log("$TAG:Failed to get Health Connect Status: '${e.message}'.");
    }
  }

  Future<void> _askForHealthConnectPermission() async {
    log("$TAG: _askForHealthConnectPermission() called");

    String? isPermissionGranted;
    try {
      isPermissionGranted = await platform.invokeMethod<String?>(
        'askForFitnessPermission',
      );

      log("$TAG: callbackResponse: $isPermissionGranted");

      if (isPermissionGranted == "GRANTED") {
        _getHealthConnectStatus();
      } else if (isPermissionGranted == "CANCELLED") {
        _showHealthConnectPermissionDeniedDialog();
      }
    } on PlatformException catch (e) {
      log("$TAG:Failed to get Health Connect Status: '${e.message}'.");
    }
  }

  Future<void> _openHealthConnectSettings() async {
    log("$TAG: _openHealthConnectSettings() called");

    try {
      await platform.invokeMethod<String?>('openHealthConnectApp');
    } on PlatformException catch (e) {
      log("$TAG:Failed to get Health Connect Status: '${e.message}'.");
    }
  }

  Future<void> _updatePlatform() async {
    _webViewController.evaluateJavascript(
      source: 'window.setSdkPlatform("ANDROID")',
    );
  }

  Future<void> _updateApiBaseUrl(Map<String, dynamic> callbackResponse) async {
    log("$TAG: _updateApiBaseUrl() called");

    String apiBaseUrl = callbackResponse['apiBaseUrl']!;
    String authtoken = callbackResponse['authtoken']!;
    int googleFitLastSync = int.parse(callbackResponse['googleFitLastSync']!);
    int gfHourlyLastSync = int.parse(callbackResponse['gfHourlyLastSync']!);

    log("$TAG: apiBaseUrl: $apiBaseUrl, authtoken: $authtoken, googleFitLastSync: $googleFitLastSync, gfHourlyLastSync: $gfHourlyLastSync");

    String? syncMessage;
    try {
      syncMessage = await platform.invokeMethod<String?>(
        'updateApiBaseUrl',
        {'apiBaseUrl': apiBaseUrl, 'authtoken': authtoken, 'googleFitLastSync': googleFitLastSync, 'gfHourlyLastSync': gfHourlyLastSync},
      );

      log("$TAG: message: $syncMessage");

    } on PlatformException catch (e) {
      log("$TAG:Failed to get Health Connect Status: '${e.message}'.");
    }
  }

  Future<void> _getDataToGenerateDetailedGraph(
    Map<String, dynamic> callbackResponse,
  ) async {
    log("$TAG: _getDataToGenerateDetailedGraph() called");

    String type = callbackResponse['type']!;
    String frequency = callbackResponse['frequency']!;
    int timestamp = int.parse(callbackResponse['timestamp']!);

    log("$TAG: type: $type, frequency: $frequency, timestamp: $timestamp");

    String? graphData;
    try {
      graphData = await platform.invokeMethod<String?>(
        'requestActivityDataFromHealthConnect',
        {'type': type, 'frequency': frequency, 'timestamp': timestamp},
      );

      String finalString = "window.$graphData";

      log("$TAG: finalString: $finalString");

      if (graphData != null) {
        _webViewController.evaluateJavascript(source: finalString);
      }
    } on PlatformException catch (e) {
      log("$TAG:Failed to get Health Connect Status: '${e.message}'.");
    }
  }

  Future<void> _getBatteryLevel() async {
    String batteryLevel;
    try {
      final result = await platform.invokeMethod<int>('getBatteryLevel');
      batteryLevel = 'Battery level at $result % .';
    } on PlatformException catch (e) {
      batteryLevel = "Failed to get battery level: '${e.message}'.";
    }

    setState(() {
      _batteryLevel = batteryLevel;
    });
  }

  void _openPDF(String pdfLink) async {
    try {
      if (await canLaunchUrl(Uri.parse(pdfLink))) {
        await launchUrl(Uri.parse(pdfLink));
      } else {
        throw 'Could not launch $pdfLink';
      }
    } catch (e) {}
  }

  void _checkForLocationAndGPSPermission() async {
    if (widget.isLoggingEnabled) {
      log('$TAG: checkForLocationAndGPSPermission: called');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    log('$TAG: checkForLocationAndGPSPermission permissionState : $permission');

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      if (widget.isLoggingEnabled) {
        log(
          '$TAG: checkForLocationAndGPSPermission permissionState : $permission',
        );
      }

      bool isGPSPermissionEnabled = await Geolocator.isLocationServiceEnabled();

      if (widget.isLoggingEnabled) {
        log(
          '$TAG: checkForLocationAndGPSPermission isGPSPermissionEnabled : $isGPSPermissionEnabled',
        );
      }

      if (isGPSPermissionEnabled) {
        if (widget.isLoggingEnabled) {
          log(
            '$TAG: checkForLocationAndGPSPermission "window.checkTheGpsPermission(true) called',
          );
        }

        String jsCode = "window.checkTheGpsPermission(true)";

        _webViewController.evaluateJavascript(source: jsCode);
      } else {
        _showEnableGPSDialog();
      }
    } else {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        bool isGPSPermissionEnabled =
            await Geolocator.isLocationServiceEnabled();

        if (widget.isLoggingEnabled) {
          log(
            '$TAG: checkForLocationAndGPSPermission isGPSPermissionEnabled : $isGPSPermissionEnabled',
          );
        }

        if (isGPSPermissionEnabled) {
          if (widget.isLoggingEnabled) {
            log(
              '$TAG: checkForLocationAndGPSPermission "window.checkTheGpsPermission(true) called',
            );
          }

          String jsCode = "window.checkTheGpsPermission(true)";

          _webViewController.evaluateJavascript(source: jsCode);
        } else {
          _showEnableGPSDialog();
        }
      } else {
        if (widget.isLoggingEnabled) {
          log(
            '$TAG: checkForLocationAndGPSPermission permissionState : $permission',
          );
        }

        _showAndroidPermissionDialog();
      }
    }
  }

  _showHealthConnectPermissionDeniedDialog() async {
    return showPermissionDialog(
      context,
      titleText: 'Permission Denied',
      descriptionText: 'Go to Health Connect App to allow app permission',
      positiveCTAText: "Open Health Connect",
      negativeCTAText: "Cancel",
      onPositiveButtonPress: () {
        Navigator.of(context).pop();
        _openHealthConnectSettings();
      },
      onNegativeButtonPress: () {
        Navigator.of(context).pop();
      },
    );
  }

  _showEnableGPSDialog() async {
    return showPermissionDialog(
      context,
      titleText: 'Permission required!',
      descriptionText: 'Please go to settings and turn on GPS',
      positiveCTAText: "Settings",
      negativeCTAText: "Cancel",
      onPositiveButtonPress: () {
        Navigator.of(context).pop();
        Geolocator.openLocationSettings();
      },
      onNegativeButtonPress: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showAndroidPermissionDialog() {
    showPermissionDialog(
      context,
      titleText: 'Permission required!',
      descriptionText: 'Please go to setting and turn on the permission',
      positiveCTAText: "Settings",
      negativeCTAText: "Cancel",
      onPositiveButtonPress: () {
        Navigator.of(context).pop();
        openAppSettings();
      },
      onNegativeButtonPress: () {
        Navigator.pop(context);
      },
    );
  }
}
