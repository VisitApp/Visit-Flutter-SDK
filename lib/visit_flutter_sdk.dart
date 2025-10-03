import 'dart:io';

import 'package:flutter/material.dart';
import 'package:visit_flutter_sdk/visit_android_webview/visit_android_webview.dart';
import 'package:visit_flutter_sdk/visitwebview_ios/visit_ios_webview.dart';

class VisitFlutterSdk extends StatelessWidget {
  final String ssoUrl;
  final bool isLoggingEnabled;

  // Constructor to accept the URL
  const VisitFlutterSdk(
      {super.key, required this.ssoUrl, this.isLoggingEnabled = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Platform.isIOS
            ? VisitIosWebView(
                initialUrl: ssoUrl, isLoggingEnabled: isLoggingEnabled)
            : VisitAndroidWebView(
                initialUrl: ssoUrl, isLoggingEnabled: isLoggingEnabled),
      ),
    );
  }
}
