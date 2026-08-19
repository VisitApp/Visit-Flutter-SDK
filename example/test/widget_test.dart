import 'package:flutter_test/flutter_test.dart';
import 'package:visit_flutter_sdk_example/main.dart';

void main() {
  test('configures the HCL demo URL', () {
    const webview = FirstPageWebview(
      initialUrl: 'https://angulardemo-nine.vercel.app/',
    );

    expect(webview.initialUrl, 'https://angulardemo-nine.vercel.app/');
  });
}
