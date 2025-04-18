import 'package:flutter/material.dart';
import 'package:visit_flutter_sdk/visit_flutter_sdk.dart';

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
        title: const Text("Enter SSO URL"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: "Enter SSO URL",
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Get the URL from the TextField and navigate to the next page
                String url = _urlController.text;
                if (url.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VisitFlutterSdkScreen(ssoUrl: url),
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
              },
              child: const Text("Open"),
            ),
          ],
        ),
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
