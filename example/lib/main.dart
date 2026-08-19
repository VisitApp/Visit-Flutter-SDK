import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:visit_flutter_sdk/colored_safe_area_widget.dart';
import 'package:visit_flutter_sdk/visit_flutter_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: UrlInputScreen());
  }
}

class UrlInputScreen extends StatelessWidget {
  const UrlInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HCL Tech App')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: FirstPageWebview(
          initialUrl: 'https://angulardemo-nine.vercel.app/',
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
  State<FirstPageWebview> createState() => _FirstPageWebviewState();
}

class _FirstPageWebviewState extends State<FirstPageWebview> {
  InAppWebViewController? _webViewController;

  Future<bool> _onWillPop() async {
    final controller = _webViewController;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    return true;
  }

  void _openVisitSdk(String ssoLink) {
    if (ssoLink.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a URL')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisitFlutterSdkScreen(ssoUrl: ssoLink),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      allowFileAccessFromFileURLs: true,
      transparentBackground: true,
      useWideViewPort: true,
      builtInZoomControls: true,
      geolocationEnabled: true,
      allowFileAccess: true,
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: false,
    );

    return ColoredSafeArea(
      color: Colors.white,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: InAppWebView(
            initialSettings: settings,
            initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              controller.addJavaScriptHandler(
                handlerName: 'FlutterWebView',
                callback: (args) {
                  try {
                    if (args.isEmpty || args.first is! String) {
                      return;
                    }

                    final callbackResponse =
                        jsonDecode(args.first as String)
                            as Map<String, dynamic>;
                    if (widget.isLoggingEnabled) {
                      log('HCL callback: $callbackResponse');
                    }

                    if (callbackResponse['name'] == 'OPEN_VISIT_APP') {
                      _openVisitSdk(
                        callbackResponse['ssoLink'] as String? ?? '',
                      );
                    }
                  } catch (error, stackTrace) {
                    log(
                      'Unable to handle HCL callback',
                      error: error,
                      stackTrace: stackTrace,
                    );
                  }
                },
              );
            },
            onGeolocationPermissionsShowPrompt: (controller, origin) async {
              return GeolocationPermissionShowPromptResponse(
                origin: origin,
                allow: true,
                retain: true,
              );
            },
          ),
        ),
      ),
    );
  }
}

class VisitFlutterSdkScreen extends StatelessWidget {
  const VisitFlutterSdkScreen({super.key, required this.ssoUrl});

  final String ssoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VisitFlutterSdk(ssoUrl: ssoUrl, isLoggingEnabled: true),
    );
  }
}
