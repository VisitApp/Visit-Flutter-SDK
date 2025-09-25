import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
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
    return ColoredSafeArea(
      color: Colors.white,
      child: Stack(
        children: [
          WillPopScope(
            onWillPop: _onWillPop,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: InAppWebView(
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    javaScriptEnabled: true,
                    allowFileAccessFromFileURLs: true,
                    transparentBackground: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  android: AndroidInAppWebViewOptions(
                    useWideViewPort: true,
                    builtInZoomControls: true,
                    geolocationEnabled: true,
                    allowFileAccess: true,
                  ),
                  ios: IOSInAppWebViewOptions(
                    allowsInlineMediaPlayback: true,
                  ),
                ),
                initialUrlRequest:
                    URLRequest(url: Uri.parse(widget.initialUrl)),
                onWebViewCreated: (InAppWebViewController controller) {
                  _webViewController = controller;

                  _webViewController.addJavaScriptHandler(
                    handlerName: 'FlutterWebView',
                    callback: (List<dynamic> args) {
                      // Get message from JavaScript code, which could be the result of some operation.
                      try {
                        String jsonString = args[0];

                        Map<String, dynamic> callbackResponse =
                            jsonDecode(jsonString);

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
                        } else if (methodName ==
                            "GET_CAMERA_AND_MICROPHONE_PERMISSIONS") {
                          _checkAndRequestCameraAndMicPermissions();
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
                onLoadStop: (controller, url) async {
                  setState(() {
                    // _isLoading = false;
                  });

                  if (!mounted) return;
                  if (widget.isLoggingEnabled) {
                    // Inject diagnostics to help debug getUserMedia
                    const js = r'''
                      (async () => {
                        const tag = '[gUM-debug]';
                        try {
                          console.log(tag, 'location', location.href);
                          if (navigator.permissions && navigator.permissions.query) {
                            try {
                              const cam = await navigator.permissions.query({ name: 'camera' }).catch(()=>({state:'unknown'}));
                              const mic = await navigator.permissions.query({ name: 'microphone' }).catch(()=>({state:'unknown'}));
                              console.log(tag, 'permissions camera=', cam.state, 'microphone=', mic.state);
                            } catch (e) { console.warn(tag, 'permissions query error', e && e.message); }
                          }
                          if (navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) {
                            const devices = await navigator.mediaDevices.enumerateDevices();
                            console.log(tag, 'devices', devices.map(d => `${d.kind}:${d.label||'(label hidden)'}`));
                          } else {
                            console.warn(tag, 'navigator.mediaDevices.enumerateDevices not available');
                          }
                        } catch (e) {
                          console.error(tag, 'probe failed', e && (e.name+': '+e.message));
                        }
                      })();
                    ''';
                    await _webViewController.evaluateJavascript(source: js);
                  }
                },
                onConsoleMessage: (controller, consoleMessage) {
                  log("$TAG: [CONSOLE][${consoleMessage.messageLevel}] ${consoleMessage.message}");
                },
                androidOnGeolocationPermissionsShowPrompt:
                    (InAppWebViewController controller, String origin) async {
                  return GeolocationPermissionShowPromptResponse(
                      origin: origin, allow: true, retain: true);
                },
                androidOnPermissionRequest:
                    (controller, origin, resources) async {
                  // Log origin and resources requested by the page
                  if (widget.isLoggingEnabled) {
                    log("$TAG: androidOnPermissionRequest origin=$origin resources=$resources");
                  }

                  // 1) Check current runtime permission status
                  PermissionStatus camStatus = await Permission.camera.status;
                  PermissionStatus micStatus =
                      await Permission.microphone.status;

                  if (widget.isLoggingEnabled) {
                    log("$TAG: runtime status BEFORE request -> camera=${camStatus}, mic=${micStatus}");
                  }

                  bool granted = camStatus.isGranted && micStatus.isGranted;

                  // 2) Request runtime permissions if needed
                  if (!granted) {
                    try {
                      final results = await [
                        Permission.camera,
                        Permission.microphone
                      ].request();

                      if (widget.isLoggingEnabled) {
                        log("$TAG: runtime request results -> ${results.map((k, v) => MapEntry(k.value, v)).toString()}");
                      }

                      camStatus = results[Permission.camera] ?? camStatus;
                      micStatus = results[Permission.microphone] ?? micStatus;
                    } catch (e) {
                      if (widget.isLoggingEnabled) {
                        log("$TAG: runtime permission request threw: $e");
                      }
                    }
                    if (widget.isLoggingEnabled) {
                      log("$TAG: runtime status AFTER request -> camera=${camStatus}, mic=${micStatus}");
                    }

                    granted = camStatus.isGranted && micStatus.isGranted;
                  }

                  // 3) Decide WebView grant/deny and log the decision
                  if (!granted) {
                    if (widget.isLoggingEnabled) {
                      log("$TAG: WebView permission DECISION = DENY (runtime not fully granted)");
                    }

                    return PermissionRequestResponse(
                      resources: resources,
                      action: PermissionRequestResponseAction.DENY,
                    );
                  }

                  // Only grant what the page asked for; also log exactly what we're granting
                  final toGrant =
                      resources.map((r) => r).toList(growable: false);

                  if (widget.isLoggingEnabled) {
                    log("$TAG: WebView permission DECISION = GRANT -> $toGrant");
                  }

                  return PermissionRequestResponse(
                    resources: toGrant,
                    action: PermissionRequestResponseAction.GRANT,
                  );
                },
              ),
            ),
          ),
          if (_isLoading)
            const Center(
                child: Align(
              alignment: Alignment(0.0, 0.7),
              // Align at 0.8 part of the screen height
              child: CircularProgressIndicator(
                color: Color(0xFFEC6625),
              ),
            )),
        ],
      ),
    );
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
        log('$TAG: checkForLocationAndGPSPermission permissionState : $permission');
      }

      bool isGPSPermissionEnabled = await Geolocator.isLocationServiceEnabled();

      if (widget.isLoggingEnabled) {
        log('$TAG: checkForLocationAndGPSPermission isGPSPermissionEnabled : $isGPSPermissionEnabled');
      }

      if (isGPSPermissionEnabled) {
        if (widget.isLoggingEnabled) {
          log('$TAG: checkForLocationAndGPSPermission "window.checkTheGpsPermission(true) called');
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
          log('$TAG: checkForLocationAndGPSPermission isGPSPermissionEnabled : $isGPSPermissionEnabled');
        }

        if (isGPSPermissionEnabled) {
          if (widget.isLoggingEnabled) {
            log('$TAG: checkForLocationAndGPSPermission "window.checkTheGpsPermission(true) called');
          }

          String jsCode = "window.checkTheGpsPermission(true)";

          _webViewController.evaluateJavascript(source: jsCode);
        } else {
          _showEnableGPSDialog();
        }
      } else {
        if (widget.isLoggingEnabled) {
          log('$TAG: checkForLocationAndGPSPermission permissionState : $permission');
        }

        _showAndroidPermissionDialog();
      }
    }
  }

  Future<void> _checkAndRequestCameraAndMicPermissions() async {
    if (widget.isLoggingEnabled) {
      log('$TAG: _checkAndRequestCameraAndMicPermissions: called');
    }

    // Current status
    PermissionStatus camStatus = await Permission.camera.status;
    PermissionStatus micStatus = await Permission.microphone.status;

    bool granted = camStatus.isGranted && micStatus.isGranted;

    // Request if not both granted
    if (!granted) {
      final results =
          await [Permission.camera, Permission.microphone].request();
      camStatus = results[Permission.camera] ?? camStatus;
      micStatus = results[Permission.microphone] ?? micStatus;
      granted = camStatus.isGranted && micStatus.isGranted;
    }

    // Notify the web page via JS (mirrors your GPS callback style)
    final js =
        'window.checkCameraAndMicPermission && window.checkCameraAndMicPermission(' +
            (granted ? 'true' : 'false') +
            ')';

    if (widget.isLoggingEnabled) {
      log('$TAG: js: '+js);
    }
    _webViewController.evaluateJavascript(source: js);

    // If permanently denied, guide user to app settings (Android)
    if (!granted &&
        (camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied)) {
      _showAndroidPermissionDialog();
    }
  }

  _showEnableGPSDialog() async {
    return showPermissionDialog(
        context, 'Please go to settings and turn on GPS',
        onPositiveButtonPress: () {
      Navigator.of(context).pop();
      Geolocator.openLocationSettings();
    }, onNegativeButtonPress: () {
      Navigator.of(context).pop();
    });
  }

  void _showAndroidPermissionDialog() {
    showPermissionDialog(
        context, 'Please go to setting and turn on the permission',
        onPositiveButtonPress: () {
      Navigator.of(context).pop();
      openAppSettings();
    }, onNegativeButtonPress: () {
      Navigator.pop(context);
    });
  }
}
