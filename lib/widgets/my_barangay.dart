import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/auth.dart';
import '../theme.dart';
import 'common.dart';

/// ============================================================
/// MY BARANGAY — the user's own barangay ([myBarangay])
/// ============================================================
/// Picked once; Weather shows its latest report, Reports can filter to it,
/// and the bell marks alerts for it. Logged in, it's saved on the user's
/// row (sign-up already asked for it, so it can't be cleared); a guest's
/// lives in memory only.

/// Opens the picker: all 27 barangays as chips.
Future<void> pickMyBarangay(BuildContext context) {
  return showAppSheet(
    context,
    builder: (sheet) {
      final c = AppColors(sheet);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your barangay',
            style: TextStyle(
              fontFamily: kDisplayFont,
              color: c.textPrimary,
              fontSize: 22,
              letterSpacing: displayTracking(22),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We\'ll show its reports and alerts first.',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in kBarangays)
                SelectChip(
                  label: b,
                  selected: myBarangay.value == b,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    _setMyBarangay(context, b);
                  },
                ),
            ],
          ),
          if (isGuest && myBarangay.value != null) ...[
            const SizedBox(height: 14),
            Center(
              child: TintedButton(
                label: 'Clear',
                onPressed: () {
                  myBarangay.value = null;
                  Navigator.of(sheet).pop();
                },
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Shows the new barangay right away, then saves it; puts the old one back
/// if saving fails.
Future<void> _setMyBarangay(BuildContext context, String b) async {
  final old = myBarangay.value;
  myBarangay.value = b;
  if (isGuest) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await saveMyBarangay(b);
  } catch (_) {
    myBarangay.value = old;
    messenger.showSnackBar(
      const SnackBar(content: Text('Couldn\'t save your barangay. Try again.')),
    );
  }
}

/// Small pill: "Brgy. Dau" (or "Set your barangay"). Tap to change it.
class MyBarangayChip extends StatelessWidget {
  /// Light text, for use on a photo or the sky card.
  final bool onDark;
  const MyBarangayChip({this.onDark = false, super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return ValueListenableBuilder<String?>(
      valueListenable: myBarangay,
      builder: (context, b, _) {
        final fg = onDark ? Colors.white : c.textPrimary;
        return Semantics(
          button: true,
          label: b == null ? 'Set your barangay' : 'Your barangay: $b. Change',
          child: PressableScale(
            onTap: () => pickMyBarangay(context),
            child: Container(
              padding: const EdgeInsets.fromLTRB(9, 6, 11, 6),
              decoration: BoxDecoration(
                color: onDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : c.surfaceAlt,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: onDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : c.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    b == null
                        ? CupertinoIcons.plus_circle_fill
                        : CupertinoIcons.placemark_fill,
                    size: 14,
                    color: b == null ? c.accent : fg,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    b == null ? 'Set your barangay' : 'Brgy. $b',
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 11,
                    color: fg.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
