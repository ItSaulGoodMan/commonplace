import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/key_check.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../core/theme.dart';
import 'settings_screen.dart' show openKeyPage;

/// The key in whatever was pasted, or null if there isn't one.
///
/// AI Studio has made "AQ." keys since May 2026; older keys start with
/// "AIza". Copies sometimes bring spaces, line breaks, quotes or a whole
/// `GEMINI_API_KEY=...` line along. The format is only a first look: the key
/// check that runs after saving asks Gemini itself.
String? parseGeminiKey(String pasted) {
  final text = pasted.replaceAll(RegExp(r'\s'), '');
  final known = RegExp(r'AIza[0-9A-Za-z_\-]{30,}|AQ\.[0-9A-Za-z_.\-]{20,}')
      .firstMatch(text);
  if (known != null) return known[0];
  // A format Google hasn't announced yet: let Gemini decide.
  final bare = text.replaceAll(RegExp('^["\'`]+|["\'`]+\$'), '');
  return RegExp(r'^[0-9A-Za-z_.\-]{30,}$').hasMatch(bare) ? bare : null;
}

/// Shows whether a Gemini key is set and lets the owner add, change or remove it.
class GeminiKeyField extends StatefulWidget {
  const GeminiKeyField({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<GeminiKeyField> createState() => _GeminiKeyFieldState();
}

class _GeminiKeyFieldState extends State<GeminiKeyField> {
  final _controller = TextEditingController();
  bool _editing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(SettingsRepository settings) async {
    final key = parseGeminiKey(_controller.text);
    if (key == null) {
      setState(
        () => _error =
            'That doesn\'t look like a Gemini key. Copy it again from AI Studio: '
            'new keys start with "AQ.", older ones with "AIza".',
      );
      return;
    }
    final check = context.read<KeyCheck>();
    await settings.setGeminiKey(key);
    _controller.clear();
    setState(() {
      _editing = false;
      _error = null;
    });
    // Find out straight away whether Gemini accepts it.
    await check.run();
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final text = Theme.of(context).textTheme;
    final palette = Palette.of(context);

    if (settings.hasGeminiKey && !_editing) {
      final check = context.watch<KeyCheck>();
      final problem = settings.keyProblem;
      final checked = settings.keyCheckedAt != null;
      final model = SettingsRepository.models
          .firstWhere((m) => m.id == settings.geminiModel)
          .label;
      final (IconData icon, Color color, String status) = check.running
          ? (
              Icons.hourglass_top_rounded,
              palette.inkSoft,
              'Checking the key with Gemini...',
            )
          : !checked
          ? (
              Icons.help_outline_rounded,
              palette.inkSoft,
              'Key saved on this phone, not checked yet',
            )
          : problem == null
          ? (
              Icons.check_circle_rounded,
              palette.ink,
              'The key works with $model',
            )
          : (Icons.error_outline_rounded, palette.error, problem.message);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  status,
                  style: text.titleSmall!.copyWith(
                    color: problem != null && !check.running
                        ? palette.error
                        : null,
                  ),
                ),
              ),
            ],
          ),
          if (problem?.detail case final detail?
              when detail.isNotEmpty && !check.running) ...[
            const SizedBox(height: Space.xs),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: SelectableText(
                'Gemini said: $detail',
                style: text.bodySmall!.copyWith(color: palette.inkSoft),
              ),
            ),
          ],
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            children: [
              OutlinedButton(
                onPressed: check.running ? null : check.run,
                child: Text(checked ? 'Check again' : 'Check key'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _editing = true),
                child: const Text('Change key'),
              ),
              TextButton(
                onPressed: () => settings.setGeminiKey(null),
                child: const Text('Remove key'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Commonplace uses Google Gemini to watch each reel and write the note. '
          'A key from Google AI Studio is free: no card needed, with a daily limit that is plenty for a few reels a day. '
          "Don't turn on billing for it and it stays free.",
          style: text.bodyMedium,
        ),
        const SizedBox(height: Space.m),
        TextButton.icon(
          onPressed: openKeyPage,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Get a free key at aistudio.google.com'),
        ),
        const SizedBox(height: Space.s),
        TextField(
          controller: _controller,
          autocorrect: false,
          enableSuggestions: false,
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Gemini API key',
            hintText: 'AQ.Ab...',
            errorText: _error,
            errorMaxLines: 3,
          ),
          onSubmitted: (_) => _save(settings),
        ),
        const SizedBox(height: Space.m),
        Wrap(
          spacing: Space.s,
          children: [
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => FilledButton(
                onPressed: _controller.text.trim().isEmpty
                    ? null
                    : () => _save(settings),
                child: const Text('Save key'),
              ),
            ),
            if (_editing)
              TextButton(
                onPressed: () => setState(() {
                  _editing = false;
                  _error = null;
                  _controller.clear();
                }),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ],
    );
  }
}
