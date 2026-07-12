import 'package:flutter/material.dart';

/// Confirmation cohérente pour une action irréversible.
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Supprimer',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final colors = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            icon: Icon(Icons.warning_amber_rounded, color: colors.error),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      ) ??
      false;
}

/// Dialog de saisie texte qui **possède et libère** son contrôleur
/// (évite l'assertion de fuite au dismiss). Renvoie le texte ou `null`.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String okLabel = 'OK',
  int maxLength = 60,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PromptDialog(
      title: title,
      initial: initial,
      hint: hint,
      okLabel: okLabel,
      maxLength: maxLength,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.okLabel,
    required this.maxLength,
  });
  final String title;
  final String initial;
  final String hint;
  final String okLabel;
  final int maxLength;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );
  late bool _valid = widget.initial.trim().isNotEmpty;
  bool _touched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _ctrl.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: widget.maxLength,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (value) => setState(() {
          _touched = true;
          _valid = value.trim().isNotEmpty;
        }),
        onSubmitted: (_) {
          if (_valid) _submit();
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: _touched && !_valid ? 'Saisis un nom.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valid ? _submit : null,
          child: Text(widget.okLabel),
        ),
      ],
    );
  }
}
