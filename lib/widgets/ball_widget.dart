/// Coloured circular ball for the bingo caller bar.
library;

import 'package:flutter/material.dart';

import '../models/bingo_ball.dart';

/// One lettered bingo ball, e.g. the freshly-drawn `B 7` or a chip in the
/// recent-calls row.
class BingoBallWidget extends StatelessWidget {
  const BingoBallWidget({
    super.key,
    required this.ball,
    this.size = 56,
    this.showLetter = true,
  });

  final BingoBall ball;

  /// Diameter of the rendered ball in logical pixels.
  final double size;

  /// Whether the letter caption is drawn above the number. Small balls on
  /// phone displays still fit thanks to [size]-relative text styles.
  final bool showLetter;

  Color get _color => ballColor(ball.letter);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.35),
            radius: 1.1,
            colors: <Color>[
              Color.alphaBlend(_color.withValues(alpha: 0.85), Colors.white),
              _color,
              Color.alphaBlend(Colors.black.withValues(alpha: 0.30), _color),
            ],
            stops: const <double>[0, 0.62, 1],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.all(size * 0.06),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showLetter)
                  Text(
                    ball.letter.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                Text(
                  '${ball.number}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * (showLetter ? 0.34 : 0.46),
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder ball rendered before the first ball of a session is drawn.
class BingoBallPlaceholder extends StatelessWidget {
  const BingoBallPlaceholder({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.casino_outlined,
        size: size * 0.5,
        color: scheme.outline,
      ),
    );
  }
}
