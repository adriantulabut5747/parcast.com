import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';

/// ============================================================
/// EVACUATION CENTERS — list with status, distance and directions
/// ============================================================
class EvacuationCentersScreen extends StatefulWidget {
  const EvacuationCentersScreen({super.key});

  @override
  State<EvacuationCentersScreen> createState() =>
      _EvacuationCentersScreenState();
}

class _EvacuationCentersScreenState extends State<EvacuationCentersScreen> {
  bool _openOnly = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Copy the list first ([...kEvacCenters]) because kEvacCenters is a
    // const list and can't be sorted in place. Then sort nearest first:
    // compareTo returns negative/zero/positive to say which goes first.
    final centers = [...kEvacCenters]
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final shown = _openOnly ? centers.where((e) => e.open).toList() : centers;
    final openCount = centers.where((e) => e.open).length;
    // The closest open one (the list is sorted nearest first).
    final nearest = centers.where((e) => e.open).firstOrNull;

    return SubpageScaffold(
      title: 'Evacuation centers',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summary(
                      c,
                      '$openCount',
                      'Open now',
                      kShelter,
                      CupertinoIcons.checkmark_circle_fill,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summary(
                      c,
                      nearest == null ? '–' : '${nearest.distanceKm} km',
                      'Nearest open',
                      kBlue,
                      CupertinoIcons.location_fill,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const SampleBadge(),
                  const Spacer(),
                  SelectChip(
                    label: 'All',
                    selected: !_openOnly,
                    onTap: () => setState(() => _openOnly = false),
                  ),
                  const SizedBox(width: 8),
                  SelectChip(
                    label: 'Open only',
                    selected: _openOnly,
                    onTap: () => setState(() => _openOnly = true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < shown.length; i++)
                FadeSlideIn(
                  delay: Duration(milliseconds: 60 * i),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: EvacCenterCard(center: shown[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(
    AppColors c,
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    return AppCard(
      child: Row(
        children: [
          IconBadge(icon, color, size: 42, squircle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card for one evacuation center. [compact] is the smaller home-page version.
class EvacCenterCard extends StatelessWidget {
  final EvacuationCenter center;
  final bool compact;
  const EvacCenterCard({required this.center, this.compact = false, super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final e = center;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => openDirections(context, e.point),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo (drop a file in assets/images/ to replace the placeholder)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: compact ? 88 : 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AssetImageWithFallback(
                    e.image,
                    fit: BoxFit.cover,
                    fallback: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: e.open
                              ? [kGraphite, Color(0xFF3A3A3C)]
                              : [
                                  const Color(0xFF3B4658),
                                  const Color(0xFF5B6678),
                                ],
                        ),
                      ),
                      child: Icon(
                        e.icon,
                        size: compact ? 38 : 52,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: StatusPill(
                      e.open ? 'Open' : 'Standby',
                      e.open ? kShelter : const Color(0xFF94A3B8),
                      solid: true,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${e.distanceKm} km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Brgy. ${e.barangay}',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.open ? 'Open now' : 'Standby, not open yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 11),
                      ),
                    ),
                    if (!compact)
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.arrow_up_right_diamond_fill,
                            size: 16,
                            color: c.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Directions',
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
