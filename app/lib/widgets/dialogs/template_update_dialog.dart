/// Offered right after a workout whose exercises diverged from its
/// template, or that started empty: fold what you actually did back into a
/// template. Templates stay lists of exercises — this saves the movements,
/// never the weights (those live on the trackers).
library;

import 'package:flutter/material.dart';

import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../providers/workout_provider.dart';

Future<void> showTemplateUpdateDialog(
  BuildContext context, {
  required TemplateUpdateSuggestion suggestion,
  required WorkoutProvider provider,
}) {
  return showDialog(
    context: context,
    builder: (_) => _TemplateUpdateDialog(
      suggestion: suggestion,
      provider: provider,
    ),
  );
}

class _TemplateUpdateDialog extends StatefulWidget {
  final TemplateUpdateSuggestion suggestion;
  final WorkoutProvider provider;

  const _TemplateUpdateDialog({
    required this.suggestion,
    required this.provider,
  });

  @override
  State<_TemplateUpdateDialog> createState() => _TemplateUpdateDialogState();
}

class _TemplateUpdateDialogState extends State<_TemplateUpdateDialog> {
  late final TextEditingController _nameController;
  bool _isSaving = false;

  bool get _isNew => widget.suggestion.isNew;

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
        : widget.suggestion.templateName;
    if (name.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final template = WorkoutTemplate()
        ..id = widget.suggestion.templateId
        ..name = name
        ..exercises.addAll(widget.suggestion.exercises);
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
    final names = widget.suggestion.exercises
        .map((e) => exerciseNames[e] ?? '?')
        .join(', ');

    return AlertDialog(
      title: Text(
        _isNew
            ? 'Save as a template?'
            : "Update '${widget.suggestion.templateName}'?",
        style: const TextStyle(fontWeight: FontWeight.w900),
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
