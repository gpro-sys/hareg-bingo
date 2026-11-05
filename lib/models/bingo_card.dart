/// Data model for a single pre-generated bingo (cartela) card.
///
/// The asset JSON stores each card as:
///   {"id":1,"cartela_no":1,"bingo_numbers":[n0..n23]}
/// where `bingo_numbers` is the flat row-major array of the 25-cell card
/// **with the centre cell omitted**. Inserting `0` at index 12 restores a
/// canonical 25-cell grid:
///
/// ```
///  0  1  2  3  4
///  5  6  7  8  9
/// 10 11 12 13 14   (12 == FREE)
/// 15 16 17 18 19
/// 20 21 22 23 24
/// ```
library;

/// Letters along the header of every card, keyed by grid column.
enum BingoLetter {
  b,
  i,
  n,
  g,
  o;

  /// `B`, `I`, `N`, `G`, `O`.
  String get label => const <String>['B', 'I', 'N', 'G', 'O'][index];
}

/// Backing type for a single 5x5 card.
class BingoCard {
  static const int cellCount = 25;
  static const int freeCellIndex = 12;
  static const int freeCellValue = 0;

  const BingoCard({
    required this.id,
    required this.cartelaNo,
    required this.numbers,
  })  : assert(numbers.length == cellCount);

  final int id;

  /// Printed number shown on the physical cartela (1..20000).
  final int cartelaNo;

  /// Flat row-major array of 25 cells. `12` is the FREE centre and is
  /// stored as `0`.
  final List<int> numbers;

  // Entire column index lists. Column 2 contains the free cell.
  static const List<List<int>> columnIndexes = <List<int>>[
    <int>[0, 5, 10, 15, 20],
    <int>[1, 6, 11, 16, 21],
    <int>[2, 7, freeCellIndex, 17, 22],
    <int>[3, 8, 13, 18, 23],
    <int>[4, 9, 14, 19, 24],
  ];

  /// 1-based numbers on the letter's pool. Column 2 spans 31..45 but the
  /// centre is FREE, so only 4 numbers may sit there.
  static int columnRangeStart(int column) => column * 15;
  static int columnRangeEnd(int column) => column * 15 + 15;

  bool isFreeCell(int index) => index == freeCellIndex;

  /// Inclusive range this number's letter must cover, or null when it is
  /// the free value.
  BingoLetter? letterForValue(int value) {
    if (value == freeCellValue) {
      return null;
    }
    final int column = (value - 1) ~/ 15;
    if (column < 0 || column >= BingoLetter.values.length) {
      return null;
    }
    return BingoLetter.values[column];
  }

  BingoCard copyWith({List<int>? numbers}) {
    return BingoCard(
      id: id,
      cartelaNo: cartelaNo,
      numbers: numbers ?? this.numbers,
    );
  }

  /// Deserialise the asset JSON object into a [BingoCard].
  factory BingoCard.fromJson(Map<String, dynamic> json) {
    final List<int> raw = <int>[
      for (final dynamic v in (json['bingo_numbers'] as List<dynamic>)) v as int,
    ];
    if (raw.length != cellCount - 1) {
      throw FormatException(
        'card ${json['cartela_no']} has ${raw.length} values, '
        'expected ${cellCount - 1}',
      );
    }
    if (raw.contains(freeCellValue)) {
      throw FormatException(
        'card ${json['cartela_no']} contains the FREE sentinel $freeCellValue',
      );
    }
    return BingoCard(
      id: json['id'] as int,
      cartelaNo: json['cartela_no'] as int,
      numbers: <int>[
        ...raw.take(freeCellIndex),
        freeCellValue,
        ...raw.skip(freeCellIndex),
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cartela_no': cartelaNo,
        'bingo_numbers': <int>[
          for (int i = 0; i < numbers.length; i++)
            if (i != freeCellIndex) numbers[i],
        ],
      };
}
