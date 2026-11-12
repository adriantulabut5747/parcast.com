import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../data/demo_data.dart';
import '../screens/account.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Thumbs up/down on a flood pin. One vote per user, like Facebook: tap
/// the same thumb again to take it back, or the other one to switch.
/// Guests get a "log in" popup instead.
class VoteBar extends StatelessWidget {
  final FloodZone zone;
  // false: just the two buttons (the Home feed has its own layout).
  final bool showQuestion;
  const VoteBar({required this.zone, this.showQuestion = true, super.key});

  void _tap(BuildContext context, Vote vote) {
    if (isGuest) {
      showLoginRequired(context, action: 'vote');
      return;
    }
    final votes = {...myVotes.value};
    if (votes[zone.barangay] == vote) {
      votes.remove(zone.barangay);
    } else {
      votes[zone.barangay] = vote;
    }
    myVotes.value = votes;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Rebuilds only this bar (not the whole sheet) when a vote changes.
    return ValueListenableBuilder(
      valueListenable: myVotes,
      builder: (context, votes, _) {
        final mine = votes[zone.barangay];
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
              zone.upVotes + (mine == Vote.up ? 1 : 0),
              kSafe,
              mine == Vote.up,
              () => _tap(context, Vote.up),
            ),
            const SizedBox(width: 8),
            _button(
              c,
              CupertinoIcons.hand_thumbsdown_fill,
              'Not helpful',
              zone.downVotes + (mine == Vote.down ? 1 : 0),
              kDanger,
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
