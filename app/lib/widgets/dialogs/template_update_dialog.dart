/// Offered right after a workout whose exercises diverged from its
/// template, or that started empty: fold what you actually did back into a
/// template. Templates stay lists of exercises — this saves the movements,
/// never the weights (those are planned per exercise).
library;

import 'package:flutter/material.dart';

import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../providers/workout_provider.dart';
import '../../theme/theme_spec.dart';

Future<void> showTemplateUpdateDialog(
  BuildContext context, {
  required TemplateOffer offer,
  required WorkoutProvider provider,
}) {
  return showDialog(
    context: context,
    builder: (_) => _TemplateUpdateDialog(offer: offer, provider: provider),
  );
}

class _TemplateUpdateDialog extends StatefulWidget {
  final TemplateOffer offer;
  final WorkoutProvider provider;

  const _TemplateUpdateDialog({required this.offer, required this.provider});

  @override
  State<_TemplateUpdateDialog> createState() => _TemplateUpdateDialogState();
}

class _TemplateUpdateDialogState extends State<_TemplateUpdateDialog> {
  late final TextEditingController _nameController;
  bool _isSaving = false;

  bool get _isNew => widget.offer.templateId.isEmpty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _isNew
        ? _nameController.text.trim()
        : widget.offer.templateName;
    if (name.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final template = WorkoutTemplate()
        ..id = widget.offer.templateId
        ..name = name
        ..exercises.addAll(widget.offer.exercises);
      await widget.provider.saveTemplate(template);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = widget.offer.exercises
        .map((e) => exerciseNames[e] ?? '?')
        .join(', ');

    return AlertDialog(
      title: Text(
        _isNew
            ? 'Save as a template?'
            : "Update '${widget.offer.templateName}'?",
        style: TextStyle(fontWeight: context.tokens.weight.heavy),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isNew
                ? 'Keep this session one tap away next time:'
                : 'This session did not match the template. Make the '
                      'template match what you did:',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 8),
          Text(
            names,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              fontWeight: context.tokens.weight.bold,
            ),
          ),
          if (_isNew) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Template name',
                hintText: 'e.g. Push, Tuesday',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(_isNew ? 'No thanks' : 'Keep as is'),
        ),
        FilledButton(
          onPressed:
              _isSaving || (_isNew && _nameController.text.trim().isEmpty)
              ? null
              : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isNew ? 'Save template' : 'Update template'),
        ),
      ],
    );
  }
}
