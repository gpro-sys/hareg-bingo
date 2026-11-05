/// Renders one 5x5 bingo card with per-cell marking.
library;

import 'package:flutter/material.dart';

import '../models/bingo_ball.dart';
import '../models/bingo_card.dart';

/// A single pre-generated card.
///
/// The widget is display-only: marking goes through [onCellTap] so the home
/// screen keeps ownership of the mark sets and can persist them.
class BingoCardWidget extends StatelessWidget {
  const BingoCardWidget({
    super.key,
    required this.card,
    required this.marked,
    required this.numberFontSize,
    required this.markingColor,
    this.onCellTap,
    this.onDelete,
    this.winningCells = const <int>[],
    this.statText,
    this.cellLabel,
    this.onLetterTap,
  });

  final BingoCard card;

  /// Currently marked cell indexes (the FREE centre included).
  final Set<int> marked;

  /// User-configurable number font size.
  final double numberFontSize;

  /// Fill colour used for marked cells.
  final Color markingColor;

  final void Function(int index)? onCellTap;

  /// When non-null a delete button is shown in the card header.
  final VoidCallback? onDelete;

  /// Cells of the completed win pattern, highlighted with a gold border.
  final List<int> winningCells;

  /// Short status line shown next to the delete button.
  final String? statText;

  /// Optional label builder (defaults to `FREE`/number).
  final String Function(BingoCard card, int index)? cellLabel;

  /// Letter tap opens the letter-number bottom sheet.
  final void Function(BingoLetter letter)? onLetterTap;

  String _defaultLabel(BingoCard card, int index) {
    if (index == BingoCard.freeCellIndex) {
      return 'FREE';
    }
    return '${card.numbers[index]}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Cartela No. ${card.cartelaNo}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (statText != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      statText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete card',
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: scheme.error,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              for (final BingoLetter letter in BingoLetter.values)
                Expanded(
                  child: GestureDetector(
                    onTap: onLetterTap == null
                        ? null
                        : () => onLetterTap!(letter),
                    child: Text(
                      letter.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ballColor(letter),
                        fontWeight: FontWeight.w800,
                        fontSize: numberFontSize * 0.8,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          AspectRatio(
            aspectRatio: 1,
            child: Column(
              children: <Widget>[
                for (int row = 0; row < 5; row++)
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        for (int column = 0; column < 5; column++)
                          Expanded(
                            child: _cell(
                              context,
                              row * 5 + column,
                              scheme,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, int index, ColorScheme scheme) {
    final bool isFree = index == BingoCard.freeCellIndex;
    final bool isMarked = marked.contains(index);
    final bool isWinner = winningCells.contains(index);
    final String label = cellLabel?.call(card, index) ??
        _defaultLabel(card, index);
    final EdgeInsets inset = EdgeInsets.all(isFree ? 6 : 4);

    return Padding(
      padding: inset,
      child: Material(
        color: isMarked ? markingColor : scheme.surface,
        borderRadius: BorderRadius.circular(8),
        shape: isWinner
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                side: BorderSide(color: Color(0xFFFFC107), width: 2.5),
              )
            : null,
        child: InkWell(
          onTap: isFree ? null : onCellTap == null ? null : () => onCellTap!(index),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: isFree ? numberFontSize * 0.52 : numberFontSize,
                fontWeight: isMarked ? FontWeight.w800 : FontWeight.w600,
                color: isMarked
                    ? Colors.white
                    : isFree
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
