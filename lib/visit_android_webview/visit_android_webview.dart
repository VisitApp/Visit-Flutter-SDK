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

  _showEnableGPSDialog() async {
    return showPermissionDialog(
      context,
      'Please go to settings and turn on GPS',
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
      'Please go to setting and turn on the permission',
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
