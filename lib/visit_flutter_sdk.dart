// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'package:flutter/material.dart';
import 'package:visit_flutter_sdk/visitwebview/visitwebview.dart';

import 'package:flutter/material.dart';

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
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VisitWebView(
                  initialUrl: ssoUrl,
                ),
              ),
            );
          },
          child: const Text('Open Settings'),
        ),
      ),
    );
  }
}
