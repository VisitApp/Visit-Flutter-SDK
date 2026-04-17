import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
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

// First Screen: URL Input and Button to Navigate
class UrlInputScreen extends StatefulWidget {
  const UrlInputScreen({super.key});

  @override
  _UrlInputScreenState createState() => _UrlInputScreenState();
}

class _UrlInputScreenState extends State<UrlInputScreen> {
  final TextEditingController _urlController = TextEditingController(text: "https://pnb-metlife.getvisitapp.net/sso?userParams=WahGNbeP04HPcnbAVg7uKoy8xNvmd7vWUjL7TQONQYVqK54BBfhHvuNucUCrJA9AubtgyjJoUXIzn0OjZGlA4RUZ9EE4eksMKqQOHn5dTPJCNzWAEfY2af5IZaQwdcgzSu32RHVSpNUasTxh81SfKty3U6lQRF5QEhXTFz8VLRiJ83crV1DYd71dtRJr7ZjbkEdXxTJ4EBRLgWgIAfZXrm_EIHmN5lFfhUf6aBFrwlug3MGyHvF0y_ptlg6bX0fAPKVd1UklFQYG-L316-r5hgarQ-3rvpQ9zMrgUd_KbveAaNroAMTAhHHLXPMmRjNYDiLZMQHhwKJHYrYr2xg_IOB-VOHbEoIwzLF3wh33AW7Q9BjyJp3GGMQBqdfxSMGT85w7zo7skJvB_Bsc6RK-vDHpbTfmlt6ipU98mKEOssG-UV5tlszJ9-Orwy3OklvrvlPeoGZmriqHGqMTuf3kKQ5Qurz0mmcF3ERxzD5YpbvdLSrqIjsINmafJD9f1QAn6J4sGC2iLNtk4toAYK11YwsSeEhUQiuHoGYJO1x5uBn3kpqntyJrngQYeVXK99X9oU_JpXk1ESfDVQaGkAXKbbrswxm-2ibpcP4DnsUNO3SWCrPqb7oyfRFMykkK-oWAJVRiRmlEjuJonwX5PY6_Z8_c_HsAPchSeTI6aPPbdQyj5gvwakWZ_4SJe7faq4SbFRXikXycQMUodK8Q99FYWdHo7UQBX_IVWCLZNsEFFQAEpPqcbd7ueFH0hLutoHGXQyS2CdGHx6qeBIkWdnou761xdcgGZu5COteYJPsNWs04hq76nl8kX5nboOjVTAK-&clientId=pnb-ml-9xb");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter SSO URL")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
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
                        builder: (context) =>
                            VisitFlutterSdkScreen(ssoUrl: url),
                      ),
                    );
                  } else {
                    // Show a warning if the URL is empty
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a URL')),
                    );
                  }
                },
                child: const Text("Open"),
              ),
            ],
          ),
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
      body: VisitFlutterSdk(ssoUrl: ssoUrl, isLoggingEnabled: true),
    );
  }
}
