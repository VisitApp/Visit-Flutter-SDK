import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colored_safe_area_widget.dart';

class VisitIosWebView extends StatefulWidget {
  const VisitIosWebView({
    super.key,
    required this.initialUrl,
    this.isLoggingEnabled = false,
  });

  final String initialUrl;
  final bool isLoggingEnabled;

  @override
  _VisitIosWebViewState createState() => _VisitIosWebViewState();
}

class _VisitIosWebViewState extends State<VisitIosWebView> {
  late InAppWebViewController _webViewController;
  String TAG = "mytag";
  bool _isLoading = false;
  bool _isDownloading = false;

  final InAppWebViewGroupOptions settings = InAppWebViewGroupOptions(
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
  );

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
    return ColoredSafeArea(
      color: Colors.white,
      child: Stack(
        children: [
          WillPopScope(
            onWillPop: _onWillPop,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: InAppWebView(
                initialOptions: settings,
                initialUrlRequest: URLRequest(
                  url: Uri.parse(widget.initialUrl),
                ),
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
                          print("$TAG: callbackResponse: $callbackResponse");
                        }

                        String methodName = callbackResponse['name']!;

                        print("methodName @@@ $methodName");

                        if (methodName == "GET_LOCATION_PERMISSIONS") {
                          _checkForLocationAndGPSPermission();
                        } else if (methodName == "DOWNLOAD_PDF") {
                          final String? documentLink = callbackResponse['link']
                              ?.toString();
                          final String? authToken = callbackResponse['authToken']
                              ?.toString();

                          if (documentLink == null || documentLink.isEmpty) {
                            return;
                          }

                          _downloadFile(
                            link: documentLink,
                            authToken: authToken,
                          );
                        } else if (methodName == "CLOSE_VIEW") {
                          Navigator.pop(context);
                          // SystemNavigator.pop();
                        } else if (methodName == "OPEN_DAILER") {
                          int? phone = callbackResponse['number'];
                          _makePhoneCall(phone!);
                        }
                      } catch (e) {
                        print("$TAG: args: $e");
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
                androidOnGeolocationPermissionsShowPrompt: (
                  controller,
                  origin,
                ) async {
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

  Map<String, String> _buildHeaders(Uri uri, String? authToken) {
    final token = authToken?.trim();
    final host = uri.host.toLowerCase();
    if (token == null ||
        token.isEmpty ||
        host.contains('amazonaws.com')) {
      return const {};
    }

    return {'Authorization': token};
  }

  Future<void> _downloadFile({required String link, String? authToken}) async {
    if (_isDownloading) {
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      _showSnackBar('Invalid file link.');
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    HttpClient? client;
    IOSink? sink;
    final headers = _buildHeaders(uri, authToken);

    try {
      client = HttpClient();
      final request = await client.getUrl(uri);

      headers.forEach((name, value) {
        request.headers.add(name, value);
      });

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download failed with status code ${response.statusCode}.',
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/${_buildFileName(link, response.headers.contentType?.mimeType)}';
      final file = File(filePath);

      sink = file.openWrite();
      await sink.addStream(response);
      await sink.flush();
      await sink.close();
      sink = null;

      await _openShareSheet(filePath);
    } catch (error) {
      _showSnackBar('Failed to download file: $error');
    } finally {
      await sink?.close();
      client?.close(force: true);

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  String _buildFileName(String link, String? mimeType) {
    final uri = Uri.tryParse(link);
    final rawName = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : 'document';
    final sanitizedName = rawName.isEmpty ? 'document' : rawName;

    if (sanitizedName.contains('.')) {
      return sanitizedName;
    }

    final extension = _fileExtensionFromMimeType(mimeType);
    return '$sanitizedName$extension';
  }

  String _fileExtensionFromMimeType(String? mimeType) {
    switch (mimeType) {
      case 'application/pdf':
        return '.pdf';
      case 'image/png':
        return '.png';
      case 'image/jpeg':
        return '.jpg';
      case 'image/webp':
        return '.webp';
      case 'image/gif':
        return '.gif';
      default:
        return '';
    }
  }

  Future<void> _openShareSheet(String filePath) async {
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    await Share.shareXFiles([
      XFile(filePath),
    ], sharePositionOrigin: sharePositionOrigin);
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _checkForLocationAndGPSPermission() async {
    if (widget.isLoggingEnabled) {
      print('$TAG: checkForLocationAndGPSPermission: called');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    print('$TAG: checkForLocationAndGPSPermission permissionState : $permission');

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      if (widget.isLoggingEnabled) {
        print(
          '$TAG: checkForLocationAndGPSPermission permissionState : $permission',
        );
      }

      bool isGPSPermissionEnabled = await Geolocator.isLocationServiceEnabled();

      if (widget.isLoggingEnabled) {
        print(
          '$TAG: checkForLocationAndGPSPermission isGPSPermissionEnabled : $isGPSPermissionEnabled',
        );
      }

      if (isGPSPermissionEnabled) {
        if (widget.isLoggingEnabled) {
          print(
            '$TAG: checkForLocationAndGPSPermission "window.checkTheGpsPermission(true) called',
          );
        }

        String jsCode = "window.checkTheGpsPermission(true)";

        _webViewController.evaluateJavascript(source: jsCode);
      } else {
        _showEnableGPSDialog();
      }
    } else {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        bool isGPSPermissionEnabled =
            await Geolocator.isLocationServiceEnabled();

        if (widget.isLoggingEnabled) {
          print(
            '$TAG: checkForLocationAndGPSPermission isGPSPermissionEnabled : $isGPSPermissionEnabled',
          );
        }

        if (isGPSPermissionEnabled) {
          if (widget.isLoggingEnabled) {
            print(
              '$TAG: checkForLocationAndGPSPermission "window.checkTheGpsPermission(true) called',
            );
          }

          String jsCode = "window.checkTheGpsPermission(true)";

          _webViewController.evaluateJavascript(source: jsCode);
        } else {
          _showEnableGPSDialog();
        }
      } else {
        if (widget.isLoggingEnabled) {
          print(
            '$TAG: checkForLocationAndGPSPermission permissionState : $permission',
          );
        }

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
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Please enable GPS to continue using this feature.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Enable'),
              onPressed: () {
                // Open device location settings
                Geolocator.openLocationSettings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
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
}
