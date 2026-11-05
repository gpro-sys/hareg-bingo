/// Deletion confirmations (single card and wipe-everything).
library;

import 'package:flutter/material.dart';

import '../models/bingo_card.dart';

/// "Delete Card?" confirmation for one cartela.
Future<bool> showConfirmDeleteCard(
  BuildContext context,
  BingoCard card,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Delete Card?'),
      content: Text(
        'Cartela No. ${card.cartelaNo} will be removed from this game.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// "Delete All?" confirmation; uses the original app's exact copy.
Future<bool> showConfirmDeleteAll(BuildContext context) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Delete All Cards?'),
      content:
          const Text('This will permanently remove every bingo card.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete all'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
