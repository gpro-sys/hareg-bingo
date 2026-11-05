library;

import 'dart:math' as math;

import 'bingo_ball.dart';
import 'bingo_card.dart';

/// Lossless, self-identifying draw sequence walking the full 75-value pool.
///
/// The reference app draws without replacement so printing `Called lines`
/// never repeats a ball and eventually runs dry.
abstract class BingoDrawer {
  const BingoDrawer();

  factory BingoDrawer.standard({int? seed}) = _StandardBingoDrawer;

  /// Remaining (undrawn) balls for the [letter].
  List<int> remainingFor(BingoLetter letter);

  /// Draw the next ball, or `null` when every number has been called.
  BingoBall? drawNext();

  /// Reverse the most recent draw (used by an "Undo call" affordance).
  BingoBall? undoLast();

  /// Rebuilds drawer state from a persisted call history so `Undo`
  /// keeps working across app restarts.
  void preloadHistory(Iterable<BingoBall> history);

  /// Full draw history; persisted by the storage layer.
  List<BingoBall> get history;

  int get calledCount;
}

class _StandardBingoDrawer extends BingoDrawer {
  _StandardBingoDrawer({int? seed})
      : _rng = seed == null ? math.Random() : math.Random(seed);

  final math.Random _rng;
  final List<BingoBall> _history = <BingoBall>[];

  /// Letter -> values still in the bag. Kept sorted so remaining sets read
  /// naturally when inspected by callers.
  final Map<BingoLetter, List<int>> _bags =
      <BingoLetter, List<int>>{
    for (final BingoLetter letter in BingoLetter.values)
      letter: List<int>.generate(
        15,
        (int i) => poolLow(letter) + i,
        growable: true,
      ),
  };

  @override
  List<int> remainingFor(BingoLetter letter) =>
      List<int>.unmodifiable(_bags[letter] ?? const <int>[]);

  @override
  BingoBall? drawNext() {
    final BingoLetter letter =
        BingoLetter.values[_rng.nextInt(BingoLetter.values.length)];
    final List<int> bag = _bags[letter]!;
    if (bag.isEmpty) {
      // Pick any letter that still has values, preferring natural flow.
      for (final BingoLetter other in BingoLetter.values) {
        if (_bags[other]!.isNotEmpty) {
          return _drawFrom(other);
        }
      }
      return null;
    }
    return _drawFrom(letter);
  }

  BingoBall? _drawFrom(BingoLetter letter) {
    final List<int> bag = _bags[letter]!;
    if (bag.isEmpty) {
      return null;
    }
    final int pick = bag.removeAt(_rng.nextInt(bag.length));
    final BingoBall ball = BingoBall(letter: letter, number: pick);
    _history.add(ball);
    return ball;
  }

  @override
  BingoBall? undoLast() {
    if (_history.isEmpty) {
      return null;
    }
    final BingoBall ball = _history.removeLast();
    _bags[ball.letter]!.add(ball.number);
    _bags[ball.letter]!.sort();
    return ball;
  }

  @override
  void preloadHistory(Iterable<BingoBall> history) {
    for (final BingoBall ball in history) {
      final List<int>? bag = _bags[ball.letter];
      if (bag == null || !bag.remove(ball.number)) {
        // Unknown or duplicate persisted ball; skip rather than corrupt.
        continue;
      }
      _history.add(ball);
    }
  }

  @override
  List<BingoBall> get history =>
      List<BingoBall>.unmodifiable(_history);

  @override
  int get calledCount => _history.length;
}

/// Progress report shown in the drawer for a single card.
class CardProgress {
  const CardProgress({
    required this.card,
    required this.rewardTiers,
    required this.currentTier,
    required this.markedCount,
  });

  final BingoCard card;
  final List<int> rewardTiers;
  final int currentTier;
  final int markedCount;

  /// How many consecutive marked cells are needed before the card gets a
  /// star in the drawer (used by `_cardStatText` in the reference app).
  int get nextTier =>
      rewardTiers.where((int tier) => tier > currentTier).fold(
            rewardTiers.first,
            (int a, int b) => a <= b ? a : b,
          );
}
