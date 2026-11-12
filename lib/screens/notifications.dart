import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// ============================================================
/// NOTIFICATIONS — the alerts from the Admin and PAGASA, opened
/// from the bell (a sheet on phones, a popup on wider screens)
/// ============================================================
/// Reports from residents live in the Reports tab; this is only for
/// official-style notices. The newest unread High alert also shows as a
/// red strip on the Weather tab.

/// Opens the notifications. [context] must be inside HomeShell (the bell
/// button's), so "View on map" can switch tabs.
void showNotifications(BuildContext context) {
  showAppSheet(
    context,
    maxWidth: 600,
    builder: (sheet) => _NotificationsPanel(
      onViewMap: () {
        Navigator.of(sheet).pop();
        HomeShell.of(context)?.switchTab(1);
      },
    ),
  );
}

class _NotificationsPanel extends StatefulWidget {
  final VoidCallback onViewMap;
  const _NotificationsPanel({required this.onViewMap});

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  AlertCategory? _filter; // null = all
  AppAlert? _open; // the alert being read; null = the list

  // `.where(...)` keeps only the alerts of the picked category.
  List<AppAlert> get _filtered => _filter == null
      ? kAlerts
      : kAlerts.where((a) => a.category == _filter).toList();

  // `{...readAlerts.value, a.id}` = a NEW set with the old ids plus this
  // one. It has to be a new set, not .add(), or the listeners (bell badge,
  // the Weather strip) aren't told. See readAlerts in demo_data.dart.
  void _read(AppAlert a) {
    readAlerts.value = {...readAlerts.value, a.id};
    setState(() => _open = a);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Reading one alert: its details replace the list, with a Back row.
    // AnimatedSwitcher cross-fades between the two.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _open != null
          ? Column(
              key: ValueKey(_open!.id),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PressableScale(
                  onTap: () => setState(() => _open = null),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.chevron_back,
                          size: 18,
                          color: c.accent,
                        ),
                        Text(
                          'All notifications',
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _AlertDetails(alert: _open!, onViewMap: widget.onViewMap),
              ],
            )
          : ValueListenableBuilder<Set<String>>(
              key: const ValueKey('list'),
              valueListenable: readAlerts,
              builder: (context, read, _) => _list(c, read),
            ),
    );
  }

  Widget _list(AppColors c, Set<String> read) {
    final items = _filtered;
    final unread = unreadAlertCount;
    // "Today" = less than 24 hours old.
    final today = items.where((a) => a.ago.inHours < 24).toList();
    final earlier = items.where((a) => a.ago.inHours >= 24).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      color: c.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    unread == 0
                        ? 'You\'re all caught up'
                        : '$unread unread · Mabalacat City',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              PressableScale(
                onTap: () =>
                    readAlerts.value = kAlerts.map((a) => a.id).toSet(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'Mark all read',
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              SelectChip(
                label: 'All  ${kAlerts.length}',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final cat in AlertCategory.values) ...[
                const SizedBox(width: 8),
                SelectChip(
                  label:
                      '${cat.label}  ${kAlerts.where((a) => a.category == cat).length}',
                  icon: cat.icon,
                  selected: _filter == cat,
                  onTap: () => setState(() => _filter = cat),
                ),
              ],
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No notifications here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ),
        if (today.isNotEmpty) ...[
          const SizedBox(height: 14),
          const FieldLabel('Today'),
          _group(c, today, read),
        ],
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: 14),
          const FieldLabel('Earlier'),
          _group(c, earlier, read),
        ],
      ],
    );
  }

  // A group of alerts as one well, thin lines between them.
  Widget _group(AppColors c, List<AppAlert> alerts, Set<String> read) {
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            _row(c, alerts[i], unread: !read.contains(alerts[i].id)),
          ],
        ],
      ),
    );
  }

  // One alert: category tile, title + time, summary, severity and area.
  Widget _row(AppColors c, AppAlert a, {required bool unread}) {
    final color = a.severity.color;
    final b = myBarangay.value;
    final mine = b != null && a.area.endsWith(b);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _read(a),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(a.category.icon, color, size: 36, squircle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: kBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo(a.ago),
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      a.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          a.severity.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '  ·  ${a.area}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 8),
                          StatusPill('Your area', c.accent),
                        ],
                      ],
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

/// Everything about one alert: severity, title, where/when/who, details,
/// what to do, and a photo of the area when there is one.
class _AlertDetails extends StatelessWidget {
  final AppAlert alert;
  final VoidCallback onViewMap;
  const _AlertDetails({required this.alert, required this.onViewMap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final a = alert;
    final color = a.severity.color;
    final photo = kAreaPhotos[a.area];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Severity as a colored dot and words, like in the list.
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '${a.severity.label} severity · ${a.category.label}',
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          a.title,
          style: TextStyle(
            fontFamily: kDisplayFont,
            color: c.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _meta(c, CupertinoIcons.placemark, a.area),
            _meta(c, CupertinoIcons.clock, timeAgo(a.ago)),
            _meta(c, CupertinoIcons.checkmark_seal, a.source),
          ],
        ),
        if (photo != null) ...[
          const SizedBox(height: 18),
          LocalPhotoView(photo, height: 190, radius: 16),
          const SizedBox(height: 6),
          Text(
            'Photo of the area, not of the current flood.',
            style: TextStyle(color: c.textSecondary, fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          a.details,
          style: TextStyle(color: c.textPrimary, fontSize: 14.5, height: 1.6),
        ),
        const SizedBox(height: 20),
        const FieldLabel('What to do'),
        for (var i = 0; i < a.actions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      a.actions[i],
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'View on map',
          icon: CupertinoIcons.map_fill,
          onPressed: onViewMap,
        ),
      ],
    );
  }

  Widget _meta(AppColors c, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
      ],
    );
  }
}
