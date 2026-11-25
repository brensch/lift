import 'package:material_ui/material_ui.dart';
import '../widgets/common/flat.dart';
import 'package:go_router/go_router.dart';
import 'package:passkeys/exceptions.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../providers/auth_provider.dart' show AuthProvider, formatAuthError;
import '../services/auth_service.dart';
import '../theme/theme_spec.dart';

class AddPasskeyScreen extends StatefulWidget {
  const AddPasskeyScreen({super.key});

  @override
  State<AddPasskeyScreen> createState() => _AddPasskeyScreenState();
}

class _AddPasskeyScreenState extends State<AddPasskeyScreen> {
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  // Step one re-proves the passkey; only then does step two (naming and adding
  // the new passkey) show. A held session alone can't enrol a new credential.
  bool _unlocked = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().reauthenticate();
      if (!mounted) return;
      setState(() => _unlocked = true);
    } on PasskeyAuthCancelledException {
      return;
    } catch (e) {
      if (mounted) setState(() => _error = formatAuthError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = copy.addPasskey.nameRequired);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().addPasskey(name);
      if (!mounted) return;
      context.pop(true);
    } on PasskeyAuthCancelledException {
      return;
    } catch (e) {
      if (mounted) setState(() => _error = formatAuthError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: PageTitle(copy.addPasskey.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _unlocked ? copy.addPasskey.body : copy.addPasskey.unlockBody,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (_unlocked)
              TextField(
                controller: _nameController,
                autofocus: true,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: copy.addPasskey.name,
                  hintText: copy.addPasskey.nameHint,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: context.tokens.brSm,
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: colorScheme.error,
                    fontSize: context.tokens.size.body,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSubmitting ? null : (_unlocked ? _add : _unlock),
              child: Text(
                _isSubmitting
                    ? copy.addPasskey.adding
                    : (_unlocked
                          ? copy.addPasskey.submit
                          : copy.addPasskey.unlockButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
