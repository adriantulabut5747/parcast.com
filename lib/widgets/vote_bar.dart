import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoActivityIndicator;

import '../data/demo_data.dart';
import '../services/auth.dart';
import '../screens/account.dart';
import '../services/reports.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Thumbs up/down on a flood pin. One vote per user, like Facebook: tap
/// the same thumb again to take it back, or the other one to switch.
/// Guests get a "log in" popup instead. A picked thumb is blue, not
/// green/red: those colors mean flood risk in this app.
/// Saved in `report_votes` (03_report_votes.sql); the numbers are the
/// database's counts, with the user's own tap shown straight away.
class VoteBar extends StatelessWidget {
  final FloodReport zone;
  // false: just the two buttons (the Home feed has its own layout).
  final bool showQuestion;
  const VoteBar({required this.zone, this.showQuestion = true, super.key});

  Future<void> _tap(BuildContext context, Vote vote) async {
    if (isGuest) {
      showLoginRequired(context, action: 'vote');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final old = myVotes.value[zone.key];
    final next = old == vote ? null : vote;
    _show(next);
    try {
      await saveVote(zone, old, next);
    } catch (_) {
      _show(old); // not saved: put the thumbs back as they were
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Your vote wasn't saved. Check your connection and try again.",
          ),
        ),
      );
    }
  }

  void _show(Vote? vote) {
    final votes = {...myVotes.value};
    if (vote == null) {
      votes.remove(zone.key);
    } else {
      votes[zone.key] = vote;
    }
    myVotes.value = votes;
  }

  // The database's count, minus the vote it has from this user, plus the
  // one on screen: the number moves on tap, before the save comes back.
  int _count(Vote side, int counted, Vote? mine) =>
      counted - (zone.myVote == side ? 1 : 0) + (mine == side ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Rebuilds only this bar (not the whole sheet) when a vote changes.
    return ValueListenableBuilder(
      valueListenable: myVotes,
      builder: (context, votes, _) {
        final mine = votes[zone.key];
        return Row(
          mainAxisSize: showQuestion ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (showQuestion)
              Expanded(
                child: Text(
                  'Was this report helpful?',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
              ),
            _button(
              c,
              CupertinoIcons.hand_thumbsup_fill,
              'Helpful',
              _count(Vote.up, zone.upVotes, mine),
              c.accent,
              mine == Vote.up,
              () => _tap(context, Vote.up),
            ),
            const SizedBox(width: 8),
            _button(
              c,
              CupertinoIcons.hand_thumbsdown_fill,
              'Not helpful',
              _count(Vote.down, zone.downVotes, mine),
              c.accent,
              mine == Vote.down,
              () => _tap(context, Vote.down),
            ),
          ],
        );
      },
    );
  }

  Widget _button(
    AppColors c,
    IconData icon,
    String tooltip,
    int count,
    Color color,
    bool selected,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? color : c.textSecondary),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? color : c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// On the user's own report, in place of the thumbs: asks, then deletes
/// the report and its photo (the database only lets owners and admins).
class DeleteReportButton extends StatefulWidget {
  final FloodReport report;
  const DeleteReportButton({required this.report, super.key});

  @override
  State<DeleteReportButton> createState() => _DeleteReportButtonState();
}

class _DeleteReportButtonState extends State<DeleteReportButton> {
  bool _busy = false;

  void _ask() {
    showAppSheet(
      context,
      builder: (sheet) {
        final c = AppColors(sheet);
        return Column(
          children: [
            const IconBadge(CupertinoIcons.trash_fill, kDanger, size: 60),
            const SizedBox(height: 14),
            Text(
              'Delete your report?',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'It disappears from the map and the feed for everyone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Delete',
              color: kDanger,
              onPressed: () {
                Navigator.of(sheet).pop();
                _delete();
              },
            ),
            const SizedBox(height: 6),
            SecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await deleteReport(widget.report);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't delete it. Check your connection and try again.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    if (_busy) return const CupertinoActivityIndicator();
    return Semantics(
      button: true,
      label: 'Delete your report',
      child: PressableScale(
        onTap: _ask,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(CupertinoIcons.trash, size: 18, color: c.textSecondary),
        ),
      ),
    );
  }
}
