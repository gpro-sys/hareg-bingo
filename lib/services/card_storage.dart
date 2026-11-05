/// Loading and persistence of the bingo card library plus session state.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bingo_ball.dart';
import '../models/bingo_card.dart';

/// Path of the pre-generated card asset shipped inside the APK.
const String kPregeneratedAssetPath = 'assets/data/bingo_cards.json';

/// Decodes the shipped `.hidden_cards/bingo_cards.json` asset.
///
/// Each entry is `{"id":1,"cartela_no":1,"bingo_numbers":[24 values]}` where
/// the values are the flat row-major grid with the FREE centre omitted.
class CardLibraryLoader {
  const CardLibraryLoader._();

  /// Loads and decodes the whole pre-generated library (20,000 cards).
  static Future<List<BingoCard>> loadPregenerated() async {
    final String raw = await rootBundle.loadString(kPregeneratedAssetPath);
    return parsePregenerated(raw);
  }

  /// Deserialises the asset payload; kept static to allow reuse in tests.
  static List<BingoCard> parsePregenerated(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException(
        'bingo_cards.json must be a JSON array of cards',
      );
    }
    return <BingoCard>[
      for (final dynamic entry in decoded)
        BingoCard.fromJson(entry as Map<String, dynamic>),
    ];
  }
}

/// SharedPreferences-backed persistence for the whole app state.
///
/// Keys mirror the reference application where its names were observable
/// (`qr_unlocked`); the remaining keys follow snake_case as in the original.
class CardStorage {
  const CardStorage._();

  static SharedPreferences _prefs = _uninitialized();

  static const String kActiveCards = 'active_cards';
  static const String kCardMarks = 'card_marks';
  static const String kSelectedGameMode = 'selected_game_mode';
  static const String kCardNumberFontSize = 'card_number_font_size';
  static const String kMarkingColor = 'marking_color';
  static const String kQrUnlocked = 'qr_unlocked';
  static const String kCalledBalls = 'called_balls';
  static const String kSortConditions = 'sort_conditions';

  /// Default card-number font size used when nothing was saved.
  static const double defaultCardNumberFontSize = 18.0;

  /// Default marking colour (material red).
  static const int defaultMarkingColorValue = 0xFFE53935;

  /// Marker,-1 for the game-type selector meaning `No game`.
  static const int noGameModeIndex = -1;

  static SharedPreferences _uninitialized() {
    throw StateError('CardStorage.setup() has not completed yet');
  }

  /// Await once from `main()` before the first synchronous read.
  static Future<void> setup() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ----------------------------- Active cards -----------------------------

  /// Saved cards as asset-layout map entries (24-value arrays).
  static List<Map<String, dynamic>> loadActiveCardsRaw() {
    final String? raw = _prefs.getString(kActiveCards);
    if (raw == null) {
      return const <Map<String, dynamic>>[];
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return const <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[
      for (final dynamic entry in decoded)
        Map<String, dynamic>.from(entry as Map<dynamic, dynamic>),
    ];
  }

  static Future<void> saveActiveCards(List<BingoCard> cards) async {
    if (cards.isEmpty) {
      await _prefs.remove(kActiveCards);
      return;
    }
    await _prefs.setString(
      kActiveCards,
      jsonEncode(<Map<String, dynamic>>[
        for (final BingoCard card in cards) card.toJson(),
      ]),
    );
  }

  // ------------------------------- Marks ----------------------------------

  /// Cartela number -> set of marked cell indexes.
  static Map<int, Set<int>> loadCardMarks() {
    final String? raw = _prefs.getString(kCardMarks);
    if (raw == null) {
      return const <int, Set<int>>{};
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<dynamic, dynamic>) {
      return const <int, Set<int>>{};
    }
    return <int, Set<int>>{
      for (final MapEntry<dynamic, dynamic> entry in decoded.entries)
        int.tryParse(entry.key! as String) ?? 0:
            <int>{
          for (final dynamic cell in entry.value as List<dynamic>)
            cell as int,
        },
    };
  }

  static Future<void> saveCardMarks(Map<int, Set<int>> marks) async {
    if (marks.isEmpty) {
      await _prefs.remove(kCardMarks);
      return;
    }
    await _prefs.setString(
      kCardMarks,
      jsonEncode(<String, List<int>>{
        for (final MapEntry<int, Set<int>> entry in marks.entries)
          '${entry.key}': entry.value.toList(growable: false),
      }),
    );
  }

  // ------------------------------ Session ---------------------------------

  static int loadSelectedGameMode() =>
      _prefs.getInt(kSelectedGameMode) ?? noGameModeIndex;

  static Future<void> saveSelectedGameMode(int index) async {
    await _prefs.setInt(kSelectedGameMode, index);
  }

  static Future<void> clearSelectedGameMode() async {
    await _prefs.remove(kSelectedGameMode);
  }

  static double loadCardNumberFontSize() =>
      _prefs.getDouble(kCardNumberFontSize) ?? defaultCardNumberFontSize;

  static Future<void> saveCardNumberFontSize(double size) async {
    await _prefs.setDouble(kCardNumberFontSize, size);
  }

  static int loadMarkingColor() =>
      _prefs.getInt(kMarkingColor) ?? defaultMarkingColorValue;

  static Future<void> saveMarkingColor(int value) async {
    await _prefs.setInt(kMarkingColor, value);
  }

  static bool loadQrUnlocked() => _prefs.getBool(kQrUnlocked) ?? false;

  static Future<void> saveQrUnlocked(bool unlocked) async {
    await _prefs.setBool(kQrUnlocked, unlocked);
  }

  static List<String> loadSortConditions() =>
      _prefs.getStringList(kSortConditions) ?? const <String>[];

  static Future<void> saveSortConditions(List<String> conditions) async {
    if (conditions.isEmpty) {
      await _prefs.remove(kSortConditions);
      return;
    }
    await _prefs.setStringList(kSortConditions, conditions);
  }

  /// Draw history as `[letterIndex, number]` pairs.
  static List<List<int>> loadCalledBalls() {
    final String? raw = _prefs.getString(kCalledBalls);
    if (raw == null) {
      return const <List<int>>[];
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return const <List<int>>[];
    }
    return <List<int>>[
      for (final dynamic pair in decoded)
        <int>[
          for (final dynamic v in pair as List<dynamic>) v as int,
        ],
    ];
  }

  static Future<void> saveCalledBalls(List<BingoBall> balls) async {
    if (balls.isEmpty) {
      await _prefs.remove(kCalledBalls);
      return;
    }
    await _prefs.setString(
      kCalledBalls,
      jsonEncode(<List<int>>[
        for (final BingoBall ball in balls)
          <int>[ball.letter.index, ball.number],
      ]),
    );
  }
}
