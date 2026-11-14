import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'common.dart';

/// Opens Google Maps with directions to [point].
Future<void> openDirections(BuildContext context, LatLng point) async {
  final url = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${point.latitude},${point.longitude}',
  });
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Couldn\'t open Google Maps.')),
    );
  }
}

/// Asks before calling, so nobody dials a hotline by accident.
Future<void> confirmCall(
  BuildContext context, {
  required String name,
  required String number,
  Color color = kDanger,
}) {
  return showAppSheet(
    context,
    builder: (sheet) {
      final c = AppColors(sheet);
      return Column(
        children: [
          IconBadge(CupertinoIcons.phone_fill, color, size: 64),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            number,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Call now',
            icon: CupertinoIcons.phone_fill,
            onPressed: () async {
              Navigator.of(sheet).pop();
              final digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
              final ok = await launchUrl(Uri(scheme: 'tel', path: digits));
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Calling isn\'t supported here. Dial $number.',
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(sheet).pop(),
          ),
        ],
      );
    },
  );
}
