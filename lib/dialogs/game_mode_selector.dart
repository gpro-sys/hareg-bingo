/// Bottom sheet listing every win mode of the reference application.
library;

import 'package:flutter/material.dart';

import '../logic/game_engine.dart';

/// Sentinel for the `No game` state in the selector result.
const int kNoGameMode = -1;

/// Opens the game-type sheet and pops with:
/// * an index into [GameMode.values], or
/// * [kNoGameMode] when the user chooses `No game`, or
/// * null when dismissed without a selection (no change).
Future<int?> showGameModeSelector(
  BuildContext context, {
  required int currentIndex,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => _GameModeSelectorSheet(
      currentIndex: currentIndex,
    ),
  );
}

class _GameModeSelectorSheet extends StatelessWidget {
  const _GameModeSelectorSheet({required this.currentIndex});

  final int currentIndex;

  void _select(BuildContext context, int value) {
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: GameMode.values.length + 1,
        itemBuilder: (BuildContext context, int index) {
          // Slot 0 = clear the game type.
          if (index == 0) {
            final bool selected = currentIndex == kNoGameMode;
            return ListTile(
              leading: Icon(
                Icons.block_outlined,
                color: selected ? scheme.primary : scheme.outline,
              ),
              title: const Text('No game'),
              trailing:
                  selected ? Icon(Icons.check_outlined, color: scheme.primary) : null,
              onTap: () => _select(context, kNoGameMode),
            );
          }
          final GameMode mode = GameMode.values[index - 1];
          final bool selected = index - 1 == currentIndex;
          return ListTile(
            leading: Icon(
              Icons.emoji_events_outlined,
              color: selected ? scheme.primary : scheme.outline,
            ),
            title: Text(mode.label),
            trailing:
                selected ? Icon(Icons.check_outlined, color: scheme.primary) : null,
            onTap: () => _select(context, index - 1),
          );
        },
      ),
    );
  }
}
