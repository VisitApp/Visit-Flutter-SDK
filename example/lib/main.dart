import 'package:flutter/material.dart';
import 'package:visit_flutter_sdk/visit_flutter_sdk.dart';

void main() => runApp(const VisitFlutterSdkExampleApp());

class VisitFlutterSdkExampleApp extends StatelessWidget {
  const VisitFlutterSdkExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: UrlInputScreen());
  }
}

class UrlInputScreen extends StatefulWidget {
  const UrlInputScreen({super.key});

  @override
  State<UrlInputScreen> createState() => _UrlInputScreenState();
}

class _UrlInputScreenState extends State<UrlInputScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _openSdk() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an SSO URL.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitFlutterSdk(ssoUrl: url, isLoggingEnabled: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visit Flutter SDK Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'SSO URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openSdk,
              child: const Text('Open Visit SDK'),
            ),
          ],
        ),
      ),
    );
  }
}
