import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoActivityIndicator;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:exif/exif.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/flood_depth.dart';
import '../widgets/agos_map.dart';
import '../widgets/barangay_search.dart';
import '../widgets/map_glass.dart';
import '../services/photo.dart';
import '../services/reports.dart';
import '../services/weather.dart' show formatDate, formatTime;

/// ============================================================
/// REPORT INCIDENT — type, severity, photo, location, notes
/// Posts to Supabase (services/reports.dart, use case "Submit Flood
/// Report"). Guests never get here (openReportIncident asks them to log in).
/// ============================================================
class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  // Types where water depth matters. The depth card is hidden for the rest.
  static const _waterTypes = {'Flooding', 'Blocked road', 'Stranded people'};

  String? _type;
  RiskLevel _severity = RiskLevel.moderate;
  double? _depthCm; // null = not set yet
  late String _barangay = myBarangay.value ?? 'Poblacion';
  // Where the pin goes. Starts at the user's barangay, but only counts
  // once they set it ([_placed]: the pin picker or "Use my location"), so
  // nobody posts a flood at a barangay's center by accident.
  late LatLng _point = kBarangayPoints[_barangay] ?? kMabalacatCenter;
  bool _placed = false;
  // Submit was tapped with something missing: show what, in red. Each tap
  // bumps [_nudge], which shakes the first missing part again.
  bool _showMissing = false;
  int _nudge = 0;
  final _typeKey = GlobalKey();
  final _whereKey = GlobalKey();
  Uint8List? _photo;
  DateTime? _photoTakenAt;
  bool _submitting = false;
  bool _locating = false;
  final _map = AgosMapController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _map.dispose();
    _note.dispose();
    super.dispose();
  }

  // A spot was set (picker or GPS): the barangay becomes the one whose
  // center is closest (a guess the user can change below the map).
  void _setSpot(LatLng p) {
    setState(() {
      _point = p;
      _placed = true;
      _barangay = nearestBarangay(p);
    });
    _map.flyTo(p, zoom: 17);
  }

  // The big map: drag it under the pin, or search a barangay. Null = closed
  // without setting it.
  Future<void> _openPicker() async {
    final p = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SpotPicker(start: _point, placed: _placed),
      ),
    );
    if (p != null && mounted) _setSpot(p);
  }

  /// What's still missing before the report can go out, in form order:
  /// (the part's key, what to tell the user).
  List<(GlobalKey, String)> get _missing => [
    if (_type == null) (_typeKey, 'Choose what happened first.'),
    if (!_placed) (_whereKey, 'Set the spot: tap the map below.'),
  ];

  // Submit is always tappable: with something missing, it scrolls up to
  // the first missing part, outlines it in red with a hint, and shakes it.
  void _trySubmit() {
    final missing = _missing;
    if (missing.isEmpty) {
      _submit();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _showMissing = true;
      _nudge++;
    });
    final target = missing.first.$1.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 450),
        curve: kSnappyCurve,
        alignment: 0.15,
      );
    }
  }

  String? _hintFor(GlobalKey key) {
    if (!_showMissing) return null;
    for (final (k, text) in _missing) {
      if (k == key) return text;
    }
    return null;
  }

  static String nearestBarangay(LatLng p) {
    const d = Distance();
    return kBarangayPoints.entries
        .reduce((a, b) => d(p, a.value) <= d(p, b.value) ? a : b)
        .key;
  }

  static bool _inCity(LatLng p) =>
      p.latitude >= kCityBounds.south &&
      p.latitude <= kCityBounds.north &&
      p.longitude >= kCityBounds.west &&
      p.longitude <= kCityBounds.east;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // "Use my location": the browser / phone asks for permission first.
  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _say('Location is blocked. Tap the map to set the spot instead.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final p = LatLng(pos.latitude, pos.longitude);
      if (!_inCity(p)) {
        _say(
          'You seem to be outside Mabalacat. Tap the map to set the spot instead.',
        );
        return;
      }
      _setSpot(p);
    } catch (_) {
      _say("Couldn't get your location. Tap the map to set the spot instead.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // When the photo was taken: now for the camera; for the gallery, the
  // date the camera wrote into the file (EXIF), else the file's date.
  static Future<DateTime> _takenAt(
    XFile file,
    Uint8List raw,
    ImageSource source,
  ) async {
    if (source == ImageSource.camera) return DateTime.now();
    try {
      final tags = await readExifFromBytes(raw);
      final v =
          (tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'])?.printable;
      // "2026:11:13 14:05:09", in the phone's local time.
      final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})')
          .firstMatch(v ?? '');
      if (m != null) {
        final n = [for (var i = 1; i <= 6; i++) int.parse(m[i]!)];
        return DateTime(n[0], n[1], n[2], n[3], n[4], n[5]);
      }
    } catch (_) {
      // No readable EXIF: use the file's date.
    }
    return file.lastModified();
  }

  bool get _asksDepth => _waterTypes.contains(_type);

  // Setting the depth also picks the matching severity. The user can
  // still change the severity by hand afterwards.
  void _setDepth(double cm) => setState(() {
    _depthCm = cm;
    _severity = riskForDepth(cm);
  });

  // Opens the camera or the gallery (`source`) and keeps the chosen photo.
  // Phones shrink it while picking (maxWidth); the browser picks the
  // original (so its date survives) and shrinks it after (photo_web.dart):
  // a 4000 px, several-MB phone photo becomes ~300 KB for the upload.
  // `file` is null if the user cancelled. try/catch: some browsers refuse
  // (no camera, permission denied, a format the browser can't open).
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: kPickerResizes ? 1600 : null,
        imageQuality: kPickerResizes ? 80 : null,
      );
      if (file == null) return;
      final raw = await file.readAsBytes();
      final taken = await _takenAt(file, raw, source);
      if (DateTime.now().difference(taken) >= kPinLifetime) {
        _say('That photo is more than 14 days old. Reports need a recent one.');
        return;
      }
      final bytes = await shrinkPhoto(raw);
      setState(() {
        _photo = bytes;
        _photoTakenAt = taken;
      });
    } catch (_) {
      _say("Couldn't open that photo. Try another one, or a JPEG.");
    }
  }

  // Uploads the photo, saves the report, then says thanks and closes.
  // On failure the form stays as it is so the user can try again.
  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await submitReport(
        incidentType: _type!.toLowerCase(),
        severity: severityFromRisk(_severity),
        depthCm: _asksDepth ? _depthCm?.round() : null,
        barangay: _barangay,
        point: _point,
        note: _note.text,
        photo: _photo,
        photoTakenAt: _photoTakenAt ?? DateTime.now(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _say(reportErrorMessage(e));
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    await showSuccessDialog(
      context,
      title: 'Report posted',
      message: "Thanks! It's on the map and in Reports for everyone now. An Admin will check it. It's removed 14 days after the photo was taken.",
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
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
              _Attention(
                key: _typeKey,
                nudge: _nudge,
                hint: _hintFor(_typeKey),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('What happened?'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (icon, label) in kIncidentTypes)
                          SelectChip(
                            label: label,
                            icon: icon,
                            selected: _type == label,
                            onTap: () => setState(() => _type = label),
                          ),
                      ],
                    ),
                  ],
                ),
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
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 22),
              const FieldLabel('Photo (optional, but it helps)'),
              _photoBox(c),
              if (_photoTakenAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Taken ${formatDate(_photoTakenAt!)}, ${formatTime(_photoTakenAt!)}. '
                    'The report is removed 14 days after that.',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 22),
              _Attention(
                key: _whereKey,
                nudge: _nudge,
                hint: _hintFor(_whereKey),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [const FieldLabel('Where?'), _wherePreview(c)],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _placed
                          ? 'Pin set. Tap the map to move it.'
                          : 'Tap the map to drop the pin on the exact spot.',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _locating
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CupertinoActivityIndicator(),
                        )
                      : TintedButton(
                          label: 'Use my location',
                          icon: CupertinoIcons.location_fill,
                          onPressed: _useMyLocation,
                        ),
                ],
              ),
              const SizedBox(height: 10),
              // Fixes the barangay guess; the pin stays where it is. Before
              // a pin is set, it also moves where the map opens.
              BarangayDropdown(
                value: _barangay,
                onChanged: (v) {
                  setState(() => _barangay = v);
                  if (!_placed) {
                    _point = kBarangayPoints[v] ?? kMabalacatCenter;
                    _map.flyTo(_point, zoom: 15);
                  }
                },
              ),
              const SizedBox(height: 22),
              const FieldLabel('Details (optional)'),
              AppTextField(
                controller: _note,
                hint: 'e.g. Water is waist-deep near the chapel',
                maxLines: 3,
              ),
              const SizedBox(height: 26),
              // Always tappable: _trySubmit shows what's missing, if anything.
              PrimaryButton(
                label: 'Submit report',
                icon: CupertinoIcons.paperplane_fill,
                loading: _submitting,
                onPressed: _trySubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The small map: not draggable (scrolling the form over it would pan
  // it), just a picture of the spot. Tap it, or "Edit pin", for the big
  // map. Until a spot is set it says so instead of showing a pin.
  Widget _wherePreview(AppColors c) {
    return Semantics(
      button: true,
      label: _placed ? 'Edit the pin' : 'Set the spot on the map',
      child: GestureDetector(
        onTap: _openPicker,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AgosMap(
                  controller: _map,
                  center: _point,
                  zoom: 15,
                  interactive: false,
                ),
                if (_placed)
                  Center(
                    child: Padding(
                      // Lifts the icon so its tip is the middle.
                      padding: const EdgeInsets.only(bottom: 34),
                      child: Icon(
                        CupertinoIcons.map_pin,
                        size: 34,
                        color: c.readable(_severity.color),
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  )
                else
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.map_pin_ellipse,
                            color: Colors.white,
                            size: 30,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap to set the spot',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _placed ? CupertinoIcons.pencil : CupertinoIcons.plus,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _placed ? 'Edit pin' : 'Set pin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
                              fontSize: 13,
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
                onTap: () => setState(() {
                  _photo = null;
                  _photoTakenAt = null;
                }),
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
                fontSize: 13,
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

/// The big map for placing the pin: full screen, drag the map under the
/// fixed pin, or search a barangay to jump there. "Set location" returns
/// the spot; the x closes without changing anything.
class _SpotPicker extends StatefulWidget {
  final LatLng start;
  final bool placed;
  const _SpotPicker({required this.start, required this.placed});

  @override
  State<_SpotPicker> createState() => _SpotPickerState();
}

class _SpotPickerState extends State<_SpotPicker> {
  final _map = AgosMapController();
  late LatLng _spot = widget.start;

  @override
  void initState() {
    super.initState();
    // The map reports its middle when it stops moving.
    _map.center.addListener(() {
      final p = _map.center.value;
      if (p != null && mounted) setState(() => _spot = p);
    });
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final pad = MediaQuery.paddingOf(context);
    final barangay = _ReportIncidentScreenState.nearestBarangay(_spot);
    return Material(
      color: c.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: AgosMap(
              controller: _map,
              center: widget.start,
              zoom: widget.placed ? 17 : 15.5,
            ),
          ),
          // The pin stays in the middle; the map moves under it.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Icon(
                  CupertinoIcons.map_pin,
                  size: 44,
                  color: c.accent,
                  shadows: const [
                    Shadow(color: Color(0x66000000), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: pad.top + 12,
            left: 12,
            right: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MapGlass(
                  radius: 24,
                  child: Semantics(
                    button: true,
                    label: 'Close without changing the pin',
                    child: PressableScale(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: c.border),
                        ),
                        child: Icon(
                          CupertinoIcons.xmark,
                          color: c.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BarangaySearch(
                    onPick: (b) => _map.flyTo(
                      kBarangayPoints[b] ?? kMabalacatCenter,
                      zoom: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: pad.bottom + 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: MapGlass(
                  radius: 24,
                  child: GlassCard(
                    radius: 24,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Brgy. $barangay',
                          style: TextStyle(
                            fontFamily: kDisplayFont,
                            color: c.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: displayTracking(20),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Drag the map so the pin sits on the exact spot.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label: 'Set location',
                          icon: CupertinoIcons.checkmark_alt,
                          onPressed: () => Navigator.of(context).pop(_spot),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A form part that needs an answer. [hint] set = it's missing: a red
/// outline and the hint under it. Each new [nudge] shakes it (a short,
/// decaying side-to-side wobble, like a wrong passcode on iOS) while it's
/// missing.
class _Attention extends StatelessWidget {
  final Widget child;
  final String? hint;
  final int nudge;
  const _Attention({
    required this.child,
    required this.hint,
    required this.nudge,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final missing = hint != null;
    return TweenAnimationBuilder<double>(
      // A new key per nudge restarts the shake.
      key: ValueKey(missing ? nudge : -1),
      tween: Tween(begin: missing ? 1 : 0, end: 0),
      duration: const Duration(milliseconds: 500),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 6) * 8 * t, 0),
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.all(missing ? 10 : 0),
        decoration: BoxDecoration(
          color: missing ? kDanger.withValues(alpha: 0.07) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: missing ? c.readable(kDanger) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            child,
            if (missing)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_circle_fill,
                      size: 16,
                      color: c.readable(kDanger),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hint!,
                        style: TextStyle(
                          color: c.readable(kDanger),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
