import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme.dart';
import 'map_glass.dart';

/// Search box for the 27 barangays, and nothing else (Adrian's call: the
/// map is only Mabalacat, so a street/place search would mostly miss).
/// Typing shows matching barangays under the field; picking one calls
/// [onPick] (the map flies there / the pin moves there) and clears it.
/// [overMap]: the box floats over the web map, so the field and the list
/// get MapGlass (real blur, and taps don't fall through to the map).
/// Barangays matching [q]: names starting with it first, then the rest
/// that contain it ("ma" -> Mabiga, Macapagal Village..., then Santa Maria).
List<String> barangayMatches(String q) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return const [];
  final starts = kBarangays.where((b) => b.toLowerCase().startsWith(s));
  final contains = kBarangays.where(
    (b) => !b.toLowerCase().startsWith(s) && b.toLowerCase().contains(s),
  );
  return [...starts, ...contains];
}

class BarangaySearch extends StatefulWidget {
  final ValueChanged<String> onPick;
  final bool overMap;
  const BarangaySearch({required this.onPick, this.overMap = true, super.key});

  @override
  State<BarangaySearch> createState() => _BarangaySearchState();
}

class _BarangaySearchState extends State<BarangaySearch> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(String b) {
    widget.onPick(b);
    _text.clear();
    _focus.unfocus();
  }

  Widget _box(AppColors c, Widget child, {double radius = 16}) {
    final box = Container(
      decoration: BoxDecoration(
        color: widget.overMap
            ? c.surface.withValues(alpha: c.isDark ? 0.72 : 0.8)
            : c.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: widget.overMap ? Border.all(color: c.border) : null,
      ),
      child: child,
    );
    return widget.overMap ? MapGlass(radius: radius, child: box) : box;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final found = barangayMatches(_text.text);
    final showList = _focus.hasFocus && _text.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _box(
          c,
          TextField(
            controller: _text,
            focusNode: _focus,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (found.isNotEmpty) _pick(found.first);
            },
            textInputAction: TextInputAction.search,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            cursorColor: c.accent,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixIcon: Icon(
                CupertinoIcons.search,
                color: c.textSecondary,
                size: 18,
              ),
              suffixIcon: _text.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: c.textSecondary,
                        size: 18,
                      ),
                      onPressed: () => setState(_text.clear),
                    ),
              hintText: 'Search a barangay',
              hintStyle: TextStyle(color: c.textSecondary, fontSize: 15),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        if (showList) ...[
          const SizedBox(height: 6),
          _box(
            c,
            radius: 14,
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 248),
              child: found.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'No barangay by that name in Mabalacat.',
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        for (final b in found)
                          InkWell(
                            onTap: () => _pick(b),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.placemark_fill,
                                    size: 16,
                                    color: c.accent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Brgy. $b',
                                      style: TextStyle(
                                        color: c.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
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
        ],
      ],
    );
  }
}
