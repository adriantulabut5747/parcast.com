import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'home_shell.dart';

/// ============================================================
/// ALERTS TAB — filterable alert feed with details
/// ============================================================
class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});
  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  AlertCategory? _filter; // null = all

  // The alerts to show for the selected filter chip. `.where(...)` keeps
  // only the items for which the check is true (like a filter in Excel).
  List<AppAlert> get _filtered => _filter == null
      ? kAlerts
      : kAlerts.where((a) => a.category == _filter).toList();

  // `{...readAlerts.value, a.id}` = a NEW set with all the old ids plus
  // this one (the `...` "spreads" the old set's items into the new one).
  // It has to be a new set, not .add(), or the listeners (bell badge, this
  // tab) aren't told about the change. See readAlerts in demo_data.dart.
  void _markRead(AppAlert a) => readAlerts.value = {...readAlerts.value, a.id};

  // Desktop only: the alert shown in the right-hand panel.
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Desktop: list on the left, the chosen alert on the right (like an
    // email inbox). Phones and tablets: one list; tapping opens a sheet.
    final desktop = screenSizeOf(context) == ScreenSize.desktop;
    // The whole list rebuilds whenever an alert is marked read, so the
    // unread dots, the counter, and the red banner stay up to date.
    // `read` is the current set of read alert ids.
    return ValueListenableBuilder<Set<String>>(
      valueListenable: readAlerts,
      builder: (context, read, _) {
        final items = _filtered;
        // Unread High alerts, from ALL categories (ignores the filter).
        // The first one is shown in the red banner at the top.
        final critical = kAlerts
            .where((a) => a.severity == RiskLevel.high && !read.contains(a.id))
            .toList();
        final top = [
          _header(c),
          const SizedBox(height: 16),
          if (critical.isNotEmpty && !desktop) ...[
            FadeSlideIn(child: _criticalBanner(context, critical.first)),
            const SizedBox(height: 16),
          ],
          _chips(),
          const SizedBox(height: 8),
        ];
        if (desktop) return _desktop(context, c, top, items, read);
        // Split into "Today" (less than 24 h old) and "Earlier".
        final today = items.where((a) => a.ago.inHours < 24).toList();
        final earlier = items.where((a) => a.ago.inHours >= 24).toList();
        return ListView(
          padding: pagePadding(context),
          children: [
            ...top,
            if (items.isEmpty) _empty(c),
            if (today.isNotEmpty) ...[
              const SizedBox(height: 12),
              const FieldLabel('Today'),
              FadeSlideIn(child: _alertList(context, c, today, read)),
            ],
            if (earlier.isNotEmpty) ...[
              const SizedBox(height: 12),
              const FieldLabel('Earlier'),
              _alertList(context, c, earlier, read),
            ],
          ],
        );
      },
    );
  }

  Widget _desktop(
    BuildContext context,
    AppColors c,
    List<Widget> top,
    List<AppAlert> items,
    Set<String> read,
  ) {
    final pad = pagePadding(context);
    // The selected alert, or the first one in the list if none is picked
    // yet (or the picked one is hidden by the filter).
    final selected =
        items.where((a) => a.id == _selectedId).firstOrNull ??
        items.firstOrNull;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...top,
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 420,
                  child: items.isEmpty
                      ? _empty(c)
                      : SingleChildScrollView(
                          child: _alertList(
                            context,
                            c,
                            items,
                            read,
                            selectedId: selected?.id,
                          ),
                        ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: selected == null
                      ? const SizedBox.shrink()
                      : AppCard(
                          padding: EdgeInsets.zero,
                          child: SingleChildScrollView(
                            // A new key per alert resets the scroll to the
                            // top when another alert is picked.
                            key: ValueKey(selected.id),
                            padding: const EdgeInsets.all(32),
                            child: _AlertDetails(
                              alert: selected,
                              onViewMap: () =>
                                  HomeShell.of(context)?.switchTab(1),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppColors c) {
    final unread = unreadAlertCount;
    return PageHeader(
      'Alerts',
      subtitle: unread == 0
          ? 'You\'re all caught up'
          : '$unread unread · Mabalacat City',
      trailing: unread == 0
          ? null
          : TextButton.icon(
              onPressed: () =>
                  readAlerts.value = kAlerts.map((a) => a.id).toSet(),
              icon: Icon(
                CupertinoIcons.checkmark_alt_circle,
                size: 18,
                color: c.accent,
              ),
              label: Text(
                'Mark all read',
                style: TextStyle(color: c.accent, fontWeight: FontWeight.w700),
              ),
            ),
    );
  }

  Widget _chips() {
    return SizedBox(
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
    );
  }

  // Phones: the newest unread High alert, pinned above the list. A plain
  // card with a red edge and a warning icon: serious, but not shouting.
  Widget _criticalBanner(BuildContext context, AppAlert a) {
    final c = AppColors(context);
    return AppCard(
      onTap: () => _openAlert(context, a),
      borderColor: kDanger.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: kDanger,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  a.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right, color: c.textSecondary),
        ],
      ),
    );
  }

  // A group of alerts as one card, with thin lines between them (like an
  // email inbox). [selectedId] (desktop) is the alert being read.
  Widget _alertList(
    BuildContext context,
    AppColors c,
    List<AppAlert> alerts,
    Set<String> read, {
    String? selectedId,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            _alertRow(
              context,
              c,
              alerts[i],
              unread: !read.contains(alerts[i].id),
              selected: alerts[i].id == selectedId,
            ),
          ],
        ],
      ),
    );
  }

  // One alert: title and time, the summary, then severity and area.
  // Plain text on purpose: the only color is the small severity dot.
  Widget _alertRow(
    BuildContext context,
    AppColors c,
    AppAlert a, {
    required bool unread,
    required bool selected,
  }) {
    final color = a.severity.color;
    return Material(
      // The alert being read (desktop) gets a soft blue background.
      color: selected
          ? kBlue.withValues(alpha: c.isDark ? 0.14 : 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          // Desktop: show it in the right-hand panel. Otherwise: a sheet.
          if (screenSizeOf(context) == ScreenSize.desktop) {
            _markRead(a);
            setState(() => _selectedId = a.id);
          } else {
            _openAlert(context, a);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                        fontSize: 14.5,
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
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
                  const SizedBox(width: 10),
                  Text(
                    timeAgo(a.ago),
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                a.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    a.severity.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '  ·  ${a.area}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          IconBadge(CupertinoIcons.bell_slash, c.textSecondary, size: 72),
          const SizedBox(height: 14),
          Text(
            'No alerts here',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We\'ll let you know when something comes up.',
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  void _openAlert(BuildContext context, AppAlert a) {
    _markRead(a);
    showAppSheet(
      context,
      builder: (sheet) => _AlertDetails(
        alert: a,
        onViewMap: () {
          Navigator.of(sheet).pop();
          HomeShell.of(context)?.switchTab(1);
        },
        onClose: () => Navigator.of(sheet).pop(),
      ),
    );
  }
}

/// Everything about one alert: severity, title, where/when/who, details,
/// what to do, and a photo of the area when there is one. Shown in a
/// sheet (phones), a popup (tablets), or the right-hand panel (desktop).
class _AlertDetails extends StatelessWidget {
  final AppAlert alert;
  final VoidCallback onViewMap;
  final VoidCallback? onClose;
  const _AlertDetails({
    required this.alert,
    required this.onViewMap,
    this.onClose,
  });

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
        if (onClose != null) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: onClose,
              child: Text('Close', style: TextStyle(color: c.textSecondary)),
            ),
          ),
        ],
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
