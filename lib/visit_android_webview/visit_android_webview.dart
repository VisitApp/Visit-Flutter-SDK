import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'dart:io';
import 'package:open_filex/open_filex.dart';

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
                          downloadAndOpenPdf(context, pdfLink);
                        } else if (methodName == "OPEN_LINK") {
                          String link = callbackResponse['link']!;
                          _openLink(link);
                        } else if (methodName == "CLOSE_VIEW") {
                          Navigator.pop(context);
                          // SystemNavigator.pop();
                        } else if (methodName == "OPEN_DAILER") {
                          int? phone = callbackResponse['number'];
                          _makePhoneCall(phone!);
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
            const Center(
              child: Align(
                alignment: Alignment(0.0, 0.7),
                // Align at 0.8 part of the screen height
                child: CircularProgressIndicator(color: Color(0xFFEC6625)),
              ),
            ),
        ],
      ),
    );
  }

  void _openLink(String link) async {
    try {
      if (await canLaunchUrl(Uri.parse(link))) {
        await launchUrl(Uri.parse(link));
      } else {
        throw 'Could not launch $link';
      }
    } catch (e) {}
  }

  /// Downloads a PDF (or any file) to the app's temp directory without plugins.
  /// Returns the absolute file path on success.
  ///
  /// [onProgress] is called with (receivedBytes, totalBytes). totalBytes can be -1 if unknown.
  // Existing download function (from your code)
  Future<String> downloadPdf({
    required String url,
    void Function(int received, int total)? onProgress,
  }) async {
    final uri = Uri.parse(url);
    final dir = Directory.systemTemp.createTempSync('pdf_dl_');
    final file = File('${dir.path}/${uri.pathSegments.last}');
    final client = HttpClient();

    final request = await client.getUrl(uri);
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Failed to download PDF: ${response.statusCode}');
    }

    final total = response.contentLength;
    final sink = file.openWrite();
    int received = 0;

    await for (final chunk in response) {
      received += chunk.length;
      sink.add(chunk);
      if (onProgress != null) onProgress(received, total);
    }

    await sink.close();
    client.close();

    return file.path;
  }

  // Function with progress dialog
  Future<void> downloadAndOpenPdf(BuildContext context, String url) async {
    double progress = 0.0;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Downloading PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Text('${(progress * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    );

    try {
      final path = await downloadPdf(
        url: url,
        onProgress: (received, total) {
          if (total > 0) {
            progress = received / total;
          } else {
            progress = 0.0;
          }
          // Update the dialog UI
          (context as Element).markNeedsBuild();
        },
      );

      // Close the dialog once done
      Navigator.of(context, rootNavigator: true).pop();

      // Open PDF in external viewer
      final result = await OpenFilex.open(path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: ${result.message}')),
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  void _checkForLocationAndGPSPermission() async {
    if (widget.isLoggingEnabled) {
      log('$TAG: _checkForLocationAndGPSPermission: called');
    }

    // 1) LOCATION PERMISSION (sequential first step)
    // Use permission_handler to avoid overlapping dialogs with Geolocator
    var phStatus = await Permission.locationWhenInUse.status;
    if (widget.isLoggingEnabled) {
      log('$TAG: permission_handler status (before): $phStatus');
    }

    if (!phStatus.isGranted && !phStatus.isPermanentlyDenied) {
      phStatus = await Permission.locationWhenInUse.request();
      if (widget.isLoggingEnabled) {
        log('$TAG: permission_handler status (after request): $phStatus');
      }
    }

    if (phStatus.isPermanentlyDenied) {
      if (widget.isLoggingEnabled) {
        log('$TAG: location permission permanently denied');
      }
      _showAndroidPermissionDialog();
      return;
    }

    if (!phStatus.isGranted) {
      if (widget.isLoggingEnabled) {
        log('$TAG: location permission denied');
      }
      _showAndroidPermissionDialog();
      return;
    }

    // Reflect into Geolocator's model for downstream checks/logs
    final geolocPerm = await Geolocator.checkPermission();
    if (widget.isLoggingEnabled) {
      log('$TAG: Geolocator.checkPermission -> $geolocPerm');
    }

    // 2) GPS / LOCATION SERVICE (sequential second step)
    final loc = Location();
    bool serviceEnabled = await loc.serviceEnabled();
    if (widget.isLoggingEnabled) {
      log('$TAG: Location.serviceEnabled (before): $serviceEnabled');
    }

    if (!serviceEnabled) {
      try {
        // On Android, this shows the in-app Google Play Services resolution dialog
        serviceEnabled = await loc.requestService();
        if (widget.isLoggingEnabled) {
          log('$TAG: Location.requestService -> $serviceEnabled');
        }
      } catch (e, st) {
        log('$TAG: requestService error: $e');
        log('$TAG: stack: $st');
        serviceEnabled = false;
      }
    }

    if (!serviceEnabled) {
      if (widget.isLoggingEnabled) {
        log('$TAG: location services NOT enabled after prompt');
      }
      _showEnableGPSDialog();
      return;
    }

    // 3) SUCCESS → notify WebView JS
    if (widget.isLoggingEnabled) {
      log('$TAG: window.checkTheGpsPermission(true) called');
    }
    _webViewController.evaluateJavascript(
      source: 'window.checkTheGpsPermission(true)',
    );
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
