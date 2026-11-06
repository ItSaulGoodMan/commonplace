import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/use_cases/note_processor.dart';
import '../../core/theme.dart';
import 'account_section.dart';
import 'gemini_key_field.dart';
import 'instagram_section.dart';
import 'status_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final play = context.read<Edition>() == Edition.play;
    final text = Theme.of(context).textTheme;
    final palette = Palette.of(context);
    final gutter = Space.gutter(MediaQuery.sizeOf(context).width);

    Widget heading(String label) => Padding(
      padding: EdgeInsets.fromLTRB(gutter, Space.xxl, gutter, Space.s),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: TypeScale.casual(20, weight: 680).copyWith(color: palette.ink),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Space.measure + 64),
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.huge),
            children: [
              if (play) ...[
                heading('Account'),
                AccountSection(gutter: gutter),
              ] else ...[
                heading('Instagram'),
                InstagramSection(gutter: gutter),
                heading('Gemini'),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: GeminiKeyField(
                    onSaved: () => context.read<NoteProcessor>().kick(),
                  ),
                ),
                const SizedBox(height: Space.l),
                RadioGroup<String>(
                  groupValue: settings.geminiModel,
                  onChanged: (v) {
                    if (v != null) settings.setGeminiModel(v);
                  },
                  child: Column(
                    children: [
                      for (final m in SettingsRepository.models)
                        RadioListTile<String>(
                          value: m.id,
                          title: Text(m.label),
                          subtitle: Text(m.description),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: gutter - 4,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              heading('Notes'),
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: gutter),
                title: const Text('Write notes in'),
                subtitle: Text(
                  settings.noteLanguage ?? 'The same language as the reel',
                ),
                trailing: const Icon(Icons.expand_more_rounded),
                onTap: () async {
                  final choice = await showModalBottomSheet<_LanguageChoice>(
                    context: context,
                    builder: (context) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final lang in SettingsRepository.noteLanguages)
                            ListTile(
                              title: Text(
                                lang ?? 'The same language as the reel',
                              ),
                              trailing: lang == settings.noteLanguage
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () =>
                                  Navigator.pop(context, _LanguageChoice(lang)),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (choice != null) {
                    await settings.setNoteLanguage(choice.language);
                  }
                },
              ),
              heading('Appearance'),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                ),
              ),
              heading('Storage'),
              SwitchListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: gutter),
                value: settings.keepMedia,
                onChanged: settings.setKeepMedia,
                title: const Text('Keep videos after the note is made'),
                subtitle: const Text(
                  'Off saves space. The original stays in your gallery and on Instagram.',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: gutter),
                value: settings.shrinkVideos,
                onChanged: settings.setShrinkVideos,
                title: const Text('Make videos smaller before sending'),
                subtitle: const Text(
                  'A 480p copy at 5 frames a second, with the sound as it is. '
                  'Gemini looks at one frame a second anyway, so notes come '
                  'out the same and sending is two or three times faster.',
                ),
              ),
              heading('Status'),
              StatusSection(gutter: gutter),
              heading('Privacy'),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: Text(
                  play
                      ? 'Your notes live only on this phone. To make a note, its video or images go through the Commonplace server to Google Gemini and are deleted once the note is made. '
                            "Google may use what's sent to improve its products, so don't add anything private. "
                            'The server keeps only your email, name and how many notes you made each day.'
                      : 'Your notes live only on this phone. A video is sent to Google Gemini only while its note is being made. '
                            "On Gemini's free tier, Google may use what you send to improve its products, so don't share anything private. "
                            'Your Instagram sign-in and Gemini key are kept encrypted on this phone and are left out of backups.',
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageChoice {
  const _LanguageChoice(this.language);
  final String? language;
}

/// Opens Google AI Studio's API key page.
Future<void> openKeyPage() => launchUrl(
  Uri.parse('https://aistudio.google.com/apikey'),
  mode: LaunchMode.externalApplication,
);
