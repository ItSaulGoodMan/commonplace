import 'dart:async';
import 'dart:io';

import '../../domain/models/ai.dart';
import '../../domain/prompts.dart';
import '../services/gemini_client.dart';
import '../services/local_stores.dart';
import 'settings_repository.dart';

/// Personal edition: Gemini with the owner's own free key, called directly.
class GeminiNoteAi implements NoteAi {
  GeminiNoteAi({
    required GeminiClient gemini,
    required SettingsRepository settings,
  }) : _gemini = gemini,
       _settings = settings;

  final GeminiClient _gemini;
  final SettingsRepository _settings;

  @override
  AiFailure? get blocked =>
      _settings.hasGeminiKey ? null : AiFailure.missingKey;

  /// Thinking is billed as output; a note needs little. Flash-Lite goes as
  /// low as MINIMAL, Flash only to LOW.
  String get _thinking =>
      _settings.geminiModel.contains('lite') ? 'MINIMAL' : 'LOW';

  @override
  Future<(Extraction, Map<String, Object?>)> read(
    List<String> mediaPaths, {
    String? caption,
    String? language,
    void Function(ReadUpdate update)? onUpdate,
    void Function(AiUsage usage)? onUsage,
    Future<void>? cancel,
  }) async {
    final text =
        Prompts.read(language: language) +
        ((caption?.trim().isNotEmpty ?? false)
            ? Prompts.readCaption(caption!.trim())
            : '');
    final uploaded = <String>[];
    try {
      final parts = <Map<String, Object?>>[
        for (final path in mediaPaths)
          await _gemini.mediaPart(
            File(path),
            MediaStore.mimeTypeFor(path),
            onUpdate: onUpdate,
            cancel: cancel,
            onUploaded: uploaded.add,
          ),
        {'text': text},
      ];
      final answer = await _gemini.generateJson(
        parts: parts,
        schema: Prompts.readSchema,
        thinkingLevel: _thinking,
        maxOutputTokens: 8192,
        onUpdate: onUpdate,
        onUsage: onUsage,
        cancel: cancel,
      );
      return Extraction.split(answer);
    } finally {
      // Read or not, the video has no business staying with Google.
      for (final name in uploaded) {
        unawaited(_gemini.deleteFile(name));
      }
    }
  }

  @override
  Future<Extraction> extract(
    List<String> mediaPaths, {
    void Function(AiUsage usage)? onUsage,
  }) async {
    final uploaded = <String>[];
    try {
      final parts = <Map<String, Object?>>[
        for (final path in mediaPaths)
          await _gemini.mediaPart(
            File(path),
            MediaStore.mimeTypeFor(path),
            onUploaded: uploaded.add,
          ),
        {'text': Prompts.extract},
      ];
      return Extraction(
        await _gemini.generateJson(
          parts: parts,
          schema: Prompts.extractSchema,
          thinkingLevel: _thinking,
          maxOutputTokens: 8192,
          onUsage: onUsage,
        ),
      );
    } finally {
      for (final name in uploaded) {
        unawaited(_gemini.deleteFile(name));
      }
    }
  }

  @override
  Future<Map<String, Object?>> write({
    required String material,
    String? language,
    Extraction? from,
    bool rewrite = false,
    void Function(AiUsage usage)? onUsage,
  }) => _gemini.generateJson(
    parts: [
      {'text': Prompts.distill(material: material, language: language)},
    ],
    schema: Prompts.distillSchema,
    thinkingLevel: _thinking,
    maxOutputTokens: 2048,
    onUsage: onUsage,
  );
}
