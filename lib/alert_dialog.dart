import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

void showPermissionDialog(
  BuildContext context, {
  required String titleText,
  required String descriptionText,
  required String positiveCTAText,
  required String negativeCTAText,
  required VoidCallback onPositiveButtonPress,
  required VoidCallback onNegativeButtonPress,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.only(bottom: 2),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/images/disclaimer_icon.svg',
                package: 'visit_flutter_sdk',
                width: 27,
                height: 27,
                placeholderBuilder: (context) =>
                    const CircularProgressIndicator(),
              ),
              const SizedBox(width: 10),
              Text(
                titleText,
                style: TextStyle(
                  fontFamily: 'Mulish',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  fontStyle: FontStyle.normal,
                  color: Color(0xFF17181A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            descriptionText,
            style: const TextStyle(
              fontFamily: 'Mulish',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              fontStyle: FontStyle.normal,
              color: Color(0xFF424242),
            ),
          ),
        ],
      ),
      actions: [
        const SizedBox(height: 24),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: const Color(0xFFEC6625),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    onPositiveButtonPress();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 17,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      positiveCTAText,
                      style: TextStyle(
                        fontFamily: 'Mulish',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontStyle: FontStyle.normal,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => onNegativeButtonPress(),
              style: ButtonStyle(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
              ),
              child: Text(
                negativeCTAText,
                style: TextStyle(
                  fontFamily: 'Mulish',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontStyle: FontStyle.normal,
                  color: Color(0xFFEC6625),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
