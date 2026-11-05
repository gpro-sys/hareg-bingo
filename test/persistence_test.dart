import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hareg_bingo/dialogs/add_card_dialog.dart';
import 'package:hareg_bingo/dialogs/qr_dialog.dart';
import 'package:hareg_bingo/models/bingo_ball.dart';
import 'package:hareg_bingo/models/bingo_call.dart';
import 'package:hareg_bingo/models/bingo_card.dart';
import 'package:hareg_bingo/services/card_storage.dart';

void main() {
  group('CardLibraryLoader', () {
    List<BingoCard>? cards;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      cards = await CardLibraryLoader.loadPregenerated();
    });

    test('loads the full pre-generated library', () {
      expect(cards, isNotNull);
      expect(cards!.length, 20000);
      expect(cards!.first.cartelaNo, 1);
      expect(cards!.last.cartelaNo, 20000);
    });

    test('every card carries the FREE centre and valid BINGO columns',
        () {
      final List<BingoCard> library = cards!;
      for (final BingoCard card in library) {
        expect(card.numbers, hasLength(25));
        expect(card.numbers[BingoCard.freeCellIndex],
            BingoCard.freeCellValue);
        for (int column = 0; column < 5; column++) {
          final List<int> cells = BingoCard.columnIndexes[column];
          final int low = column * 15 + 1;
          final List<int> values = <int>[
            for (final int cell in cells)
              if (!card.isFreeCell(cell)) card.numbers[cell],
          ];
          expect(values, hasLength(column == 2 ? 4 : 5));
          for (final int value in values) {
            expect(value, inInclusiveRange(low, low + 14),
                reason: 'card ${card.cartelaNo} column $column');
          }
        }
      }
    });

    test('numbers stay unique across the whole card', () {
      for (final BingoCard card in cards!) {
        expect(card.numbers.where((int v) => v != 0).toSet().length, 24);
      }
    });
  });

  group('BingoDrawer persistence helpers', () {
    test('preloadHistory removes drawn values from their bags', () {
      final BingoDrawer drawer = BingoDrawer.standard();
      const BingoBall ball = BingoBall(letter: BingoLetter.b, number: 7);
      drawer.preloadHistory(<BingoBall>[ball]);
      expect(drawer.history, contains(ball));
      expect(drawer.calledCount, 1);
      expect(drawer.remainingFor(BingoLetter.b), isNot(contains(7)));
      // Undo restores the value into the bag.
      expect(drawer.undoLast(), ball);
      expect(drawer.remainingFor(BingoLetter.b), contains(7));
    });
  });

  group('parseCartelaInput', () {
    test('single values, lists and ranges', () {
      expect(parseCartelaInput('5'), <int>[5]);
      expect(parseCartelaInput('3-9'), <int>[3, 4, 5, 6, 7, 8, 9]);
      expect(parseCartelaInput('12, 15, 20-22'), <int>[12, 15, 20, 21, 22]);
      expect(parseCartelaInput('7 8 9'), <int>[7, 8, 9]);
      expect(parseCartelaInput('5 5'), <int>[5]); // de-duplicated
      expect(parseCartelaInput(''), isNull);
      expect(parseCartelaInput('abc'), isNull);
      expect(parseCartelaInput('0'), isNull);
      expect(parseCartelaInput('20001'), isNull);
      expect(parseCartelaInput('9-3'), isNull);
    });
  });

  group('QR password gate', () {
    test('accepts only the exact password', () {
      expect(verifyQrPassword('2305'), isTrue);
      expect(verifyQrPassword('2306'), isFalse);
      expect(verifyQrPassword(''), isFalse);
      // The digest matches sha256("2305").
      expect(
        verifyQrPassword('2305'),
        isTrue,
        reason:
            'sha256(2305) == 9a5a48758da347f33bd37064cfbd05442ef005c85ae'
            '0ea4614740d5597316ed3',
      );
    });
  });

  group('asset layout round trip', () {
    test('toJson emits the 24-value asset payload', () {
      const Map<String, dynamic> raw = <String, dynamic>{
        'id': 401,
        'cartela_no': 401,
        'bingo_numbers': <int>[
          12, 20, 40, 56, 70, //
          3, 24, 38, 50, 68, //
          9, 19, 54, 66, 13, //
          22, 32, 60, 61, 2, //
          21, 41, 55, 71,
        ],
      };
      final Map<String, dynamic> back =
          jsonDecode(jsonEncode(BingoCard.fromJson(raw).toJson()))
              as Map<String, dynamic>;
      expect(back['id'], 401);
      expect(back['cartela_no'], 401);
      expect(back['bingo_numbers'], raw['bingo_numbers']);
    });
  });
}
