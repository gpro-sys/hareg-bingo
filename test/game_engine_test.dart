import 'package:flutter_test/flutter_test.dart';
import 'package:hareg_bingo/logic/game_engine.dart';
import 'package:hareg_bingo/models/bingo_ball.dart';
import 'package:hareg_bingo/models/bingo_call.dart';
import 'package:hareg_bingo/models/bingo_card.dart';

void main() {
  group('GameEngine pattern checks', () {
    List<bool> markedCells(Set<int> indexes) {
      final m = List<bool>.filled(25, false);
      m[12] = true; // free
      for (final i in indexes) {
        m[i] = true;
      }
      return m;
    }

    test('row win detection for each mode', () {
      expect(GamePatternChecks.rows[2], contains(BingoCard.freeCellIndex));
      expect(
        GameEngine.evaluate(GameMode.horizontalAny,
            marked: markedCells({0, 1, 3, 4})),
        isFalse,
      );
      expect(
        GameEngine.evaluate(GameMode.horizontalAny, marked: markedCells({0, 1, 4})),
        isFalse,
      );
      // Row 0 all plus free.
      expect(
        GameEngine.evaluate(GameMode.horizontalAny,
            marked: markedCells({0, 1, 2, 3, 4})),
        isTrue,
      );
      // Row 2 (the free row) complete already on a fresh card, so
      // Not Touching Free only looks at rows 0,1,3,4.
      expect(
        GameEngine.evaluate(GameMode.horizontalNotTouchingFree,
            marked: markedCells({})),
        isFalse,
      );
      expect(
        GameEngine.evaluate(GameMode.horizontalNotTouchingFree,
            marked: markedCells({15, 16, 17, 18, 19})),
        isTrue,
      );
      // Vertical: column 2 contains the free slot.
      expect(
        GameEngine.evaluate(GameMode.verticalNotTouchingFree,
            marked: markedCells({0, 5, 10, 15, 20})),
        isTrue,
      );
      // Column 2 completes only when its four live numbers join the free cell.
      expect(
        GameEngine.evaluate(GameMode.verticalTouchingFree,
            marked: markedCells({2, 7, 17, 22})),
        isTrue,
      );
      expect(
        GameEngine.evaluate(GameMode.verticalTouchingFree, marked: markedCells({})),
        isFalse,
      );
    });

    test('squares and rectangles', () {
      // 2x2 block anchored top-left: cells 0,1,5,6.
      expect(
        GameEngine.evaluate(GameMode.squaresAny, marked: markedCells({0, 1, 5, 6})),
        isTrue,
      );
      expect(
        GameEngine.evaluate(
            GameMode.squaresNotTouchingFree, marked: markedCells({0, 1, 5, 6})),
        isTrue,
      );
      expect(
        GameEngine.evaluate(
            GameMode.squaresTouchingFree, marked: markedCells({0, 1, 5, 6})),
        isFalse,
      );
      // Block (1,1)-(2,2) touches free: indexes 6,7,11,12(free).
      expect(
        GameEngine.evaluate(
            GameMode.squaresTouchingFree, marked: markedCells({6, 7, 11})),
        isTrue,
      );
      // Rectangles: 2x3 anchored at (0,1) => indexes 1,2,3,6,7,8 (contains free 12? no)
      expect(
        GameEngine.evaluate(GameMode.rectanglesAny,
            marked: markedCells({1, 2, 3, 6, 7, 8})),
        isTrue,
      );
      expect(
        GameEngine.evaluate(
            GameMode.rectanglesNotTouchingFree,
            marked: markedCells({1, 2, 3, 6, 7, 8})),
        isTrue,
      );
      expect(
        GameEngine.evaluate(GameMode.rectanglesTouchingFree,
            marked: markedCells({1, 2, 3, 6, 7, 8})),
        isFalse,
      );
      // 2x3 anchored (2,0) -> rows 2..3, cols 0..2 -> indexes 10,11,12,15,16,17 -> touches free.
      expect(
        GameEngine.evaluate(GameMode.rectanglesTouchingFree,
            marked: markedCells({10, 11, 15, 16, 17})),
        isTrue,
      );
    });

    test('diagonal, corners, all lines, full house', () {
      // Dingbats diagonal (r == c) completes only with free centre filled:
      // cells {0,6,12,18,24}. Free is marked so index 6,0,18,24 needed.
      expect(
        GameEngine.evaluate(GameMode.diagonal,
            marked: markedCells({0, 6, 18, 24})),
        isTrue,
      );
      expect(
        GameEngine.evaluate(GameMode.fourCorners,
            marked: markedCells({0, 4, 20, 24})),
        isTrue,
      );
      expect(
        GameEngine.evaluate(GameMode.fourCorners, marked: markedCells({0, 4, 20})),
        isFalse,
      );
      final all = List<bool>.filled(25, true);
      expect(GameEngine.evaluate(GameMode.fullHouse, marked: all), isTrue);
      expect(
        GameEngine.evaluate(GameMode.allLines,
            marked: markedCells({
              0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14,
              15, 16, 17, 18, 19, 20, 21, 22, 23, 24
            })),
        isTrue,
      );
      expect(
        GameEngine.evaluate(GameMode.allLines,
            marked: markedCells({0, 1, 2, 3, 4})),
        isFalse,
      );
    });

    test('winningCells returns marked indexes used by highlight', () {
      final result = GameEngine.check(
        GameMode.horizontalAny,
        marked: markedCells({0, 1, 2, 3, 4}),
      );
      expect(result.hasWin, isTrue);
      expect(result.winningCells, containsAll(const <int>[0, 1, 2, 3, 4]));
      expect(result.kindLabel, 'Horizontal - Any');
    });
  });

  group('BingoDrawer', () {
    test('draws 75 unique balls then runs dry', () {
      final drawer = BingoDrawer.standard(seed: 42);
      final seen = <int>{};
      for (var i = 0; i < 75; i++) {
        final ball = drawer.drawNext();
        expect(ball, isNotNull);
        seen.add(ball!.number);
      }
      expect(seen.length, 75);
      expect(drawer.drawNext(), isNull);
      expect(drawer.undoLast(), isNotNull);
      expect(drawer.drawNext(), isNotNull);
    });
  });

  group('BingoCard', () {
    test('fromJson rebuilds the 25-cell grid', () {
      final card = BingoCard.fromJson(<String, dynamic>{
        'id': 1,
        'cartela_no': 1,
        'bingo_numbers': <int>[
          15, 18, 38, 48, 61, 11, 19, 33, 47, 75,
          1, 27, 58, 73, 14, 26, 32, 52, 68, 7,
          24, 35, 60, 65,
        ],
      });
      expect(card.numbers.length, 25);
      expect(card.numbers[12], BingoCard.freeCellValue);
      expect(card.cartelaNo, 1);
      expect(card.isFreeCell(12), isTrue);
      expect(card.letterForValue(1), BingoLetter.b);
      expect(card.letterForValue(75), BingoLetter.o);
      expect(card.letterForValue(0), isNull);
    });

    test('toJson round-trips', () {
      const original = <String, dynamic>{
        'id': 9,
        'cartela_no': 9,
        'bingo_numbers': <int>[1, 16, 31, 46, 61, 2, 17, 32, 47, 62, 3, 18,
          48, 63, 4, 19, 33, 49, 64, 5, 20, 34, 50, 65],
      };
      final card = BingoCard.fromJson(original);
      final back = card.toJson();
      expect(back['id'], 9);
      expect(back['cartela_no'], 9);
      expect((back['bingo_numbers'] as List<int>).length, 24);
      expect((back['bingo_numbers'] as List<int>).contains(0), isFalse);
    });
  });

  group('BingoBall', () {
    test('shortCode and displayLabel', () {
      const ball = BingoBall(letter: BingoLetter.n, number: 42);
      expect(ball.shortCode, 'N42');
      expect(ball.displayLabel, 'N 42');
    });
  });
}
