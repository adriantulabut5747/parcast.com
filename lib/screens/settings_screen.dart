import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSwitch;

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/agos_icons.dart';

/// ============================================================
/// SETTINGS — appearance, notifications, location
/// ============================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _floodAlerts = true;
  bool _weatherAlerts = true;
  bool _community = true;
  bool _sound = true;
  bool _location = false;
  RiskLevel _minSeverity = RiskLevel.normal;
  String _barangay = 'Poblacion';

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return SubpageScaffold(
      title: 'Settings',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const FieldLabel('Appearance'),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) => Row(
                  children: [
                    for (final (m, icon, label) in [
                      (ThemeMode.light, CupertinoIcons.sun_max_fill, 'Light'),
                      (ThemeMode.dark, CupertinoIcons.moon_fill, 'Dark'),
                      (
                        ThemeMode.system,
                        CupertinoIcons.circle_lefthalf_fill,
                        'System',
                      ),
                    ]) ...[
                      if (m != ThemeMode.light) const SizedBox(width: 10),
                      Expanded(child: _themeOption(c, m, icon, label, mode)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const FieldLabel('Notifications'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _switch(
                      c,
                      AgosIcons.flood,
                      'Flood alerts',
                      'Water levels and flood warnings',
                      _floodAlerts,
                      (v) => setState(() => _floodAlerts = v),
                    ),
                    _divider(c),
                    _switch(
                      c,
                      CupertinoIcons.cloud_bolt_rain_fill,
                      'Weather advisories',
                      'Heavy rain and storms',
                      _weatherAlerts,
                      (v) => setState(() => _weatherAlerts = v),
                    ),
                    _divider(c),
                    _switch(
                      c,
                      CupertinoIcons.exclamationmark_bubble_fill,
                      'Community reports',
                      'Incidents reported near you',
                      _community,
                      (v) => setState(() => _community = v),
                    ),
                    _divider(c),
                    _switch(
                      c,
                      CupertinoIcons.speaker_2_fill,
                      'Alert sound',
                      'Play a sound for high alerts',
                      _sound,
                      (v) => setState(() => _sound = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const FieldLabel('Notify me about'),
              Row(
                children: [
                  for (final level in RiskLevel.values) ...[
                    if (level != RiskLevel.normal) const SizedBox(width: 8),
                    Expanded(
                      child: SelectChip(
                        label: switch (level) {
                          RiskLevel.normal => 'Everything',
                          RiskLevel.moderate => 'Moderate+',
                          RiskLevel.high => 'High only',
                        },
                        color: level.color,
                        selected: _minSeverity == level,
                        onTap: () => setState(() => _minSeverity = level),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              const FieldLabel('Location'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _switch(
                  c,
                  CupertinoIcons.location_fill,
                  'Share my location',
                  'Helps rescuers find you faster',
                  _location,
                  (v) => setState(() => _location = v),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'My barangay',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              BarangayDropdown(
                value: _barangay,
                onChanged: (v) => setState(() => _barangay = v),
              ),
              const SizedBox(height: 20),
              Text(
                'Settings are a preview and reset when the app reloads.',
                style: TextStyle(color: c.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(
    AppColors c,
    ThemeMode m,
    IconData icon,
    String label,
    ThemeMode current,
  ) {
    final selected = m == current;
    return PressableScale(
      onTap: () => themeNotifier.value = m,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? c.inverse : c.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Colors.transparent : c.border),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? c.onInverse : c.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? c.onInverse : c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppColors c) =>
      Divider(height: 1, indent: 64, color: c.border);

  Widget _switch(
    AppColors c,
    IconData icon,
    String title,
    String sub,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    // An iOS Settings row: icon tile, title + note, the Apple switch.
    // The whole row toggles it, like on iPhone.
    return PressableScale(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            IconBadge(icon, c.accent, size: 36, squircle: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: kSafe,
            ),
          ],
        ),
      ),
    );
  }
}
