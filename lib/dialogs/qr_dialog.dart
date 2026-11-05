/// Password gate + QR sheet for the `Card Numbers QR` feature.
///
/// The password check never stores the secret: only the sha256 digest is
/// compared, exactly like the reference application (Password 2305).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/bingo_card.dart';

/// sha256 digest of the password accepted by the QR feature.
const String kQrPasswordHash =
    '9a5a48758da347f33bd37064cfbd05442ef005c85ae0ea4614740d5597316ed3';

/// True when [password] hashes to the stored digest.
bool verifyQrPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString() == kQrPasswordHash;
}

/// Locked-state password dialog. Pops `true` once the password is accepted.
Future<bool> showPasswordDialog(BuildContext context) async {
  final bool? unlocked = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PasswordDialog(),
  );
  return unlocked ?? false;
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _incorrect = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (verifyQrPassword(_controller.text.trim())) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _incorrect = true;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Enter Password'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        keyboardType: TextInputType.number,
        onChanged: (String text) {
          if (_incorrect) {
            setState(() => _incorrect = false);
          }
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          errorText: _incorrect ? 'Incorrect password' : null,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.key_rounded, size: 18),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
          ),
          onPressed: _submit,
          label: const Text('Unlock'),
        ),
      ],
    );
  }
}

/// QR sheet for already-unlocked sessions. One card at a time, each encoded
/// as the asset-layout JSON map so scans are round-trip compatible.
Future<int?> showQrDialog(BuildContext context, List<BingoCard> cards) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _QrSheet(cards: cards),
  );
}

class _QrSheet extends StatefulWidget {
  const _QrSheet({required this.cards});

  final List<BingoCard> cards;

  @override
  State<_QrSheet> createState() => _QrSheetState();
}

class _QrSheetState extends State<_QrSheet> {
  int _selected = 0;

  BingoCard get _card => widget.cards[_selected];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Card Numbers QR (${_card.cartelaNo})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            if (widget.cards.length > 1)
              DropdownMenu<int>(
                width: MediaQuery.sizeOf(context).width - 60,
                initialSelection: _selected,
                dropdownMenuEntries: <DropdownMenuEntry<int>>[
                  for (int i = 0; i < widget.cards.length; i++)
                    DropdownMenuEntry<int>(
                      value: i,
                      label: 'Cartela No. ${widget.cards[i].cartelaNo}',
                    ),
                ],
                onSelected: (int? value) =>
                    setState(() => _selected = value ?? 0),
              ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: jsonEncode(_card.toJson()),
                size: 260,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: scheme.inverseSurface,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: scheme.inverseSurface,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Scanning decodes the asset-layout JSON of this card '
              '(id, cartela_no, bingo_numbers).',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
