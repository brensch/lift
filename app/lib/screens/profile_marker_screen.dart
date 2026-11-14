import '../widgets/common/flat.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../logic/whimsical_emojis.dart';
import '../providers/auth_provider.dart';
import '../services/grpc_client.dart';
import '../services/user_service.dart';
import '../theme/theme_spec.dart';
import 'onboarding/widgets/profile_marker_widgets.dart';
import '../theme/app_icons.dart';

class ProfileMarkerScreen extends StatefulWidget {
  const ProfileMarkerScreen({super.key});

  @override
  State<ProfileMarkerScreen> createState() => _ProfileMarkerScreenState();
}

class _ProfileMarkerScreenState extends State<ProfileMarkerScreen> {
  late String _savedEmoji;
  late String _savedColorHex;
  late String _selectedEmoji;
  late String _selectedColorHex;
  late List<String> _emojiChoices;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _savedEmoji = auth.profileEmoji;
    _savedColorHex = auth.profileColorHex;
    _selectedEmoji = _savedEmoji;
    _selectedColorHex = _savedColorHex;
    _emojiChoices = withSelectedVisible(
      whimsicalEmojiCatalog.take(emojiWindowSize).toList(),
      _selectedEmoji,
    );
  }

  bool get _hasUnsavedChanges =>
      _selectedEmoji != _savedEmoji || _selectedColorHex != _savedColorHex;

  void _refreshEmojiChoices() {
    setState(() => _emojiChoices = shuffledEmojiWindow(_selectedEmoji));
  }

  Future<void> _save() async {
    if (_isSaving || !_hasUnsavedChanges) return;
    setState(() => _isSaving = true);
    try {
      final user = await UserServiceWrapper(context.read<GrpcClient>())
          .updateMyProfile(
            profileEmoji: _selectedEmoji,
            profileColorHex: _selectedColorHex,
          );
      if (!mounted) return;
      context.read<AuthProvider>().setProfile(
        profileEmoji: user.profileEmoji,
        profileColorHex: user.profileColorHex,
      );
      setState(() {
        _savedEmoji = user.profileEmoji;
        _savedColorHex = user.profileColorHex;
        _selectedEmoji = user.profileEmoji;
        _selectedColorHex = user.profileColorHex;
        _emojiChoices = withSelectedVisible(_emojiChoices, _selectedEmoji);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.profileMarker.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Leaving with a pick not saved asks first, by the back arrow or the
    // phone's own back.
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await confirmDialog(
          context,
          title: copy.profileMarker.unsavedTitle,
          body: copy.profileMarker.unsavedBody,
          confirm: copy.profileMarker.unsavedDiscard,
          cancel: copy.profileMarker.unsavedKeep,
          destructive: true,
        );
        if (!discard || !mounted) return;
        setState(() {
          _selectedEmoji = _savedEmoji;
          _selectedColorHex = _savedColorHex;
        });
        // After the frame that lets the page go again.
        WidgetsBinding.instance.addPostFrameCallback((_) => navigator.pop());
      },
      child: _page(context, cs),
    );
  }

  Widget _page(BuildContext context, ColorScheme cs) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: PageTitle(copy.profileMarker.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  Text(
                    copy.profileMarker.heading,
                    style: TextStyle(
                      fontSize: context.tokens.size.headline,
                      fontWeight: context.tokens.weight.heavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.profileMarker.body,
                    style: TextStyle(
                      fontSize: context.tokens.size.body,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ProfilePreviewCard(
                    emoji: _selectedEmoji,
                    colorHex: _selectedColorHex,
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _refreshEmojiChoices,
                      icon: const Icon(AppIcons.refresh, size: 18),
                      label: Text(copy.profileMarker.refresh),
                    ),
                  ),
                  const SizedBox(height: 8),
                  EmojiChoiceWrap(
                    choices: _emojiChoices,
                    selected: _selectedEmoji,
                    onSelect: (emoji) => setState(() => _selectedEmoji = emoji),
                  ),
                  const SizedBox(height: 18),
                  ColorChoiceWrap(
                    selected: _selectedColorHex,
                    onSelect: (hex) => setState(() => _selectedColorHex = hex),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: (!_isSaving && _hasUnsavedChanges) ? _save : null,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          copy.profileMarker.save,
                          style: TextStyle(
                            fontWeight: context.tokens.weight.heavy,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
