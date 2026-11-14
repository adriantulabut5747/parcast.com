import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import '../widgets/tugak.dart';
import '../widgets/agos_icons.dart';

/// ============================================================
/// ABOUT and HELP screens
/// ============================================================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    const features = [
      (
        CupertinoIcons.cloud_fill,
        'Live weather',
        'Live conditions and forecast for Mabalacat City.',
      ),
      (
        AgosIcons.flood,
        'Flood outlook',
        'A daily flood risk estimate from the rain forecast.',
      ),
      (
        CupertinoIcons.map_fill,
        'Flood map',
        'Flood zones and evacuation centers on an interactive map.',
      ),
      (
        AgosIcons.lifebuoyFill,
        'Emergency help',
        'SOS, rescue requests, and one-tap hotlines.',
      ),
    ];
    return SubpageScaffold(
      title: 'About',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const SizedBox(height: 8),
              // A real Mabalacat landmark instead of a stock picture.
              const LocalPhotoView(kPhotoMabuhayArch, height: 190, radius: 20),
              const SizedBox(height: 16),
              Center(
                child: BrandLogo.icon(
                  height: 110,
                  fallback: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: kGraphite,
                    ),
                    child: const Icon(
                      AgosIcons.waves,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'AgosAlert helps the people of Mabalacat City, Pampanga stay safe during floods: know the weather, see where it\'s flooding, and get help fast.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"Agos" means current, the flow of water.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconBadge(
                      CupertinoIcons.lab_flask_solid,
                      kBlue,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Unofficial demo. AgosAlert is a school project, not '
                        'an app of the Mabalacat City government. The weather '
                        'and flood reports are live (posted by users, not yet '
                        'checked by an official); alerts and evacuation centers '
                        'are sample data (marked SAMPLE). Who will run it is '
                        'not decided yet.',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const FieldLabel('Features'),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < features.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconBadge(
                            features[i].$1,
                            c.accent,
                            size: 40,
                            squircle: true,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  features[i].$2,
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  features[i].$3,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const FieldLabel('Data sources'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _source(
                      c,
                      'Weather, air quality',
                      'Open-Meteo (open-meteo.com)',
                    ),
                    _source(
                      c,
                      'Map',
                      '© OpenStreetMap contributors, via Protomaps · Terrain: '
                          'Mapzen / AWS Terrain Tiles · MapLibre',
                    ),
                    _source(
                      c,
                      'Flood reports and photos',
                      'Posted by AgosAlert users',
                    ),
                    _source(
                      c,
                      'Alerts, evacuation centers',
                      'Sample data (live data coming soon)',
                    ),
                    for (final p in kLocalPhotos)
                      _source(c, p.place, '${p.credit} (Wikimedia Commons)'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const FieldLabel('Who made it'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _source(c, 'Made by', 'BSIT students, school capstone'),
                    _source(
                      c,
                      'Source code',
                      'github.com/adriantulabut5747/AgosAlert',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _source(AppColors c, String what, String from) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              what,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ),
          Flexible(
            child: Text(
              from,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return SubpageScaffold(
      title: 'Help & FAQ',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const TugakBeside(
                pose: 'think',
                line: 'These are the questions people ask me most. Tap one, the answers are short.',
              ),
              const SizedBox(height: 20),
              const FieldLabel('Frequently asked questions'),
              for (final (q, a) in kFaqs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: Theme(
                      // Hide the default ExpansionTile divider lines
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        shape: const RoundedRectangleBorder(),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        iconColor: c.accent,
                        collapsedIconColor: c.textSecondary,
                        title: Text(
                          q,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        children: [
                          Text(
                            a,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              AppCard(
                gradient: LinearGradient(
                  colors: [
                    kBlue.withValues(alpha: c.isDark ? 0.3 : 0.12),
                    c.surface,
                  ],
                ),
                child: Row(
                  children: [
                    IconBadge(
                      CupertinoIcons.phone_circle_fill,
                      c.accent,
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Still need help?',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Call the Mabalacat CDRRMO',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TintedButton(
                      label: 'Call',
                      icon: CupertinoIcons.phone_fill,
                      onPressed: () => confirmCall(
                        context,
                        name: kHotlines[1].name,
                        number: kHotlines[1].number,
                        color: kBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
