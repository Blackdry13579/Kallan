import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/level_utils.dart';
import '../../services/celebration_coordinator.dart';
import '../blocs/badge/badge_bloc.dart';
import '../blocs/badge/badge_event.dart';
import '../blocs/badge/badge_state.dart';
import '../blocs/deck/deck_bloc.dart';
import '../blocs/deck/deck_state.dart';
import '../blocs/quiz/quiz_bloc.dart';
import '../blocs/quiz/quiz_state.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_event.dart';
import '../blocs/user/user_state.dart';
import 'badge_unlock_popup.dart';
import 'level_up_popup.dart';

/// Écoute globalement montées de niveau et badges ; affiche les popups sur le navigateur racine.
class CelebrationListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const CelebrationListener({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<CelebrationListener> createState() => _CelebrationListenerState();
}

class _CelebrationListenerState extends State<CelebrationListener> {
  int? _lastKnownLevel;

  @override
  void initState() {
    super.initState();
    CelebrationCoordinator.navigatorKey = widget.navigatorKey;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<UserBloc, UserState>(
          listener: (context, state) {
            if (state is! UserLoaded) return;

            final points = state.profile['points'] as int? ?? 0;
            final currentLevel = LevelUtils.getLevelInfo(points).level;

            if (_lastKnownLevel != null && currentLevel > _lastKnownLevel!) {
              final levelInfo = LevelUtils.getLevelInfo(points);
              CelebrationCoordinator.queueOrRun(() {
                final ctx = CelebrationCoordinator.navigatorKey?.currentContext;
                if (ctx == null) return;
                LevelUpPopup.show(
                  ctx,
                  level: levelInfo.level,
                  title: levelInfo.title,
                  icon: levelInfo.icon,
                  pointsReward: 50,
                  flashcardsCount: state.stats['flashcardCount'] ?? 0,
                );
              });
            }
            _lastKnownLevel = currentLevel;
          },
        ),
        BlocListener<BadgeBloc, BadgeState>(
          listener: (context, state) {
            if (state is! BadgeJustUnlocked) return;
            context.read<UserBloc>().add(RefreshBadges());
            CelebrationCoordinator.queueOrRun(() {
              final ctx = CelebrationCoordinator.navigatorKey?.currentContext;
              if (ctx == null) return;
              BadgeUnlockPopup.show(
                ctx,
                label: state.label,
                emoji: state.emoji,
                imagePath: state.imagePath,
                color: state.color,
                reason: state.description,
              );
            });
          },
        ),
        BlocListener<DeckBloc, DeckState>(
          listener: (context, state) {
            if (state is DeckSaved) {
              context.read<BadgeBloc>().add(CheckNewBadges());
            }
          },
        ),
        BlocListener<QuizBloc, QuizState>(
          listener: (context, state) {
            if (state is QuizSubmitted) {
              context.read<BadgeBloc>().add(CheckNewBadges());
            }
          },
        ),
      ],
      child: widget.child,
    );
  }
}
