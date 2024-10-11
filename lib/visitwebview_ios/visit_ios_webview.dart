import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef WebViewCreatedCallback = void Function(WebViewController controller);
typedef PageStartedCallback = void Function(String url);
typedef PageFinishedCallback = void Function(String url);
typedef ErrorCallback = void Function(WebResourceError error);

class VisitIosWebView extends StatefulWidget {
  const VisitIosWebView({
    Key? key,
    required this.initialUrl,
    this.isLoggingEnabled = false,
    this.onWebViewCreated,
    this.onPageStarted,
    this.onPageFinished,
    this.onError,
  }) : super(key: key);

  final String initialUrl;
  final bool isLoggingEnabled;
  final WebViewCreatedCallback? onWebViewCreated;
  final PageStartedCallback? onPageStarted;
  final PageFinishedCallback? onPageFinished;
  final ErrorCallback? onError;

  @override
  _VisitIosWebViewState createState() => _VisitIosWebViewState();
}

class _VisitIosWebViewState extends State<VisitIosWebView> {
  bool _isLoading = false;
  bool _showAppBarContent = false;
  late final WebViewController _controller;

  String TAG = "mytag";

  @override
  void initState() {
    super.initState();
    // Webview setup
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ReactNativeWebView',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Handle progress event
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onHttpError: (HttpResponseError error) {
            log('onHttpError -- $error');
          },
          onWebResourceError: (WebResourceError error) {
            log('onWebResourceError -- $error');
          },
          onUrlChange: (UrlChange url) {
            print('onUrlChange : --$url');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.endsWith('.pdf')) {
              _handlePDF(request.url);
              setState(() {
                _showAppBarContent = true;
              });
            } else {
              setState(() {
                _showAppBarContent = false;
              });
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false; // Prevent the default back action
    }
    return true; // Allow the default back action
  }

  void _handlePDF(String url) async {
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download PDF'),
        content: const Text('Do you want to download the PDF file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (shouldDownload == true) {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    }
  }

  // This method will handle JavaScript messages received from the WebView
  void _handleJavaScriptMessage(String message) {
    log('message ---${message}');

    String jsonResponse = message;

    // Decode JSON to Map
    Map<String, dynamic> callbackResponse = jsonDecode(jsonResponse);

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
      // Navigator.pop(context);
      SystemNavigator.pop();
    }
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
    log('$TAG: checkForLocationAndGPSPermission: called');

    LocationPermission permission = await Geolocator.checkPermission();

    log('$TAG: checkForLocationAndGPSPermission permissionState : $permission');

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      log('$TAG: checkForLocationAndGPSPermission permissionState : $permission');

      bool isGPSPermissionEnabled = await Geolocator.isLocationServiceEnabled();

      log('$TAG: checkForLocationAndGPSPermission isGPSPermissionEnabled : $isGPSPermissionEnabled');

      if (isGPSPermissionEnabled) {
        log('$TAG: checkForLocationAndGPSPermission "window.checkTheGpsPermission(true) called');

        String jsCode = "window.checkTheGpsPermission(true)";

        _controller.runJavaScript(jsCode);
      } else {
        _showEnableGPSDialog();
      }
    } else {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        bool isGPSPermissionEnabled =
            await Geolocator.isLocationServiceEnabled();

        log('$TAG: checkForLocationAndGPSPermission isGPSPermissionEnabled : $isGPSPermissionEnabled');

        if (isGPSPermissionEnabled) {
          log('$TAG: checkForLocationAndGPSPermission "window.checkTheGpsPermission(true) called');

          String jsCode = "window.checkTheGpsPermission(true)";

          _controller.runJavaScript(jsCode);
        } else {
          _showEnableGPSDialog();
        }
      } else {
        log('$TAG: checkForLocationAndGPSPermission permissionState : $permission');

        _showAndroidPermissionDialog();
      }
    }
  }

  _showEnableGPSDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap the button
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enable GPS'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Please enable GPS to continue using this feature.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Enable'),
              onPressed: () {
                // Open device location settings
                Geolocator.openLocationSettings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAndroidPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text('This app needs access to your location.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: _showAppBarContent
            ? AppBar(actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _controller.reload();
                  },
                ),
              ])
            : null,
        body: SafeArea(
          child: Stack(
            children: [
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : WebViewWidget(controller: _controller),
            ],
          ),
        ),
      ),
    );
  }
}
