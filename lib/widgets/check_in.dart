import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/demo_data.dart';
import '../services/share.dart';
import '../services/weather.dart';
import '../theme.dart';
import 'common.dart';
import 'tugak.dart';

/// ============================================================
/// "I'M SAFE" CHECK-IN — like Facebook's Safety Check, but it
/// only uses the phone's own share menu (no server needed)
/// ============================================================
/// Shows the message first, then hands it to the share menu (Messenger,
/// Viber, SMS...). Browsers without a share menu copy it instead.

/// The text that gets sent, e.g.
///   I'm safe. — AC Parcore, Brgy. Dau · Thu, Nov 12, 3:40 PM
///   Sent with AgosAlert, flood alerts for Mabalacat City.
String imSafeMessage(DateTime now) {
  final who = [
    if (!isGuest) kDemoUserName,
    if (myBarangay.value != null) 'Brgy. ${myBarangay.value}',
  ].join(', ');
  final when = '${formatDate(now)}, ${formatTime(now)}';
  return 'I\'m safe.${who.isEmpty ? '' : ' — $who'} · $when\n'
      'Sent with AgosAlert, flood alerts for Mabalacat City.';
}

Future<void> showImSafe(BuildContext context) {
  return showAppSheet(
    context,
    builder: (sheet) {
      final c = AppColors(sheet);
      final message = imSafeMessage(DateTime.now());
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: TugakImage(size: 110)),
          const SizedBox(height: 6),
          Text(
            'Tell people you\'re safe',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kDisplayFont,
              color: c.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One message to family and friends, so nobody has to guess.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          // The message, in a chat-bubble look.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Share "I\'m safe"',
            icon: CupertinoIcons.share,
            color: kSafe,
            onPressed: () async {
              final shared = await shareText(message);
              if (!shared) {
                await Clipboard.setData(ClipboardData(text: message));
              }
              if (!sheet.mounted) return;
              Navigator.of(sheet).pop();
              if (!shared && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied. Paste it into any chat.'),
                  ),
                );
              }
            },
          ),
        ],
      );
    },
  );
}
