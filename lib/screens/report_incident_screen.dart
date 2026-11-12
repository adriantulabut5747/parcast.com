import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/flood_depth.dart';
import '../widgets/agos_map.dart';
import '../widgets/agos_icons.dart';

/// ============================================================
/// REPORT INCIDENT — type, severity, photo, location, notes
/// (front end only: nothing is sent yet)
/// ============================================================
class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  static const _types = [
    (AgosIcons.flood, 'Flooding'),
    (CupertinoIcons.nosign, 'Blocked road'),
    (AgosIcons.landslide, 'Landslide'),
    (CupertinoIcons.bolt_fill, 'Fallen power line'),
    (CupertinoIcons.person_3_fill, 'Stranded people'),
    (CupertinoIcons.ellipsis, 'Other'),
  ];

  // Types where water depth matters. The depth card is hidden for the rest.
  static const _waterTypes = {'Flooding', 'Blocked road', 'Stranded people'};

  String? _type;
  RiskLevel _severity = RiskLevel.moderate;
  double? _depthCm; // null = not set yet
  String _barangay = 'Poblacion';
  Uint8List? _photo;
  bool _submitting = false;
  final _map = AgosMapController();

  bool get _asksDepth => _waterTypes.contains(_type);

  // Setting the depth also picks the matching severity. The user can
  // still change the severity by hand afterwards.
  void _setDepth(double cm) => setState(() {
    _depthCm = cm;
    _severity = riskForDepth(cm);
  });

  // Opens the camera or the gallery (`source`) and keeps the chosen photo.
  // maxWidth + imageQuality shrink big phone photos (often 4000+ px, several
  // MB) so the preview stays fast. `file` is null if the user cancelled.
  // The photo is kept as raw bytes (Uint8List) because on the web there's
  // no real file path; Image.memory shows it from those bytes.
  // try/catch: some browsers/devices refuse (no camera, permission
  // denied), and then we show a message instead of crashing.
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _photo = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t open the photo picker.')),
      );
    }
  }

  // Demo only: nothing is sent anywhere. The 0.9 s wait just imitates a
  // real upload so the button's spinner shows. `await showSuccessDialog`
  // waits until the user closes the popup; then the screen closes too.
  Future<void> _submit() async {
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _submitting = false);
    final depth = _asksDepth && _depthCm != null
        ? ' (${FloodLevel.of(_depthCm!).label.toLowerCase()}, about ${formatCm(_depthCm!)})'
        : '';
    await showSuccessDialog(
      context,
      title: 'Report submitted (demo)',
      message:
          'Thanks for reporting ${_type!.toLowerCase()}$depth in Brgy. $_barangay. In the full app, an Admin would review it.\n\nNothing was actually sent yet.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final point = kBarangayPoints[_barangay] ?? kMabalacatCenter;
    return SubpageScaffold(
      title: 'Report incident',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                'Help your neighbors by reporting what you see.',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              const FieldLabel('What happened?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (icon, label) in _types)
                    SelectChip(
                      label: label,
                      icon: icon,
                      selected: _type == label,
                      onTap: () => setState(() => _type = label),
                    ),
                ],
              ),
              // AnimatedSize: the depth card slides open/closed instead of
              // popping in when the type changes.
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _asksDepth
                    ? Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: _depthCard(c),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 22),
              const FieldLabel('How serious is it?'),
              _severityBar(c),
              if (_asksDepth && _depthCm != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Set from the water depth. Tap to change it.',
                    style: TextStyle(color: c.textSecondary, fontSize: 11.5),
                  ),
                ),
              const SizedBox(height: 22),
              const FieldLabel('Photo (optional)'),
              _photoBox(c),
              const SizedBox(height: 22),
              const FieldLabel('Where?'),
              BarangayDropdown(
                value: _barangay,
                onChanged: (v) {
                  setState(() => _barangay = v);
                  _map.flyTo(
                    kBarangayPoints[v] ?? kMabalacatCenter,
                    zoom: 14.5,
                  );
                },
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 150,
                  // A still preview (no dragging): shows where the
                  // report will be pinned, in the color of its severity.
                  child: AgosMap(
                    controller: _map,
                    center: point,
                    zoom: 14.5,
                    interactive: false,
                    pins: [
                      MapPin(
                        id: 'report',
                        kind: PinKind.flood,
                        point: point,
                        color: _severity.color,
                        icon: AgosIcons.flood,
                        title: _barangay,
                        a11y: 'Report location, Brgy. $_barangay',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const FieldLabel('Details (optional)'),
              const AppTextField(
                hint: 'e.g. Water is waist-deep near the chapel',
                maxLines: 3,
              ),
              const SizedBox(height: 26),
              PrimaryButton(
                label: _type == null ? 'Choose what happened' : 'Submit report',
                icon: CupertinoIcons.paperplane_fill,
                loading: _submitting,
                onPressed: _type == null ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The gauge on the left, the numbers on the right, and a tip below.
  Widget _depthCard(AppColors c) {
    final cm = _depthCm;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DepthGauge(
                depthCm: cm ?? 0,
                color: cm == null ? c.accent : riskForDepth(cm).color,
                width: 160,
                height: 240,
                onChanged: _setDepth,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: DepthReadout(depthCm: cm, caption: 'Water depth'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Drag the water up or down to match what you see. Compare it '
            'with people walking through, car tires, or a wall nearby.',
            style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  // One bar split in three, instead of three separate buttons.
  Widget _severityBar(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final level in RiskLevel.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: _severity == level,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _severity = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _severity == level ? level.color : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _severity == level
                                ? Colors.white
                                : level.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            level == RiskLevel.normal ? 'Minor' : level.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _severity == level
                                  ? Colors.white
                                  : c.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoBox(AppColors c) {
    if (_photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Image.memory(
              _photo!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 10,
              right: 10,
              child: PressableScale(
                onTap: () => setState(() => _photo = null),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // One box split in two halves, like the severity bar.
    Widget option(IconData icon, String label, ImageSource source) => Expanded(
      child: InkWell(
        onTap: () => _pickPhoto(source),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c.accent, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.border),
      ),
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            option(CupertinoIcons.camera, 'Take photo', ImageSource.camera),
            VerticalDivider(
              width: 1,
              color: c.border,
              indent: 16,
              endIndent: 16,
            ),
            option(
              CupertinoIcons.photo_on_rectangle,
              'Choose from gallery',
              ImageSource.gallery,
            ),
          ],
        ),
      ),
    );
  }
}
