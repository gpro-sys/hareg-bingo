library;

import 'package:flutter/material.dart';

import 'bingo_card.dart';

/// Single called ball, e.g. `"B 7"`, `"N 42"`.
@immutable
class BingoBall {
  const BingoBall({required this.letter, required this.number})
      : assert(number >= 1 && number <= 75);

  const BingoBall.fromColumnAndValue(this.letter, int value)
      : number = value,
        assert(value >= 1 && value <= 75);

  final BingoLetter letter;
  final int number;

  /// `"B7"`, short code used by the caller bar.
  String get shortCode => '${letter.label}$number';

  /// `"B 7"`, user facing label.
  String get displayLabel => '${letter.label} $number';

  @override
  String toString() => 'BingoBall(${letter.label}$number)';

  @override
  bool operator ==(Object other) =>
      other is BingoBall &&
      other.letter == letter &&
      other.number == number;

  @override
  int get hashCode => Object.hash(letter, number);
}

/// Numeric pool of a [BingoLetter]: 15 consecutive values 1..75.
int poolLow(BingoLetter letter) => letter.index * 15 + 1;
int poolHigh(BingoLetter letter) => letter.index * 15 + 15;

/// Colour palette mapped to the BINGO letters (used by [BingoBallWidget]).
Color ballColor(BingoLetter letter) {
  switch (letter) {
    case BingoLetter.b:
      return const Color(0xFF1E63D0);
    case BingoLetter.i:
      return const Color(0xFF6B43C4);
    case BingoLetter.n:
      return const Color(0xFF00897B);
    case BingoLetter.g:
      return const Color(0xFF2E7D32);
    case BingoLetter.o:
      return const Color(0xFFE65100);
  }
}

/// Comparison helper used by `.indexOf` / sets.
int ballCompare(BingoBall a, BingoBall b) {
  if (a.letter == b.letter) {
    return a.number.compareTo(b.number);
  }
  return a.letter.index.compareTo(b.letter.index);
}
