import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:visit_flutter_sdk/colored_safe_area_widget.dart';
import 'package:visit_flutter_sdk/visit_flutter_sdk.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:developer';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: UrlInputScreen(),
    );
  }
}

// First Screen: URL Input and Button to Navigate
class UrlInputScreen extends StatefulWidget {
  const UrlInputScreen({super.key});

  @override
  _UrlInputScreenState createState() => _UrlInputScreenState();
}

class _UrlInputScreenState extends State<UrlInputScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCL Tech App"),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: FirstPageWebview(
                initialUrl: 'https://angulardemo-nine.vercel.app/',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FirstPageWebview extends StatefulWidget {
  const FirstPageWebview({
    super.key,
    required this.initialUrl,
    this.isLoggingEnabled = false,
  });

  final String initialUrl;
  final bool isLoggingEnabled;

  @override
  _FirstPageWebviewState createState() => _FirstPageWebviewState();
}

class _FirstPageWebviewState extends State<FirstPageWebview> {
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

  Future<void> _openVisitSDK(String ssoLink) async {
    if (ssoLink.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VisitFlutterSdkScreen(ssoUrl: ssoLink),
        ),
      );
    } else {
      // Show a warning if the URL is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL'),
        ),
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

                        if (methodName == "OPEN_VISIT_APP") {
                          String? ssoLink = callbackResponse['ssoLink'];
                          _openVisitSDK(ssoLink!);
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
                androidOnGeolocationPermissionsShowPrompt:
                    (InAppWebViewController controller, String origin) async {
                  return GeolocationPermissionShowPromptResponse(
                      origin: origin, allow: true, retain: true);
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
}

// Second Screen: VisitFlutterSdk
class VisitFlutterSdkScreen extends StatelessWidget {
  final String ssoUrl;

  const VisitFlutterSdkScreen({super.key, required this.ssoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VisitFlutterSdk(
        ssoUrl: ssoUrl,
        isLoggingEnabled: true,
      ),
    );
  }
}
