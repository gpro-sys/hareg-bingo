/// Win-pattern evaluation for the canonical 25-cell bingo grid.
///
/// Grid layout (index -> row-major position, `12` is the FREE centre):
///
/// ```text
///  [  0  1  2  3  4 ]
///  [  5  6  7  8  9 ]
///  [ 10 11 12 13 14 ]
///  [ 15 16 17 18 19 ]
///  [ 20 21 22 23 24 ]
/// ```
library;

import '../models/bingo_card.dart';

/// Every win mode of the reference application, in display order.
enum GameMode {
  horizontalAny,
  horizontalTouchingFree,
  horizontalNotTouchingFree,
  verticalAny,
  verticalTouchingFree,
  verticalNotTouchingFree,
  squaresAny,
  squaresTouchingFree,
  squaresNotTouchingFree,
  rectanglesAny,
  rectanglesTouchingFree,
  rectanglesNotTouchingFree,
  diagonal,
  fourCorners,
  allLines,
  fullHouse,
}

extension GameModeLabelX on GameMode {
  /// Exact label used by the game-type picker. The `- Touching Free` /
  /// `- Not Touching Free` variants say whether the winning pattern must /
  /// must not contain the FREE centre cell.
  String get label => switch (this) {
        GameMode.horizontalAny => 'Horizontal - Any',
        GameMode.horizontalTouchingFree => 'Horizontal - Touching Free',
        GameMode.horizontalNotTouchingFree => 'Horizontal - Not Touching Free',
        GameMode.verticalAny => 'Vertical - Any',
        GameMode.verticalTouchingFree => 'Vertical - Touching Free',
        GameMode.verticalNotTouchingFree => 'Vertical - Not Touching Free',
        GameMode.squaresAny => 'Squares - Any',
        GameMode.squaresTouchingFree => 'Squares - Touching Free',
        GameMode.squaresNotTouchingFree => 'Squares - Not Touching Free',
        GameMode.rectanglesAny => 'Rectangles - Any',
        GameMode.rectanglesTouchingFree => 'Rectangles - Touching Free',
        GameMode.rectanglesNotTouchingFree => 'Rectangles - Not Touching Free',
        GameMode.diagonal => 'Diagonal',
        GameMode.fourCorners => 'Four Corners',
        GameMode.allLines => 'All Lines',
        GameMode.fullHouse => 'Full House',
      };
}

/// Static pattern tables for every win mode of the 5x5 grid.
class GamePatternChecks {
  const GamePatternChecks._();

  /// Index of the FREE centre cell.
  static const int freeCellIndex = BingoCard.freeCellIndex;

  /// The five horizontal rows.
  static const List<List<int>> rows = <List<int>>[
    <int>[0, 1, 2, 3, 4],
    <int>[5, 6, 7, 8, 9],
    <int>[10, 11, freeCellIndex, 13, 14],
    <int>[15, 16, 17, 18, 19],
    <int>[20, 21, 22, 23, 24],
  ];

  /// The five vertical columns; column 2 hosts the FREE centre.
  static const List<List<int>> columns = <List<int>>[
    <int>[0, 5, 10, 15, 20],
    <int>[1, 6, 11, 16, 21],
    <int>[2, 7, freeCellIndex, 17, 22],
    <int>[3, 8, 13, 18, 23],
    <int>[4, 9, 14, 19, 24],
  ];

  /// Every 2x2 block, anchored top-left.
  static const List<List<int>> squares = <List<int>>[
    <int>[0, 1, 5, 6],
    <int>[1, 2, 6, 7],
    <int>[2, 3, 7, 8],
    <int>[3, 4, 8, 9],
    <int>[5, 6, 10, 11],
    <int>[6, 7, 11, 12],
    <int>[7, 8, 12, 13],
    <int>[8, 9, 13, 14],
    <int>[10, 11, 15, 16],
    <int>[11, 12, 16, 17],
    <int>[12, 13, 17, 18],
    <int>[13, 14, 18, 19],
    <int>[15, 16, 20, 21],
    <int>[16, 17, 21, 22],
    <int>[17, 18, 22, 23],
    <int>[18, 19, 23, 24],
  ];

  /// Every 3-wide x 2-tall (first twelve) and 2-wide x 3-tall (last twelve)
  /// block, anchored top-left.
  static const List<List<int>> rectangles = <List<int>>[
    <int>[0, 1, 2, 5, 6, 7],
    <int>[1, 2, 3, 6, 7, 8],
    <int>[2, 3, 4, 7, 8, 9],
    <int>[5, 6, 7, 10, 11, 12],
    <int>[6, 7, 8, 11, 12, 13],
    <int>[7, 8, 9, 12, 13, 14],
    <int>[10, 11, 12, 15, 16, 17],
    <int>[11, 12, 13, 16, 17, 18],
    <int>[12, 13, 14, 17, 18, 19],
    <int>[15, 16, 17, 20, 21, 22],
    <int>[16, 17, 18, 21, 22, 23],
    <int>[17, 18, 19, 22, 23, 24],
    <int>[0, 1, 5, 6, 10, 11],
    <int>[1, 2, 6, 7, 11, 12],
    <int>[2, 3, 7, 8, 12, 13],
    <int>[3, 4, 8, 9, 13, 14],
    <int>[5, 6, 10, 11, 15, 16],
    <int>[6, 7, 11, 12, 16, 17],
    <int>[7, 8, 12, 13, 17, 18],
    <int>[8, 9, 13, 14, 18, 19],
    <int>[10, 11, 15, 16, 20, 21],
    <int>[11, 12, 16, 17, 21, 22],
    <int>[12, 13, 17, 18, 22, 23],
    <int>[13, 14, 18, 19, 23, 24],
  ];

  /// The two diagonals; both pass through the FREE centre.
  static const List<List<int>> diagonals = <List<int>>[
    <int>[0, 6, freeCellIndex, 18, 24],
    <int>[4, 8, freeCellIndex, 16, 20],
  ];

  /// The four corners.
  static const List<int> fourCorners = <int>[0, 4, 20, 24];

  /// Every cell of the grid, FREE centre included. Full-grid modes require
  /// the caller's marked list to pre-mark cell 12 (the app always does).
  static const List<int> everyCell = <int>[
    0, 1, 2, 3, 4, //
    5, 6, 7, 8, 9, //
    10, 11, 12, 13, 14, //
    15, 16, 17, 18, 19, //
    20, 21, 22, 23, 24, //
  ];

  /// Whether [cells] includes the FREE centre cell.
  static bool touchesFree(List<int> cells) => cells.contains(freeCellIndex);
}

/// Outcome of [GameEngine.check] for one card.
class WinCheckResult {
  const WinCheckResult({
    required this.mode,
    required this.hasWin,
    required this.winningCells,
    required this.kindLabel,
  });

  final GameMode mode;
  final bool hasWin;

  /// Cells of the first completed pattern; empty when no win.
  final List<int> winningCells;

  /// Display label of [mode] (e.g. `Horizontal - Any`).
  final String kindLabel;

  @override
  String toString() =>
      'WinCheckResult(${mode.name}: ${hasWin ? 'WIN' : 'no win'}, '
      '${winningCells.length} winning cells)';
}

/// Win-pattern evaluation engine.
class GameEngine {
  const GameEngine._();

  /// Whether every cell of [pattern] is marked. `marked` must be a 25-cell
  /// grid state; the caller normally pre-marks the FREE centre.
  static bool _complete(List<int> pattern, List<bool> marked) {
    if (marked.length < BingoCard.cellCount) {
      throw ArgumentError.value(marked, 'marked', 'length must be 25');
    }
    for (final int cell in pattern) {
      if (!marked[cell]) {
        return false;
      }
    }
    return true;
  }

  /// Candidate patterns for [mode]; full-grid modes are handled directly.
  static List<List<int>> _candidatesFor(GameMode mode) => switch (mode) {
        GameMode.horizontalAny => GamePatternChecks.rows,
        GameMode.horizontalTouchingFree => <List<int>>[
            GamePatternChecks.rows[2],
          ],
        GameMode.horizontalNotTouchingFree => <List<int>>[
            GamePatternChecks.rows[0],
            GamePatternChecks.rows[1],
            GamePatternChecks.rows[3],
            GamePatternChecks.rows[4],
          ],
        GameMode.verticalAny => GamePatternChecks.columns,
        GameMode.verticalTouchingFree => <List<int>>[
            GamePatternChecks.columns[2],
          ],
        GameMode.verticalNotTouchingFree => <List<int>>[
            GamePatternChecks.columns[0],
            GamePatternChecks.columns[1],
            GamePatternChecks.columns[3],
            GamePatternChecks.columns[4],
          ],
        GameMode.squaresAny => GamePatternChecks.squares,
        GameMode.squaresTouchingFree => GamePatternChecks.squares
            .where(GamePatternChecks.touchesFree)
            .toList(),
        GameMode.squaresNotTouchingFree => GamePatternChecks.squares
            .where((List<int> cells) => !GamePatternChecks.touchesFree(cells))
            .toList(),
        GameMode.rectanglesAny => GamePatternChecks.rectangles,
        GameMode.rectanglesTouchingFree => GamePatternChecks.rectangles
            .where(GamePatternChecks.touchesFree)
            .toList(),
        GameMode.rectanglesNotTouchingFree => GamePatternChecks.rectangles
            .where((List<int> cells) => !GamePatternChecks.touchesFree(cells))
            .toList(),
        GameMode.diagonal => GamePatternChecks.diagonals,
        GameMode.fourCorners => <List<int>>[GamePatternChecks.fourCorners],
        // Full-grid modes are evaluated without a candidate list.
        GameMode.allLines => const <List<int>>[],
        GameMode.fullHouse => const <List<int>>[],
      };

  /// Whether every row and every column is complete (== every cell marked).
  static bool _allLinesComplete(List<bool> marked) {
    for (final List<int> row in GamePatternChecks.rows) {
      if (!_complete(row, marked)) {
        return false;
      }
    }
    for (final List<int> column in GamePatternChecks.columns) {
      if (!_complete(column, marked)) {
        return false;
      }
    }
    return true;
  }

  /// True when [mode] is already won on the [marked] grid.
  static bool evaluate(GameMode mode, {required List<bool> marked}) {
    if (mode == GameMode.allLines) {
      return _allLinesComplete(marked);
    }
    if (mode == GameMode.fullHouse) {
      return _complete(GamePatternChecks.everyCell, marked);
    }
    for (final List<int> pattern in _candidatesFor(mode)) {
      if (_complete(pattern, marked)) {
        return true;
      }
    }
    return false;
  }

  /// Evaluate [mode] and describe the win (used to highlight winning cells).
  static WinCheckResult check(GameMode mode, {required List<bool> marked}) {
    if (mode == GameMode.allLines) {
      return _result(mode, _allLinesComplete(marked));
    }
    if (mode == GameMode.fullHouse) {
      return _result(mode, _complete(GamePatternChecks.everyCell, marked));
    }
    for (final List<int> pattern in _candidatesFor(mode)) {
      if (_complete(pattern, marked)) {
        return WinCheckResult(
          mode: mode,
          hasWin: true,
          winningCells: List<int>.unmodifiable(pattern),
          kindLabel: mode.label,
        );
      }
    }
    return _result(mode, false);
  }

  static WinCheckResult _result(GameMode mode, bool win) {
    return WinCheckResult(
      mode: mode,
      hasWin: win,
      winningCells: win
          ? List<int>.unmodifiable(GamePatternChecks.everyCell)
          : const <int>[],
      kindLabel: mode.label,
    );
  }
}
