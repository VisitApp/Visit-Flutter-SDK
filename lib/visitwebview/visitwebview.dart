import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

typedef WebViewCreatedCallback = void Function(WebViewController controller);
typedef PageStartedCallback = void Function(String url);
typedef PageFinishedCallback = void Function(String url);
typedef ErrorCallback = void Function(WebResourceError error);

class VisitWebView extends StatefulWidget {
  const VisitWebView({
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
  _VisitWebViewState createState() => _VisitWebViewState();
}

class _VisitWebViewState extends State<VisitWebView> {
  bool _isLoading = false;
  bool _showAppBarContent = false;
  String _permissionStatus = 'Unknown';
  late final WebViewController _controller;
  String _locationMessage = "";

  @override
  void initState() {
    super.initState();
    // Webview setup
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterWebView',
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
    if (message == 'GET_LOCATION_PERMISSIONS') {
      _checkPermissionAndRun();
    }
  }

  Future<void> _checkPermissionAndRun() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied; handle accordingly
        setState(() {
          _locationMessage = 'Location permissions are denied';
        });
        return _showPermissionDialog();
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied; handle accordingly
      setState(() {
        _locationMessage = 'Location permissions are permanently denied';
      });
      return _showPermissionDialog();
    }
    // If permission is granted, run your specific code here
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _locationMessage =
          'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
    });
    return _sendLocationToWebView();
  }

  Future<void> _sendLocationToWebView() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String jsCode = '''
        window.checkTheGpsPermission(true);
        ''';
      _controller.runJavaScript(jsCode);
    } catch (e) {
      log('Error getting location: $e');
    }
  }

  void _showPermissionDialog() {
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
