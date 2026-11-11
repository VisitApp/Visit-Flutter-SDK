import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../alert_dialog.dart';
import '../colored_safe_area_widget.dart';
import '../src/health_call_guard.dart';
import '../visit_flutter_sdk_platform_interface.dart';

class VisitAndroidWebView extends StatefulWidget {
  const VisitAndroidWebView({
    super.key,
    required this.initialUrl,
    this.isLoggingEnabled = false,
  });

  final String initialUrl;
  final bool isLoggingEnabled;

  @override
  _VisitAndroidWebViewState createState() => _VisitAndroidWebViewState();
}

class _VisitAndroidWebViewState extends State<VisitAndroidWebView> {
  static const MethodChannel platform = MethodChannel('visit_flutter_sdk');
  final _healthCalls = HealthCallGuard();
  bool _healthDialogVisible = false;
  late InAppWebViewController _webViewController;
  String TAG = "mytag";
  bool _isLoading = false;
  bool _isDownloading = false;

  @override
  void dispose() {
    _healthCalls.dispose();
    super.dispose();
  }

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
    final options = InAppWebViewGroupOptions(
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

    return ColoredSafeArea(
      color: Colors.white,
      child: Stack(
        children: [
          WillPopScope(
            onWillPop: _onWillPop,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: InAppWebView(
                initialOptions: options,
                initialUrlRequest: URLRequest(
                  url: WebUri(widget.initialUrl),
                ),
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
                          print("$TAG: callbackResponse: $callbackResponse");
                        }

                        String methodName = callbackResponse['name']!;

                        if (methodName == "GET_LOCATION_PERMISSIONS") {
                          _checkForLocationAndGPSPermission();
                        } else if (methodName == "DOWNLOAD_PDF") {
                          final String? documentLink =
                              callbackResponse['link']?.toString();
                          final String? authToken =
                              callbackResponse['authToken']?.toString();

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
                        } else if (methodName == "GET_HEALTH_CONNECT_STATUS") {
                          _healthCalls.run('status', _getHealthConnectStatus);
                        } else if (methodName == "CONNECT_TO_GOOGLE_FIT") {
                          _healthCalls.run(
                            'permission', _askForHealthConnectPermission,
                          );
                        } else if (methodName == "GET_CALORIE_BURNED") {
                          _healthCalls.run('calories', _getTodayCaloriesBurned);
                        } else if (methodName == "UPDATE_PLATFORM") {
                          _healthCalls.run('platform', _updatePlatform);
                        } else if (methodName == "UPDATE_API_BASE_URL") {
                          _updateApiBaseUrl(callbackResponse);
                        } else if (methodName == "GET_DATA_TO_GENERATE_GRAPH") {
                          final timestamp = int.tryParse(
                            callbackResponse['timestamp'].toString(),
                          );
                          final key = (
                            'graph', callbackResponse['type'],
                            callbackResponse['frequency'], timestamp,
                          );
                          _healthCalls.run(key, (document) {
                            return _getDataToGenerateDetailedGraph(
                              callbackResponse, timestamp, document,
                            );
                          });
                        }
                      } catch (e) {
                        print("$TAG: args: $e");
                      }
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  _healthCalls.newDocument();
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
              child: CircularProgressIndicator(
                color: Color(0xFFEC6625),
              ),
            )),
        ],
      ),
    );
  }

  bool _currentHealthDocument(int document) =>
      mounted && _healthCalls.isCurrent(document);

  Future<void> _evaluateHealthJs(String source, int document) async {
    if (_currentHealthDocument(document)) {
      await _webViewController.evaluateJavascript(source: source);
    }
  }

  Future<void> _getHealthConnectStatus(int document) async {
    try {
      final healthConnectStatus = await platform.invokeMethod<String>(
        'getHealthConnectStatus',
      );
      if (!_currentHealthDocument(document)) return;

      if (healthConnectStatus == 'CONNECTED') {
        await _getDailyFitnessData(document);
      } else {
        await _showHealthStatus(healthConnectStatus, document);
      }
    } on PlatformException catch (e) {
      await _handleHealthError(e, document);
    }
  }

  Future<void> _showHealthStatus(String? status, int document) async {
    if (status == 'NOT_SUPPORTED') {
      await _evaluateHealthJs('window.healthConnectNotSupported()', document);
    } else if (status == 'NOT_INSTALLED') {
      await _evaluateHealthJs('window.healthConnectNotInstall()', document);
      await _evaluateHealthJs(
        'window.updateFitnessPermissions(false,0,0)', document,
      );
    } else if (status == 'INSTALLED') {
      await _evaluateHealthJs('window.healthConnectAvailable()', document);
      await _evaluateHealthJs(
        'window.updateFitnessPermissions(false,0,0)', document,
      );
    }
  }

  Future<void> _getDailyFitnessData(int document) async {
    try {
      final dailyFitnessData = await platform.invokeMethod<String>(
        'requestDailyFitnessData',
      );
      if (dailyFitnessData != null) {
        await _evaluateHealthJs(dailyFitnessData, document);
      }
    } on PlatformException catch (e) {
      await _handleHealthError(e, document);
    }
  }

  Future<void> _getTodayCaloriesBurned(int document) async {
    try {
      final kcal = await platform.invokeMethod<int>('getTodayCaloriesBurned');
      if (kcal == null) return;
      await _evaluateHealthJs(
        "if (typeof window.updateCalorieBurned === 'function') "
        'window.updateCalorieBurned($kcal);',
        document,
      );
    } on PlatformException catch (error) {
      if (widget.isLoggingEnabled) {
        debugPrint('Health Connect calorie read failed: ${error.code}');
      }
    }
  }

  Future<void> _askForHealthConnectPermission(int document) async {
    try {
      final isPermissionGranted = await platform.invokeMethod<String>(
        'askForFitnessPermission',
      );
      if (!_currentHealthDocument(document)) return;

      if (isPermissionGranted == "GRANTED") {
        await _healthCalls.run('status', _getHealthConnectStatus);
      } else if (isPermissionGranted == "CANCELLED") {
        await _showHealthConnectPermissionDeniedDialog(document);
      }
    } on PlatformException catch (e) {
      await _handleHealthError(e, document);
    }
  }

  Future<void> _handleHealthError(PlatformException error, int document) async {
    if (!_currentHealthDocument(document)) return;
    if (error.code == 'permission_denied') {
      await _showHealthConnectPermissionDeniedDialog(document);
    } else if (error.code == 'health_connect_unavailable') {
      await _showHealthStatus(error.details?.toString(), document);
    } else if (widget.isLoggingEnabled) {
      debugPrint('Health Connect: ${error.code}');
    }
  }

  Future<void> _openHealthConnectSettings() async {
    try {
      await platform.invokeMethod<void>('openHealthConnectApp');
    } on PlatformException catch (e) {
      if (widget.isLoggingEnabled) {
        debugPrint("$TAG: Failed to open Health Connect: ${e.code}");
      }
    }
  }

  Future<void> _updatePlatform(int document) async {
    await _evaluateHealthJs('window.setSdkPlatform("ANDROID")', document);
  }

  Future<void> _updateApiBaseUrl(Map<String, dynamic> callbackResponse) async {
    try {
      await platform.invokeMethod<String>('updateApiBaseUrl', {
        'apiBaseUrl': callbackResponse['apiBaseUrl'],
        'authtoken': callbackResponse['authtoken'],
        'googleFitLastSync': int.tryParse(
          callbackResponse['googleFitLastSync'].toString(),
        ),
        'gfHourlyLastSync': int.tryParse(
          callbackResponse['gfHourlyLastSync'].toString(),
        ),
      });
    } on PlatformException catch (e) {
      if (widget.isLoggingEnabled) {
        debugPrint("$TAG: Failed to configure Health Connect: ${e.code}");
      }
    }
  }

  Future<void> _getDataToGenerateDetailedGraph(
    Map<String, dynamic> callbackResponse,
    int? timestamp,
    int document,
  ) async {
    try {
      final graphData = await platform.invokeMethod<String>(
        'requestActivityDataFromHealthConnect',
        {
          'type': callbackResponse['type'],
          'frequency': callbackResponse['frequency'],
          'timestamp': timestamp,
        },
      );
      if (graphData != null) {
        await _evaluateHealthJs("window.$graphData", document);
      }
    } on PlatformException catch (e) {
      await _handleHealthError(e, document);
    }
  }

  Map<String, String> _buildHeaders(Uri uri, String? authToken) {
    final token = authToken?.trim();
    final host = uri.host.toLowerCase();
    if (token == null || token.isEmpty || host.contains('amazonaws.com')) {
      return const {};
    }

    return {'Authorization': token};
  }

  Future<void> _downloadFile({required String link, String? authToken}) async {
    print("_downloadFile() called");

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

      final mimeType = response.headers.contentType?.mimeType;
      final directory = await Directory.systemTemp.createTemp(
        'visit_flutter_sdk_',
      );
      final filePath = '${directory.path}/${_buildFileName(link, mimeType)}';
      final file = File(filePath);

      sink = file.openWrite();
      await sink.addStream(response);
      await sink.flush();
      await sink.close();
      sink = null;

      print("file downloaded successfully");

      await _openShareSheet(filePath, mimeType: mimeType);

      print("file downloaded successfully");
    } catch (error) {
      _showSnackBar('Failed to download file: $error');
      print("error occured: $error");
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

  Future<void> _openShareSheet(String filePath, {String? mimeType}) async {
    await VisitFlutterSdkPlatform.instance.shareFile(
      filePath,
      mimeType: mimeType,
    );
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

    print(
        '$TAG: checkForLocationAndGPSPermission permissionState : $permission');

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

  Future<void> _showHealthConnectPermissionDeniedDialog(int document) async {
    if (!_currentHealthDocument(document) || _healthDialogVisible) return;
    _healthDialogVisible = true;
    try {
      await _evaluateHealthJs(
        'window.updateFitnessPermissions(false,0,0)', document,
      );
      if (!mounted || !_healthCalls.isCurrent(document)) return;
      await showPermissionDialog(
        context,
        titleText: 'Permission Denied',
        descriptionText: 'Go to Health Connect App to allow app permission',
        positiveCTAText: "Open Health Connect",
        negativeCTAText: "Cancel",
        onPositiveButtonPress: () {
          Navigator.of(context).pop();
          _openHealthConnectSettings();
        },
        onNegativeButtonPress: () {
          Navigator.of(context).pop();
        },
      );
    } finally {
      _healthDialogVisible = false;
    }
  }

  _showEnableGPSDialog() async {
    return showPermissionDialog(
      context,
      titleText: 'Permission required!',
      descriptionText: 'Please go to settings and turn on GPS',
      positiveCTAText: "Settings",
      negativeCTAText: "Cancel",
      onPositiveButtonPress: () {
        Navigator.of(context).pop();
        Geolocator.openLocationSettings();
      },
      onNegativeButtonPress: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showAndroidPermissionDialog() {
    showPermissionDialog(
      context,
      titleText: 'Permission required!',
      descriptionText: 'Please go to setting and turn on the permission',
      positiveCTAText: "Settings",
      negativeCTAText: "Cancel",
      onPositiveButtonPress: () {
        Navigator.of(context).pop();
        openAppSettings();
      },
      onNegativeButtonPress: () {
        Navigator.pop(context);
      },
    );
  }
}
