/// "Add Bingo Card(s)" modal for picking pre-generated cartela numbers.
library;

import 'package:flutter/material.dart';

/// Parses free-form cartela input: single numbers, comma/plain lists and
/// inclusive ranges (`5`, `3-9`, `12, 15, 20-24`).
///
/// Returns the sorted de-duplicated values, and `null` when the whole input
/// is unparseable so the caller can surface the proper error.
List<int>? parseCartelaInput(String input) {
  final Set<int> values = <int>{};
  final RegExp rangePattern = RegExp(r'^(\d+)\s*[-–]\s*(\d+)$');
  final RegExp valuePattern = RegExp(r'^\d+$');
  bool sawAnything = false;
  bool sawBadPart = false;

  for (final String part in input.split(RegExp(r'[\s,;]+'))) {
    if (part.isEmpty) {
      continue;
    }
    sawAnything = true;
    final String trimmed = part.trim();
    final RegExpMatch? range = rangePattern.firstMatch(trimmed);
    if (range != null) {
      final int low = int.parse(range.group(1)!);
      final int high = int.parse(range.group(2)!);
      if (low <= 0 || high > _maxCartelaNo) {
        sawBadPart = true;
        continue;
      }
      if (low <= high) {
        values.addAll(
          <int>[for (int n = low; n <= high; n++) n],
        );
      } else {
        sawBadPart = true;
      }
      continue;
    }
    if (valuePattern.hasMatch(trimmed)) {
      final int value = int.parse(trimmed);
      if (value <= 0 || value > _maxCartelaNo) {
        sawBadPart = true;
        continue;
      }
      values.add(value);
      continue;
    }
    sawBadPart = true;
  }

  if (!sawAnything || sawBadPart && values.isEmpty) {
    return null;
  }
  return values.toList(growable: false)..sort();
}

/// Pre-generated library is always 1..20000; bounds-checked here so typos
/// never silently widen the add dialog.
const int _maxCartelaNo = 20000;

/// Modal that collects one or many cartela numbers.
class AddCardDialog extends StatefulWidget {
  const AddCardDialog({super.key});

  /// Pops with the parsed cartela numbers, or null when cancelled.
  static Future<List<int>?> show(BuildContext context) {
    return showDialog<List<int>>(
      context: context,
      builder: (_) => const AddCardDialog(),
    );
  }

  @override
  State<AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<AddCardDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    setState(() => _errorText = null);
    final List<int>? values = parseCartelaInput(_controller.text);
    if (values == null || values.isEmpty) {
      setState(() => _errorText = 'Enter a cartela number or range');
      return;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add Bingo Card(s)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: 'e.g. 12 or 40-68',
              labelText: 'Cartela number(s)',
              errorText: _errorText,
              prefixIcon: const Icon(Icons.library_add_outlined),
            ),
            onSubmitted: (_) => _add(),
            onChanged: (String text) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Any cartela from 1 to 20000 can be listed, separated by spaces, '
            'commas or ranges.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _add,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
