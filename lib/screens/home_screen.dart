/// Hareg Bingo frontend state shell.
library;

import 'package:flutter/material.dart';

import '../dialogs/add_card_dialog.dart';
import '../dialogs/confirm_dialogs.dart';
import '../dialogs/game_mode_selector.dart';
import '../dialogs/qr_dialog.dart';
import '../logic/game_engine.dart';
import '../models/bingo_ball.dart';
import '../models/bingo_call.dart';
import '../models/bingo_card.dart';
import '../services/card_storage.dart';
import '../widgets/ball_widget.dart';
import '../widgets/bingo_card_widget.dart';

/// Sorting conditions selectable in the Sorting Mode sheet; several may be
/// combined (applied in selection order).
enum SortCondition { cartelaNo, mostMarked, leastMarked, mostLinked }

extension SortConditionX on SortCondition {
  String get label => switch (this) {
        SortCondition.cartelaNo => 'Cartela No',
        SortCondition.mostMarked => 'Most Marked',
        SortCondition.leastMarked => 'Least Marked',
        SortCondition.mostLinked => 'Most Called',
      };

  String get shortCode => switch (this) {
        SortCondition.cartelaNo => 'CART',
        SortCondition.mostMarked => 'MARK',
        SortCondition.leastMarked => 'LMRK',
        SortCondition.mostLinked => 'LNKS',
      };
}

enum _MenuAction { fontSize, markingColor, deleteAll }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Newest fifteen balls shown as chips in the caller bar.
  static const int _maxRecentBalls = 12;

  static const double _minCardFontSize = 12.0;
  static const double _maxCardFontSize = 36.0;

  /// Colour candidates offered by the Marking Color sheet.
  static const List<int> _markingColorValues = <int>[
    0xFFE53935,
    0xFFD81B60,
    0xFFF9A825,
    0xFF43A047,
    0xFF00897B,
    0xFF1E88E5,
    0xFF3949AB,
    0xFF8E24AA,
  ];

  /// Full pre-generated library, loaded lazily on the first add.
  List<BingoCard>? _library;
  List<BingoCard> _cards = <BingoCard>[];

  /// Cartela number -> marked cell indexes (FREE centre included).
  final Map<int, Set<int>> _marks = <int, Set<int>>{};

  /// Cartela number -> completed pattern cells (gold highlight).
  final Map<int, List<int>> _winningCells = <int, List<int>>{};

  /// Cards whose current win was already announced.
  final Set<int> _announcedWinCartelas = <int>{};

  final Set<int> _calledNumbers = <int>{};
  final List<BingoBall> _recentBalls = <BingoBall>[];
  BingoBall? _currentBall;
  BingoDrawer _drawer = BingoDrawer.standard();

  /// `-1` mirrors the original `No game` state.
  int _selectedModeIndex = CardStorage.noGameModeIndex;

  Set<SortCondition> _sortConditions = <SortCondition>{};

  double _cardNumberFontSize = CardStorage.defaultCardNumberFontSize;
  Color _markingColor = const Color(CardStorage.defaultMarkingColorValue);
  bool _qrUnlocked = false;

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

  // ------------------------------ State load ------------------------------

  Future<void> _loadAppState() async {
    // Persisted cards (asset-layout 24-value arrays) rebuild the grid.
    final List<BingoCard> restoredCards =
        _parsePreGeneratedCards(CardStorage.loadActiveCardsRaw());
    final Map<int, Set<int>> savedMarks = CardStorage.loadCardMarks();
    final int modeIndex = CardStorage.loadSelectedGameMode();
    final double fontSize = CardStorage.loadCardNumberFontSize();
    final Color markingColor = Color(CardStorage.loadMarkingColor());
    final bool qrUnlocked = CardStorage.loadQrUnlocked();
    final List<String> sortNames = CardStorage.loadSortConditions();

    // Rebuild the caller's history; [BingoDrawer.preloadHistory] removes the
    // drawn values from their bags so undo keeps working after a restart.
    final List<BingoBall> history = <BingoBall>[
      for (final List<int> pair in CardStorage.loadCalledBalls())
        if (pair.length == 2 &&
            pair[0] >= 0 &&
            pair[0] < BingoLetter.values.length &&
            pair[1] >= 1 &&
            pair[1] <= 75)
          BingoBall(letter: BingoLetter.values[pair[0]], number: pair[1]),
    ];
    final BingoDrawer restoredDrawer = BingoDrawer.standard();
    restoredDrawer.preloadHistory(history);

    final Set<SortCondition> restoredSort = <SortCondition>{
      for (final String name in sortNames)
        if (_sortConditionByName(name) != null) _sortConditionByName(name)!,
    };

    if (!mounted) {
      return;
    }
    setState(() {
      _cards = restoredCards;
      _marks.clear();
      _marks.addAll(savedMarks);
      for (final BingoCard card in _cards) {
        _marks.putIfAbsent(
          card.cartelaNo,
          () => <int>{BingoCard.freeCellIndex},
        );
      }
      _drawer = restoredDrawer;
      _calledNumbers.addAll(<int>[for (final ball in history) ball.number]);
      _updateRecentCallerBalls(history);
      _currentBall = history.isEmpty ? null : history.last;
      _selectedModeIndex = modeIndex;
      _cardNumberFontSize = fontSize;
      _markingColor = markingColor;
      _qrUnlocked = qrUnlocked;
      _sortConditions = restoredSort;
    });
    _recomputeAllWins(silent: true);
  }

  /// Deserialises saved active cards. Failures surface exactly like the
  /// reference build: `Error parsing card {cartela_no}`.
  List<BingoCard> _parsePreGeneratedCards(List<Map<String, dynamic>> raw) {
    final List<BingoCard> rebuilt = <BingoCard>[];
    int? firstBrokenCartela;
    for (final Map<String, dynamic> entry in raw) {
      final Object? cartelaRaw = entry['cartela_no'];
      final Object? numbersRaw = entry['bingo_numbers'];
      if (cartelaRaw is! num || numbersRaw is! List<dynamic>) {
        firstBrokenCartela ??= 0;
        continue;
      }
      final int cartelaNo = cartelaRaw.toInt();
      final List<int> flat = <int>[
        for (final dynamic value in numbersRaw) (value as num).toInt(),
      ];
      if (flat.length != BingoCard.cellCount - 1) {
        firstBrokenCartela ??= cartelaNo;
        continue;
      }
      rebuilt.add(
        BingoCard(
          id: ((entry['id'] as num?)?.toInt()) ?? cartelaNo,
          cartelaNo: cartelaNo,
          numbers: _buildGridFromNumbers(flat),
        ),
      );
    }
    if (firstBrokenCartela != null && mounted) {
      _showCallerSnack('Error parsing card $firstBrokenCartela');
    }
    return rebuilt;
  }

  /// Asset layout row-major list -> 25-cell grid with FREE centre restored.
  List<int> _buildGridFromNumbers(List<int> flat) => <int>[
        ...flat.take(BingoCard.freeCellIndex),
        BingoCard.freeCellValue,
        ...flat.skip(BingoCard.freeCellIndex),
      ];

  // ------------------------------ State save ------------------------------

  Future<void> _saveAppState() async {
    await CardStorage.saveActiveCards(_cards);
    await CardStorage.saveCardMarks(_marks);
    await CardStorage.saveCalledBalls(_drawer.history);
  }

  // -------------------------------- Cards --------------------------------

  Future<List<BingoCard>> _ensureLibrary() async {
    _library ??= await CardLibraryLoader.loadPregenerated();
    return _library!;
  }

  Future<void> _showAddCardModal() async {
    final List<int>? cartelas = await AddCardDialog.show(context);
    if (cartelas == null || !mounted) {
      return;
    }
    final List<BingoCard> library = await _ensureLibrary();
    int added = 0;
    int? invalidCartela;
    for (final int cartela in cartelas) {
      if (await _addCardFromPreGenerated(library, cartela)) {
        added++;
      } else {
        invalidCartela ??= cartela;
      }
    }
    if (!mounted) {
      return;
    }
    if (invalidCartela != null && added == 0) {
      _showCallerSnack('Error parsing card $invalidCartela');
    } else if (invalidCartela != null) {
      _showCallerSnack(
        'Added $added; error parsing card $invalidCartela',
      );
    } else {
      _showCallerSnack('Added $added card${added == 1 ? '' : 's'}');
    }
  }

  Future<bool> _addCardFromPreGenerated(
    List<BingoCard> library,
    int cartelaNo,
  ) async {
    if (_cards.any((BingoCard card) => card.cartelaNo == cartelaNo)) {
      return true;
    }
    for (final BingoCard candidate in library) {
      if (candidate.cartelaNo == cartelaNo) {
        if (!mounted) {
          return false;
        }
        setState(() {
          _cards.add(candidate);
          _marks[cartelaNo] = <int>{BingoCard.freeCellIndex};
          _applyExistingMarksToCard(candidate);
          _recheckWin(candidate, silent: true);
        });
        await _saveAppState();
        return true;
      }
    }
    return false;
  }

  /// Re-attaches previously saved marks for a re-added cartela number.
  void _applyExistingMarksToCard(BingoCard card) {
    _marks.putIfAbsent(
      card.cartelaNo,
      () => <int>{BingoCard.freeCellIndex},
    );
  }

  Future<void> _confirmDeleteCard(BingoCard card) async {
    if (await showConfirmDeleteCard(context, card)) {
      _deleteCard(card);
    }
  }

  void _deleteCard(BingoCard card) {
    setState(() {
      _cards.remove(card);
      _marks.remove(card.cartelaNo);
      _winningCells.remove(card.cartelaNo);
      _announcedWinCartelas.remove(card.cartelaNo);
    });
    _saveAppState();
    _showCallerSnack('Card deleted');
  }

  Future<void> _confirmDeleteAll() async {
    if (!mounted) {
      return;
    }
    if (await showConfirmDeleteAll(context)) {
      _deleteAllCards();
    }
  }

  void _deleteAllCards() {
    setState(() {
      _cards.clear();
      _marks.clear();
      _winningCells.clear();
      _announcedWinCartelas.clear();
    });
    _saveAppState();
    _showCallerSnack('All cards deleted');
  }

  // ------------------------------ Marking --------------------------------

  void _toggleMark(BingoCard card, int index) {
    setState(() {
      final Set<int> marks = _marks[card.cartelaNo] ??
          (_marks[card.cartelaNo] = <int>{BingoCard.freeCellIndex});
      marks.contains(index) ? marks.remove(index) : marks.add(index);
    });
    _recheckWin(card);
    _saveAppState();
  }

  /// Mark one number across every card: toggling mirrors the original
  /// behaviour (if the number is marked anywhere, unmark it everywhere).
  void _toggleNumberAcrossAllCards(int value) {
    final bool anyMarked = _isNumberMarkedOnAnyCard(value);
    for (final BingoCard card in _cards) {
      final Set<int> marks = _marks[card.cartelaNo] ??
          (_marks[card.cartelaNo] = <int>{BingoCard.freeCellIndex});
      for (int index = 0; index < BingoCard.cellCount; index++) {
        if (index == BingoCard.freeCellIndex) {
          continue;
        }
        if (card.numbers[index] == value) {
          anyMarked ? marks.remove(index) : marks.add(index);
        }
      }
    }
    setState(() {});
    _recomputeAllWins();
    _saveAppState();
  }

  /// True when at least one card has [value] marked.
  bool _isNumberMarkedOnAnyCard(int value) {
    for (final BingoCard card in _cards) {
      final Set<int>? marks = _marks[card.cartelaNo];
      if (marks == null) {
        continue;
      }
      for (final int index in marks) {
        if (index != BingoCard.freeCellIndex &&
            card.numbers[index] == value) {
          return true;
        }
      }
    }
    return false;
  }

  int _markedCount(BingoCard card) {
    final Set<int>? marks = _marks[card.cartelaNo];
    if (marks == null) {
      return 0;
    }
    return marks.contains(BingoCard.freeCellIndex)
        ? marks.length - 1
        : marks.length;
  }

  /// Numbers of [card] that were already called by the drawer.
  int _calledLinkCount(BingoCard card) {
    int count = 0;
    for (int index = 0; index < BingoCard.cellCount; index++) {
      if (index == BingoCard.freeCellIndex) {
        continue;
      }
      if (_calledNumbers.contains(card.numbers[index])) {
        count++;
      }
    }
    return count;
  }

  String _cardCellNumber(BingoCard card, int index) =>
      index == BingoCard.freeCellIndex
          ? 'FREE'
          : '${card.numbers[index]}';

  String _cardStatText(BingoCard card) {
    final int marked = _markedCount(card);
    return _winningCells.containsKey(card.cartelaNo)
        ? 'Bingo! ($marked/24)'
        : '$marked/24 marked';
  }

  // ------------------------------ Win checks -----------------------------

  void _recheckWin(BingoCard card, {bool silent = false}) {
    if (_selectedModeIndex < 0) {
      _winningCells.remove(card.cartelaNo);
      _announcedWinCartelas.remove(card.cartelaNo);
      return;
    }
    final GameMode mode = GameMode.values[_selectedModeIndex];
    final Set<int> marks =
        _marks[card.cartelaNo] ?? const <int>{};
    final List<bool> marked = List<bool>.generate(
      BingoCard.cellCount,
      (int index) => marks.contains(index),
    );
    final WinCheckResult result = GameEngine.check(mode, marked: marked);
    if (result.hasWin) {
      _winningCells[card.cartelaNo] = result.winningCells;
      final bool newlyAnnounced = _announcedWinCartelas.add(card.cartelaNo);
      if (newlyAnnounced && !silent) {
        _showCallerSnack(
          'Bingo! Cartela No. ${card.cartelaNo} (${result.kindLabel})',
        );
      }
    } else {
      _winningCells.remove(card.cartelaNo);
      _announcedWinCartelas.remove(card.cartelaNo);
    }
  }

  void _recomputeAllWins({bool silent = true}) {
    for (final BingoCard card in _cards) {
      _recheckWin(card, silent: silent);
    }
  }

  // ------------------------------- Caller --------------------------------

  void _callNext() {
    if (_selectedModeIndex < 0) {
      _showCallerSnack('No game selected');
    }
    final BingoBall? ball = _drawer.drawNext();
    if (ball == null) {
      _showCallerSnack('All 75 numbers have been called');
      return;
    }
    setState(() {
      _currentBall = ball;
      _calledNumbers.add(ball.number);
      _updateRecentCallerBalls(<BingoBall>[ball]);
    });
    _recomputeAllWins(silent: false);
    _saveAppState();
  }

  void _undoCall() {
    final BingoBall? ball = _drawer.undoLast();
    if (ball == null) {
      _showCallerSnack('No call to undo');
      return;
    }
    setState(() {
      _calledNumbers.remove(ball.number);
      _recentBalls.remove(ball);
      _currentBall = _recentBalls.isEmpty ? null : _recentBalls.first;
    });
    _recomputeAllWins();
    _saveAppState();
  }

  /// Newest-first window of the caller history for the recent row.
  void _updateRecentCallerBalls(List<BingoBall> balls) {
    _recentBalls.clear();
    for (final BingoBall ball in balls.reversed) {
      _recentBalls.add(ball);
      if (_recentBalls.length >= _maxRecentBalls) {
        break;
      }
    }
  }

  /// New session: fresh drawer, cleared marks, cleared call history.
  void _resetMarks() {
    setState(() {
      for (final Set<int> marks in _marks.values) {
        marks
          ..clear()
          ..add(BingoCard.freeCellIndex);
      }
      _winningCells.clear();
      _announcedWinCartelas.clear();
      _drawer = BingoDrawer.standard();
      _recentBalls.clear();
      _calledNumbers.clear();
      _currentBall = null;
    });
    _recomputeAllWins();
    _saveAppState();
    _showCallerSnack('New game - marks reset');
  }

  Widget _callerBall(
    BingoBall ball, {
    double size = 56,
    bool showLetter = true,
  }) {
    return BingoBallWidget(
      ball: ball,
      size: size,
      showLetter: showLetter,
    );
  }

  Widget _numberBallRow() {
    if (_recentBalls.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No balls called yet',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: <Widget>[
          for (final BingoBall ball in _recentBalls)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _callerBall(ball, size: 34, showLetter: false),
            ),
        ],
      ),
    );
  }

  Widget _bottomBingoCallerBar() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _currentBall != null
                      ? _callerBall(_currentBall!, size: 64)
                      : const BingoBallPlaceholder(size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              'Called ${_calledNumbers.length} / 75',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 36,
                          child: _numberBallRow(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('New game'),
                      onPressed: _resetMarks,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Undo'),
                      onPressed: _undoCall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.casino, size: 18),
                      label: const Text('Call'),
                      onPressed: _callNext,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------- Letter bottom sheet -----------------------

  List<int> _numbersForBingoLetter(BingoLetter letter) =>
      <int>[for (int i = 0; i < 15; i++) poolLow(letter) + i];

  Color _bingoLetterColor(BingoLetter letter) => ballColor(letter);

  void _showBingoLetterNumbersModal(BingoLetter letter) {
    final Color letterColor = _bingoLetterColor(letter);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(VoidCallback) setSheetState) {
            final List<int> numbers = _numbersForBingoLetter(letter);
            final int calledCount =
                numbers.where(_calledNumbers.contains).length;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: letterColor,
                          child: Text(
                            letter.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${letter.label} numbers - called $calledCount / 15',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final int value in numbers)
                          _letterNumberChip(letter, value, setSheetState),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap a number to mark or unmark it across every card.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _letterNumberChip(
    BingoLetter letter,
    int value,
    void Function(VoidCallback) refreshSheet,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool called = _calledNumbers.contains(value);
    final bool markedOnAny = _isNumberMarkedOnAnyCard(value);
    return FilterChip(
      label: Text('$value'),
      selected: markedOnAny,
      backgroundColor: called
          ? Color.alphaBlend(
              _bingoLetterColor(letter).withValues(alpha: 0.35),
              scheme.surface,
            )
          : null,
      selectedColor: _markingColor.withValues(alpha: 0.85),
      checkmarkColor: Colors.white,
      onSelected: (bool _) {
        _toggleNumberAcrossAllCards(value);
        refreshSheet(() {});
      },
    );
  }

  // ------------------------------ Sheets ---------------------------------

  void _showSortingModeDialog() {
    final Set<SortCondition> working = <SortCondition>{..._sortConditions};
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(VoidCallback) setSheetState,
          ) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sorting Mode',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Combine several conditions; they apply in tap order.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final SortCondition condition
                            in SortCondition.values)
                          FilterChip(
                            label: Text(
                              '${_shortCodeForCondition(condition)} · ${condition.label}',
                            ),
                            selected: working.contains(condition),
                            onSelected: (bool selected) => setSheetState(
                              () => selected
                                  ? working.add(condition)
                                  : working.remove(condition),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(working),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((Object? result) {
      if (result is Set<SortCondition>) {
        _onSortingConditionsApplied(result);
      }
    });
  }

  void _onSortingConditionsApplied(Set<SortCondition> conditions) {
    setState(() => _sortConditions = conditions);
    _applyCombinedSort();
    CardStorage.saveSortConditions(
      <String>[for (final SortCondition condition in conditions) condition.name],
    );
    if (conditions.isNotEmpty) {
      _showCallerSnack(
        'Sorted by ${conditions.map(_shortCodeForCondition).join(' + ')}',
      );
    }
  }

  void _applyCombinedSort() {
    if (_sortConditions.isEmpty) {
      return;
    }
    final List<SortCondition> conditions = _sortConditions.toList();
    _cards.sort((BingoCard a, BingoCard b) {
      for (final SortCondition condition in conditions) {
        final int comparison = switch (condition) {
          SortCondition.cartelaNo => a.cartelaNo.compareTo(b.cartelaNo),
          SortCondition.mostMarked =>
            _markedCount(b).compareTo(_markedCount(a)),
          SortCondition.leastMarked =>
            _markedCount(a).compareTo(_markedCount(b)),
          SortCondition.mostLinked =>
            _calledLinkCount(b).compareTo(_calledLinkCount(a)),
        };
        if (comparison != 0) {
          return comparison;
        }
      }
      return a.cartelaNo.compareTo(b.cartelaNo);
    });
  }

  String _shortCodeForCondition(SortCondition condition) =>
      condition.shortCode;

  /// Matches a persisted condition name back to its enum value.
  SortCondition? _sortConditionByName(String name) {
    for (final SortCondition condition in SortCondition.values) {
      if (condition.name == name) {
        return condition;
      }
    }
    return null;
  }

  void _showFontSizeDrawer() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Card Number Font Size',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              _fontSizeDrawerTile(
                Icons.text_decrease_rounded,
                'Decrease',
                _decreaseCardNumberFontSize,
              ),
              _fontSizeDrawerTile(
                Icons.text_increase_rounded,
                'Increase',
                _increaseCardNumberFontSize,
              ),
              _fontSizeDrawerTile(
                Icons.restart_alt_rounded,
                'Reset to default',
                () => _saveCardNumberFontSize(
                  CardStorage.defaultCardNumberFontSize,
                ),
              ),
              _fontSizeDrawerTile(
                Icons.close_rounded,
                'Close',
                _closeDrawer,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fontSizeDrawerTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        '${_cardNumberFontSize.toStringAsFixed(0)} px',
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
      onTap: onTap,
    );
  }

  void _decreaseCardNumberFontSize() {
    final double next = (_cardNumberFontSize - 2)
        .clamp(_minCardFontSize, _maxCardFontSize)
        .toDouble();
    _saveCardNumberFontSize(next);
  }

  void _increaseCardNumberFontSize() {
    final double next = (_cardNumberFontSize + 2)
        .clamp(_minCardFontSize, _maxCardFontSize)
        .toDouble();
    _saveCardNumberFontSize(next);
  }

  void _saveCardNumberFontSize(double size) {
    setState(() => _cardNumberFontSize = size);
    CardStorage.saveCardNumberFontSize(size);
  }

  void _showMarkingColorDialog() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Marking Color',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final int value in _markingColorValues)
                      _markingColorSwatch(value),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _markingColorSwatch(int value) {
    final Color color = Color(value);
    final bool selected = _markingColor.toARGB32() == value;
    return GestureDetector(
      onTap: () {
        setState(() => _markingColor = color);
        CardStorage.saveMarkingColor(value);
        _closeDrawer();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white)
            : null,
      ),
    );
  }

  void _closeDrawer() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ------------------------------- QR / lock -----------------------------

  /// AppBar text / feedback copy for the currently selected game type.
  String _gameTypeMessage() => _selectedModeIndex < 0
      ? 'No game'
      : GameMode.values[_selectedModeIndex].label;

  Future<void> _onLockTap() async {
    if (_qrUnlocked) {
      await _showQrDialog();
      return;
    }
    await _showPasswordDialog();
  }

  Future<void> _showPasswordDialog() async {
    final bool unlocked = await showPasswordDialog(context);
    if (!unlocked || !mounted) {
      return;
    }
    _setUnlockState(true);
    await _showQrDialog();
  }

  void _setUnlockState(bool unlocked) {
    setState(() => _qrUnlocked = unlocked);
    CardStorage.saveQrUnlocked(unlocked);
    if (unlocked) {
      _showCallerSnack('Unlocked! QR feature enabled.');
    }
  }

  Future<void> _showQrDialog() async {
    if (!mounted) {
      return;
    }
    if (_cards.isEmpty) {
      _showCallerSnack('Add bingo cards first');
      return;
    }
    await showQrDialog(context, _cards);
  }

  // ------------------------------ Game type ------------------------------

  void _showGameTypeSheet() {
    showGameModeSelector(
      context,
      currentIndex: _selectedModeIndex,
    ).then((int? result) {
      if (result == null) {
        return;
      }
      _setGameMode(result);
    });
  }

  void _setGameMode(int index) {
    setState(() => _selectedModeIndex = index);
    if (index < 0) {
      CardStorage.clearSelectedGameMode();
      _showCallerSnack(_gameTypeMessage());
    } else {
      CardStorage.saveSelectedGameMode(index);
    }
    _winningCells.clear();
    _announcedWinCartelas.clear();
    _recomputeAllWins();
  }

  // ------------------------------- Snack ---------------------------------

  void _showCallerSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(40, 8, 40, 96),
          backgroundColor: Colors.black87,
          duration: const Duration(milliseconds: 2200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  // -------------------------------- Build --------------------------------

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hareg Bingo'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sorting Mode',
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortingModeDialog,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: TextButton(
              onPressed: _showGameTypeSheet,
              child: Text(
                _gameTypeMessage(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _selectedModeIndex < 0
                      ? scheme.outline
                      : scheme.primary,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _qrUnlocked ? 'Card Numbers QR' : 'Unlock QR feature',
            icon: Icon(
              _qrUnlocked
                  ? Icons.lock_open_outlined
                  : Icons.lock_outline_rounded,
            ),
            onPressed: _onLockTap,
          ),
          PopupMenuButton<_MenuAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (_MenuAction action) {
              switch (action) {
                case _MenuAction.fontSize:
                  _showFontSizeDrawer();
                case _MenuAction.markingColor:
                  _showMarkingColorDialog();
                case _MenuAction.deleteAll:
                  _confirmDeleteAll();
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<_MenuAction>>[
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.fontSize,
                child: Text('Card number font size'),
              ),
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.markingColor,
                child: Text('Marking color'),
              ),
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.deleteAll,
                child: Text('Delete all cards'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCardModal,
        icon: const Icon(Icons.add),
        label: const Text('Add Bingo Card(s)'),
      ),
      bottomNavigationBar: _bottomBingoCallerBar(),
    );
  }

  Widget _buildBody() {
    if (_cards.isEmpty) {
      final ColorScheme scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.style_outlined,
              size: 72,
              color: scheme.outline.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Add bingo cards first',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add bingo cards',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: _cards.length,
      itemBuilder: (BuildContext context, int index) {
        final BingoCard card = _cards[index];
        return BingoCardWidget(
          card: card,
          marked: _marks[card.cartelaNo] ?? const <int>{},
          numberFontSize: _cardNumberFontSize,
          markingColor: _markingColor,
          winningCells: _winningCells[card.cartelaNo] ?? const <int>[],
          statText: _cardStatText(card),
          cellLabel: _cardCellNumber,
          onCellTap: (int cellIndex) => _toggleMark(card, cellIndex),
          onDelete: () => _confirmDeleteCard(card),
          onLetterTap: _showBingoLetterNumbersModal,
        );
      },
    );
  }
}
