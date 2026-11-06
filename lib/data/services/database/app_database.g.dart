// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<NoteStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<NoteStatus>($NotesTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<SourceKind, String> sourceKind =
      GeneratedColumn<String>(
        'source_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SourceKind>($NotesTable.$convertersourceKind);
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creatorHandleMeta = const VerificationMeta(
    'creatorHandle',
  );
  @override
  late final GeneratedColumn<String> creatorHandle = GeneratedColumn<String>(
    'creator_handle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> mediaPaths =
      GeneratedColumn<String>(
        'media_paths',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($NotesTable.$convertermediaPaths);
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  onScreenText = GeneratedColumn<String>(
    'on_screen_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($NotesTable.$converteronScreenText);
  static const VerificationMeta _visualNotesMeta = const VerificationMeta(
    'visualNotes',
  );
  @override
  late final GeneratedColumn<String> visualNotes = GeneratedColumn<String>(
    'visual_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<KeyPoint>, String>
  keyPoints = GeneratedColumn<String>(
    'key_points',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<KeyPoint>>($NotesTable.$converterkeyPoints);
  @override
  late final GeneratedColumnWithTypeConverter<List<ActionItem>, String>
  actions = GeneratedColumn<String>(
    'actions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<ActionItem>>($NotesTable.$converteractions);
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topicChosenMeta = const VerificationMeta(
    'topicChosen',
  );
  @override
  late final GeneratedColumn<bool> topicChosen = GeneratedColumn<bool>(
    'topic_chosen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("topic_chosen" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($NotesTable.$convertertags);
  static const VerificationMeta _personalNoteMeta = const VerificationMeta(
    'personalNote',
  );
  @override
  late final GeneratedColumn<String> personalNote = GeneratedColumn<String>(
    'personal_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openCountMeta = const VerificationMeta(
    'openCount',
  );
  @override
  late final GeneratedColumn<int> openCount = GeneratedColumn<int>(
    'open_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highlightsRevealedMeta =
      const VerificationMeta('highlightsRevealed');
  @override
  late final GeneratedColumn<bool> highlightsRevealed = GeneratedColumn<bool>(
    'highlights_revealed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("highlights_revealed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    status,
    sourceKind,
    sourceUrl,
    remoteId,
    creatorHandle,
    caption,
    mediaPaths,
    transcript,
    onScreenText,
    visualNotes,
    language,
    title,
    summary,
    keyPoints,
    actions,
    topic,
    topicChosen,
    tags,
    personalNote,
    starred,
    lastOpenedAt,
    openCount,
    errorMessage,
    highlightsRevealed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('creator_handle')) {
      context.handle(
        _creatorHandleMeta,
        creatorHandle.isAcceptableOrUnknown(
          data['creator_handle']!,
          _creatorHandleMeta,
        ),
      );
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    }
    if (data.containsKey('visual_notes')) {
      context.handle(
        _visualNotesMeta,
        visualNotes.isAcceptableOrUnknown(
          data['visual_notes']!,
          _visualNotesMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('topic')) {
      context.handle(
        _topicMeta,
        topic.isAcceptableOrUnknown(data['topic']!, _topicMeta),
      );
    }
    if (data.containsKey('topic_chosen')) {
      context.handle(
        _topicChosenMeta,
        topicChosen.isAcceptableOrUnknown(
          data['topic_chosen']!,
          _topicChosenMeta,
        ),
      );
    }
    if (data.containsKey('personal_note')) {
      context.handle(
        _personalNoteMeta,
        personalNote.isAcceptableOrUnknown(
          data['personal_note']!,
          _personalNoteMeta,
        ),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('open_count')) {
      context.handle(
        _openCountMeta,
        openCount.isAcceptableOrUnknown(data['open_count']!, _openCountMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('highlights_revealed')) {
      context.handle(
        _highlightsRevealedMeta,
        highlightsRevealed.isAcceptableOrUnknown(
          data['highlights_revealed']!,
          _highlightsRevealedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      status: $NotesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      sourceKind: $NotesTable.$convertersourceKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source_kind'],
        )!,
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      creatorHandle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator_handle'],
      ),
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      mediaPaths: $NotesTable.$convertermediaPaths.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}media_paths'],
        )!,
      ),
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      ),
      onScreenText: $NotesTable.$converteronScreenText.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}on_screen_text'],
        )!,
      ),
      visualNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visual_notes'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      keyPoints: $NotesTable.$converterkeyPoints.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}key_points'],
        )!,
      ),
      actions: $NotesTable.$converteractions.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}actions'],
        )!,
      ),
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      ),
      topicChosen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}topic_chosen'],
      )!,
      tags: $NotesTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        )!,
      ),
      personalNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personal_note'],
      ),
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
      openCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}open_count'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      highlightsRevealed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}highlights_revealed'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NoteStatus, String, String> $converterstatus =
      const EnumNameConverter<NoteStatus>(NoteStatus.values);
  static JsonTypeConverter2<SourceKind, String, String> $convertersourceKind =
      const EnumNameConverter<SourceKind>(SourceKind.values);
  static TypeConverter<List<String>, String> $convertermediaPaths =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converteronScreenText =
      const StringListConverter();
  static TypeConverter<List<KeyPoint>, String> $converterkeyPoints =
      const KeyPointListConverter();
  static TypeConverter<List<ActionItem>, String> $converteractions =
      const ActionListConverter();
  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  final int id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NoteStatus status;
  final SourceKind sourceKind;
  final String? sourceUrl;

  /// Instagram's numeric id for the post, when the note came from Instagram.
  final String? remoteId;
  final String? creatorHandle;
  final String? caption;
  final List<String> mediaPaths;
  final String? transcript;
  final List<String> onScreenText;
  final String? visualNotes;
  final String? language;
  final String? title;
  final String? summary;
  final List<KeyPoint> keyPoints;
  final List<ActionItem> actions;
  final String? topic;

  /// True once the owner moves the note to a shelf by hand; rewrites keep it.
  final bool topicChosen;
  final List<String> tags;
  final String? personalNote;
  final bool starred;
  final DateTime? lastOpenedAt;
  final int openCount;
  final String? errorMessage;
  final bool highlightsRevealed;
  const NoteRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.sourceKind,
    this.sourceUrl,
    this.remoteId,
    this.creatorHandle,
    this.caption,
    required this.mediaPaths,
    this.transcript,
    required this.onScreenText,
    this.visualNotes,
    this.language,
    this.title,
    this.summary,
    required this.keyPoints,
    required this.actions,
    this.topic,
    required this.topicChosen,
    required this.tags,
    this.personalNote,
    required this.starred,
    this.lastOpenedAt,
    required this.openCount,
    this.errorMessage,
    required this.highlightsRevealed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    {
      map['status'] = Variable<String>(
        $NotesTable.$converterstatus.toSql(status),
      );
    }
    {
      map['source_kind'] = Variable<String>(
        $NotesTable.$convertersourceKind.toSql(sourceKind),
      );
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || creatorHandle != null) {
      map['creator_handle'] = Variable<String>(creatorHandle);
    }
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    {
      map['media_paths'] = Variable<String>(
        $NotesTable.$convertermediaPaths.toSql(mediaPaths),
      );
    }
    if (!nullToAbsent || transcript != null) {
      map['transcript'] = Variable<String>(transcript);
    }
    {
      map['on_screen_text'] = Variable<String>(
        $NotesTable.$converteronScreenText.toSql(onScreenText),
      );
    }
    if (!nullToAbsent || visualNotes != null) {
      map['visual_notes'] = Variable<String>(visualNotes);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    {
      map['key_points'] = Variable<String>(
        $NotesTable.$converterkeyPoints.toSql(keyPoints),
      );
    }
    {
      map['actions'] = Variable<String>(
        $NotesTable.$converteractions.toSql(actions),
      );
    }
    if (!nullToAbsent || topic != null) {
      map['topic'] = Variable<String>(topic);
    }
    map['topic_chosen'] = Variable<bool>(topicChosen);
    {
      map['tags'] = Variable<String>($NotesTable.$convertertags.toSql(tags));
    }
    if (!nullToAbsent || personalNote != null) {
      map['personal_note'] = Variable<String>(personalNote);
    }
    map['starred'] = Variable<bool>(starred);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    map['open_count'] = Variable<int>(openCount);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['highlights_revealed'] = Variable<bool>(highlightsRevealed);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      status: Value(status),
      sourceKind: Value(sourceKind),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      creatorHandle: creatorHandle == null && nullToAbsent
          ? const Value.absent()
          : Value(creatorHandle),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      mediaPaths: Value(mediaPaths),
      transcript: transcript == null && nullToAbsent
          ? const Value.absent()
          : Value(transcript),
      onScreenText: Value(onScreenText),
      visualNotes: visualNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(visualNotes),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      keyPoints: Value(keyPoints),
      actions: Value(actions),
      topic: topic == null && nullToAbsent
          ? const Value.absent()
          : Value(topic),
      topicChosen: Value(topicChosen),
      tags: Value(tags),
      personalNote: personalNote == null && nullToAbsent
          ? const Value.absent()
          : Value(personalNote),
      starred: Value(starred),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
      openCount: Value(openCount),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      highlightsRevealed: Value(highlightsRevealed),
    );
  }

  factory NoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      status: $NotesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      sourceKind: $NotesTable.$convertersourceKind.fromJson(
        serializer.fromJson<String>(json['sourceKind']),
      ),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      creatorHandle: serializer.fromJson<String?>(json['creatorHandle']),
      caption: serializer.fromJson<String?>(json['caption']),
      mediaPaths: serializer.fromJson<List<String>>(json['mediaPaths']),
      transcript: serializer.fromJson<String?>(json['transcript']),
      onScreenText: serializer.fromJson<List<String>>(json['onScreenText']),
      visualNotes: serializer.fromJson<String?>(json['visualNotes']),
      language: serializer.fromJson<String?>(json['language']),
      title: serializer.fromJson<String?>(json['title']),
      summary: serializer.fromJson<String?>(json['summary']),
      keyPoints: serializer.fromJson<List<KeyPoint>>(json['keyPoints']),
      actions: serializer.fromJson<List<ActionItem>>(json['actions']),
      topic: serializer.fromJson<String?>(json['topic']),
      topicChosen: serializer.fromJson<bool>(json['topicChosen']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      personalNote: serializer.fromJson<String?>(json['personalNote']),
      starred: serializer.fromJson<bool>(json['starred']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
      openCount: serializer.fromJson<int>(json['openCount']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      highlightsRevealed: serializer.fromJson<bool>(json['highlightsRevealed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'status': serializer.toJson<String>(
        $NotesTable.$converterstatus.toJson(status),
      ),
      'sourceKind': serializer.toJson<String>(
        $NotesTable.$convertersourceKind.toJson(sourceKind),
      ),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'remoteId': serializer.toJson<String?>(remoteId),
      'creatorHandle': serializer.toJson<String?>(creatorHandle),
      'caption': serializer.toJson<String?>(caption),
      'mediaPaths': serializer.toJson<List<String>>(mediaPaths),
      'transcript': serializer.toJson<String?>(transcript),
      'onScreenText': serializer.toJson<List<String>>(onScreenText),
      'visualNotes': serializer.toJson<String?>(visualNotes),
      'language': serializer.toJson<String?>(language),
      'title': serializer.toJson<String?>(title),
      'summary': serializer.toJson<String?>(summary),
      'keyPoints': serializer.toJson<List<KeyPoint>>(keyPoints),
      'actions': serializer.toJson<List<ActionItem>>(actions),
      'topic': serializer.toJson<String?>(topic),
      'topicChosen': serializer.toJson<bool>(topicChosen),
      'tags': serializer.toJson<List<String>>(tags),
      'personalNote': serializer.toJson<String?>(personalNote),
      'starred': serializer.toJson<bool>(starred),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
      'openCount': serializer.toJson<int>(openCount),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'highlightsRevealed': serializer.toJson<bool>(highlightsRevealed),
    };
  }

  NoteRow copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    NoteStatus? status,
    SourceKind? sourceKind,
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> remoteId = const Value.absent(),
    Value<String?> creatorHandle = const Value.absent(),
    Value<String?> caption = const Value.absent(),
    List<String>? mediaPaths,
    Value<String?> transcript = const Value.absent(),
    List<String>? onScreenText,
    Value<String?> visualNotes = const Value.absent(),
    Value<String?> language = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    List<KeyPoint>? keyPoints,
    List<ActionItem>? actions,
    Value<String?> topic = const Value.absent(),
    bool? topicChosen,
    List<String>? tags,
    Value<String?> personalNote = const Value.absent(),
    bool? starred,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
    int? openCount,
    Value<String?> errorMessage = const Value.absent(),
    bool? highlightsRevealed,
  }) => NoteRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    sourceKind: sourceKind ?? this.sourceKind,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    creatorHandle: creatorHandle.present
        ? creatorHandle.value
        : this.creatorHandle,
    caption: caption.present ? caption.value : this.caption,
    mediaPaths: mediaPaths ?? this.mediaPaths,
    transcript: transcript.present ? transcript.value : this.transcript,
    onScreenText: onScreenText ?? this.onScreenText,
    visualNotes: visualNotes.present ? visualNotes.value : this.visualNotes,
    language: language.present ? language.value : this.language,
    title: title.present ? title.value : this.title,
    summary: summary.present ? summary.value : this.summary,
    keyPoints: keyPoints ?? this.keyPoints,
    actions: actions ?? this.actions,
    topic: topic.present ? topic.value : this.topic,
    topicChosen: topicChosen ?? this.topicChosen,
    tags: tags ?? this.tags,
    personalNote: personalNote.present ? personalNote.value : this.personalNote,
    starred: starred ?? this.starred,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
    openCount: openCount ?? this.openCount,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    highlightsRevealed: highlightsRevealed ?? this.highlightsRevealed,
  );
  NoteRow copyWithCompanion(NotesCompanion data) {
    return NoteRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      creatorHandle: data.creatorHandle.present
          ? data.creatorHandle.value
          : this.creatorHandle,
      caption: data.caption.present ? data.caption.value : this.caption,
      mediaPaths: data.mediaPaths.present
          ? data.mediaPaths.value
          : this.mediaPaths,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      onScreenText: data.onScreenText.present
          ? data.onScreenText.value
          : this.onScreenText,
      visualNotes: data.visualNotes.present
          ? data.visualNotes.value
          : this.visualNotes,
      language: data.language.present ? data.language.value : this.language,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      keyPoints: data.keyPoints.present ? data.keyPoints.value : this.keyPoints,
      actions: data.actions.present ? data.actions.value : this.actions,
      topic: data.topic.present ? data.topic.value : this.topic,
      topicChosen: data.topicChosen.present
          ? data.topicChosen.value
          : this.topicChosen,
      tags: data.tags.present ? data.tags.value : this.tags,
      personalNote: data.personalNote.present
          ? data.personalNote.value
          : this.personalNote,
      starred: data.starred.present ? data.starred.value : this.starred,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      openCount: data.openCount.present ? data.openCount.value : this.openCount,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      highlightsRevealed: data.highlightsRevealed.present
          ? data.highlightsRevealed.value
          : this.highlightsRevealed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('remoteId: $remoteId, ')
          ..write('creatorHandle: $creatorHandle, ')
          ..write('caption: $caption, ')
          ..write('mediaPaths: $mediaPaths, ')
          ..write('transcript: $transcript, ')
          ..write('onScreenText: $onScreenText, ')
          ..write('visualNotes: $visualNotes, ')
          ..write('language: $language, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('keyPoints: $keyPoints, ')
          ..write('actions: $actions, ')
          ..write('topic: $topic, ')
          ..write('topicChosen: $topicChosen, ')
          ..write('tags: $tags, ')
          ..write('personalNote: $personalNote, ')
          ..write('starred: $starred, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('openCount: $openCount, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('highlightsRevealed: $highlightsRevealed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    status,
    sourceKind,
    sourceUrl,
    remoteId,
    creatorHandle,
    caption,
    mediaPaths,
    transcript,
    onScreenText,
    visualNotes,
    language,
    title,
    summary,
    keyPoints,
    actions,
    topic,
    topicChosen,
    tags,
    personalNote,
    starred,
    lastOpenedAt,
    openCount,
    errorMessage,
    highlightsRevealed,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.sourceKind == this.sourceKind &&
          other.sourceUrl == this.sourceUrl &&
          other.remoteId == this.remoteId &&
          other.creatorHandle == this.creatorHandle &&
          other.caption == this.caption &&
          other.mediaPaths == this.mediaPaths &&
          other.transcript == this.transcript &&
          other.onScreenText == this.onScreenText &&
          other.visualNotes == this.visualNotes &&
          other.language == this.language &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.keyPoints == this.keyPoints &&
          other.actions == this.actions &&
          other.topic == this.topic &&
          other.topicChosen == this.topicChosen &&
          other.tags == this.tags &&
          other.personalNote == this.personalNote &&
          other.starred == this.starred &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.openCount == this.openCount &&
          other.errorMessage == this.errorMessage &&
          other.highlightsRevealed == this.highlightsRevealed);
}

class NotesCompanion extends UpdateCompanion<NoteRow> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<NoteStatus> status;
  final Value<SourceKind> sourceKind;
  final Value<String?> sourceUrl;
  final Value<String?> remoteId;
  final Value<String?> creatorHandle;
  final Value<String?> caption;
  final Value<List<String>> mediaPaths;
  final Value<String?> transcript;
  final Value<List<String>> onScreenText;
  final Value<String?> visualNotes;
  final Value<String?> language;
  final Value<String?> title;
  final Value<String?> summary;
  final Value<List<KeyPoint>> keyPoints;
  final Value<List<ActionItem>> actions;
  final Value<String?> topic;
  final Value<bool> topicChosen;
  final Value<List<String>> tags;
  final Value<String?> personalNote;
  final Value<bool> starred;
  final Value<DateTime?> lastOpenedAt;
  final Value<int> openCount;
  final Value<String?> errorMessage;
  final Value<bool> highlightsRevealed;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.creatorHandle = const Value.absent(),
    this.caption = const Value.absent(),
    this.mediaPaths = const Value.absent(),
    this.transcript = const Value.absent(),
    this.onScreenText = const Value.absent(),
    this.visualNotes = const Value.absent(),
    this.language = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.keyPoints = const Value.absent(),
    this.actions = const Value.absent(),
    this.topic = const Value.absent(),
    this.topicChosen = const Value.absent(),
    this.tags = const Value.absent(),
    this.personalNote = const Value.absent(),
    this.starred = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.openCount = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.highlightsRevealed = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    required NoteStatus status,
    required SourceKind sourceKind,
    this.sourceUrl = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.creatorHandle = const Value.absent(),
    this.caption = const Value.absent(),
    this.mediaPaths = const Value.absent(),
    this.transcript = const Value.absent(),
    this.onScreenText = const Value.absent(),
    this.visualNotes = const Value.absent(),
    this.language = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.keyPoints = const Value.absent(),
    this.actions = const Value.absent(),
    this.topic = const Value.absent(),
    this.topicChosen = const Value.absent(),
    this.tags = const Value.absent(),
    this.personalNote = const Value.absent(),
    this.starred = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.openCount = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.highlightsRevealed = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       status = Value(status),
       sourceKind = Value(sourceKind);
  static Insertable<NoteRow> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? status,
    Expression<String>? sourceKind,
    Expression<String>? sourceUrl,
    Expression<String>? remoteId,
    Expression<String>? creatorHandle,
    Expression<String>? caption,
    Expression<String>? mediaPaths,
    Expression<String>? transcript,
    Expression<String>? onScreenText,
    Expression<String>? visualNotes,
    Expression<String>? language,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? keyPoints,
    Expression<String>? actions,
    Expression<String>? topic,
    Expression<bool>? topicChosen,
    Expression<String>? tags,
    Expression<String>? personalNote,
    Expression<bool>? starred,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? openCount,
    Expression<String>? errorMessage,
    Expression<bool>? highlightsRevealed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (remoteId != null) 'remote_id': remoteId,
      if (creatorHandle != null) 'creator_handle': creatorHandle,
      if (caption != null) 'caption': caption,
      if (mediaPaths != null) 'media_paths': mediaPaths,
      if (transcript != null) 'transcript': transcript,
      if (onScreenText != null) 'on_screen_text': onScreenText,
      if (visualNotes != null) 'visual_notes': visualNotes,
      if (language != null) 'language': language,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (keyPoints != null) 'key_points': keyPoints,
      if (actions != null) 'actions': actions,
      if (topic != null) 'topic': topic,
      if (topicChosen != null) 'topic_chosen': topicChosen,
      if (tags != null) 'tags': tags,
      if (personalNote != null) 'personal_note': personalNote,
      if (starred != null) 'starred': starred,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (openCount != null) 'open_count': openCount,
      if (errorMessage != null) 'error_message': errorMessage,
      if (highlightsRevealed != null) 'highlights_revealed': highlightsRevealed,
    });
  }

  NotesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<NoteStatus>? status,
    Value<SourceKind>? sourceKind,
    Value<String?>? sourceUrl,
    Value<String?>? remoteId,
    Value<String?>? creatorHandle,
    Value<String?>? caption,
    Value<List<String>>? mediaPaths,
    Value<String?>? transcript,
    Value<List<String>>? onScreenText,
    Value<String?>? visualNotes,
    Value<String?>? language,
    Value<String?>? title,
    Value<String?>? summary,
    Value<List<KeyPoint>>? keyPoints,
    Value<List<ActionItem>>? actions,
    Value<String?>? topic,
    Value<bool>? topicChosen,
    Value<List<String>>? tags,
    Value<String?>? personalNote,
    Value<bool>? starred,
    Value<DateTime?>? lastOpenedAt,
    Value<int>? openCount,
    Value<String?>? errorMessage,
    Value<bool>? highlightsRevealed,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      remoteId: remoteId ?? this.remoteId,
      creatorHandle: creatorHandle ?? this.creatorHandle,
      caption: caption ?? this.caption,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      transcript: transcript ?? this.transcript,
      onScreenText: onScreenText ?? this.onScreenText,
      visualNotes: visualNotes ?? this.visualNotes,
      language: language ?? this.language,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      keyPoints: keyPoints ?? this.keyPoints,
      actions: actions ?? this.actions,
      topic: topic ?? this.topic,
      topicChosen: topicChosen ?? this.topicChosen,
      tags: tags ?? this.tags,
      personalNote: personalNote ?? this.personalNote,
      starred: starred ?? this.starred,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      openCount: openCount ?? this.openCount,
      errorMessage: errorMessage ?? this.errorMessage,
      highlightsRevealed: highlightsRevealed ?? this.highlightsRevealed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $NotesTable.$converterstatus.toSql(status.value),
      );
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(
        $NotesTable.$convertersourceKind.toSql(sourceKind.value),
      );
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (creatorHandle.present) {
      map['creator_handle'] = Variable<String>(creatorHandle.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (mediaPaths.present) {
      map['media_paths'] = Variable<String>(
        $NotesTable.$convertermediaPaths.toSql(mediaPaths.value),
      );
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (onScreenText.present) {
      map['on_screen_text'] = Variable<String>(
        $NotesTable.$converteronScreenText.toSql(onScreenText.value),
      );
    }
    if (visualNotes.present) {
      map['visual_notes'] = Variable<String>(visualNotes.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (keyPoints.present) {
      map['key_points'] = Variable<String>(
        $NotesTable.$converterkeyPoints.toSql(keyPoints.value),
      );
    }
    if (actions.present) {
      map['actions'] = Variable<String>(
        $NotesTable.$converteractions.toSql(actions.value),
      );
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (topicChosen.present) {
      map['topic_chosen'] = Variable<bool>(topicChosen.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(
        $NotesTable.$convertertags.toSql(tags.value),
      );
    }
    if (personalNote.present) {
      map['personal_note'] = Variable<String>(personalNote.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (openCount.present) {
      map['open_count'] = Variable<int>(openCount.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (highlightsRevealed.present) {
      map['highlights_revealed'] = Variable<bool>(highlightsRevealed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('remoteId: $remoteId, ')
          ..write('creatorHandle: $creatorHandle, ')
          ..write('caption: $caption, ')
          ..write('mediaPaths: $mediaPaths, ')
          ..write('transcript: $transcript, ')
          ..write('onScreenText: $onScreenText, ')
          ..write('visualNotes: $visualNotes, ')
          ..write('language: $language, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('keyPoints: $keyPoints, ')
          ..write('actions: $actions, ')
          ..write('topic: $topic, ')
          ..write('topicChosen: $topicChosen, ')
          ..write('tags: $tags, ')
          ..write('personalNote: $personalNote, ')
          ..write('starred: $starred, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('openCount: $openCount, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('highlightsRevealed: $highlightsRevealed')
          ..write(')'))
        .toString();
  }
}

class $SeenPostsTable extends SeenPosts
    with TableInfo<$SeenPostsTable, SeenPostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeenPostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pkMeta = const VerificationMeta('pk');
  @override
  late final GeneratedColumn<String> pk = GeneratedColumn<String>(
    'pk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenAtMeta = const VerificationMeta('seenAt');
  @override
  late final GeneratedColumn<DateTime> seenAt = GeneratedColumn<DateTime>(
    'seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [pk, seenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seen_posts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeenPostRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pk')) {
      context.handle(_pkMeta, pk.isAcceptableOrUnknown(data['pk']!, _pkMeta));
    } else if (isInserting) {
      context.missing(_pkMeta);
    }
    if (data.containsKey('seen_at')) {
      context.handle(
        _seenAtMeta,
        seenAt.isAcceptableOrUnknown(data['seen_at']!, _seenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_seenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pk};
  @override
  SeenPostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeenPostRow(
      pk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pk'],
      )!,
      seenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}seen_at'],
      )!,
    );
  }

  @override
  $SeenPostsTable createAlias(String alias) {
    return $SeenPostsTable(attachedDatabase, alias);
  }
}

class SeenPostRow extends DataClass implements Insertable<SeenPostRow> {
  final String pk;
  final DateTime seenAt;
  const SeenPostRow({required this.pk, required this.seenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pk'] = Variable<String>(pk);
    map['seen_at'] = Variable<DateTime>(seenAt);
    return map;
  }

  SeenPostsCompanion toCompanion(bool nullToAbsent) {
    return SeenPostsCompanion(pk: Value(pk), seenAt: Value(seenAt));
  }

  factory SeenPostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeenPostRow(
      pk: serializer.fromJson<String>(json['pk']),
      seenAt: serializer.fromJson<DateTime>(json['seenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pk': serializer.toJson<String>(pk),
      'seenAt': serializer.toJson<DateTime>(seenAt),
    };
  }

  SeenPostRow copyWith({String? pk, DateTime? seenAt}) =>
      SeenPostRow(pk: pk ?? this.pk, seenAt: seenAt ?? this.seenAt);
  SeenPostRow copyWithCompanion(SeenPostsCompanion data) {
    return SeenPostRow(
      pk: data.pk.present ? data.pk.value : this.pk,
      seenAt: data.seenAt.present ? data.seenAt.value : this.seenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeenPostRow(')
          ..write('pk: $pk, ')
          ..write('seenAt: $seenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pk, seenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeenPostRow &&
          other.pk == this.pk &&
          other.seenAt == this.seenAt);
}

class SeenPostsCompanion extends UpdateCompanion<SeenPostRow> {
  final Value<String> pk;
  final Value<DateTime> seenAt;
  final Value<int> rowid;
  const SeenPostsCompanion({
    this.pk = const Value.absent(),
    this.seenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeenPostsCompanion.insert({
    required String pk,
    required DateTime seenAt,
    this.rowid = const Value.absent(),
  }) : pk = Value(pk),
       seenAt = Value(seenAt);
  static Insertable<SeenPostRow> custom({
    Expression<String>? pk,
    Expression<DateTime>? seenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pk != null) 'pk': pk,
      if (seenAt != null) 'seen_at': seenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeenPostsCompanion copyWith({
    Value<String>? pk,
    Value<DateTime>? seenAt,
    Value<int>? rowid,
  }) {
    return SeenPostsCompanion(
      pk: pk ?? this.pk,
      seenAt: seenAt ?? this.seenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pk.present) {
      map['pk'] = Variable<String>(pk.value);
    }
    if (seenAt.present) {
      map['seen_at'] = Variable<DateTime>(seenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeenPostsCompanion(')
          ..write('pk: $pk, ')
          ..write('seenAt: $seenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiCallsTable extends AiCalls with TableInfo<$AiCallsTable, AiCallRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiCallsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<int> noteId = GeneratedColumn<int>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputTokensMeta = const VerificationMeta(
    'inputTokens',
  );
  @override
  late final GeneratedColumn<int> inputTokens = GeneratedColumn<int>(
    'input_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputTokensMeta = const VerificationMeta(
    'outputTokens',
  );
  @override
  late final GeneratedColumn<int> outputTokens = GeneratedColumn<int>(
    'output_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costMicroUsdMeta = const VerificationMeta(
    'costMicroUsd',
  );
  @override
  late final GeneratedColumn<int> costMicroUsd = GeneratedColumn<int>(
    'cost_micro_usd',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    at,
    model,
    inputTokens,
    outputTokens,
    costMicroUsd,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_calls';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiCallRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('input_tokens')) {
      context.handle(
        _inputTokensMeta,
        inputTokens.isAcceptableOrUnknown(
          data['input_tokens']!,
          _inputTokensMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputTokensMeta);
    }
    if (data.containsKey('output_tokens')) {
      context.handle(
        _outputTokensMeta,
        outputTokens.isAcceptableOrUnknown(
          data['output_tokens']!,
          _outputTokensMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outputTokensMeta);
    }
    if (data.containsKey('cost_micro_usd')) {
      context.handle(
        _costMicroUsdMeta,
        costMicroUsd.isAcceptableOrUnknown(
          data['cost_micro_usd']!,
          _costMicroUsdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiCallRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiCallRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}note_id'],
      ),
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      inputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_tokens'],
      )!,
      outputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_tokens'],
      )!,
      costMicroUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_micro_usd'],
      ),
    );
  }

  @override
  $AiCallsTable createAlias(String alias) {
    return $AiCallsTable(attachedDatabase, alias);
  }
}

class AiCallRow extends DataClass implements Insertable<AiCallRow> {
  final int id;
  final int? noteId;
  final DateTime at;
  final String model;
  final int inputTokens;
  final int outputTokens;

  /// Null when the model's price isn't known to Commonplace.
  final int? costMicroUsd;
  const AiCallRow({
    required this.id,
    this.noteId,
    required this.at,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    this.costMicroUsd,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<int>(noteId);
    }
    map['at'] = Variable<DateTime>(at);
    map['model'] = Variable<String>(model);
    map['input_tokens'] = Variable<int>(inputTokens);
    map['output_tokens'] = Variable<int>(outputTokens);
    if (!nullToAbsent || costMicroUsd != null) {
      map['cost_micro_usd'] = Variable<int>(costMicroUsd);
    }
    return map;
  }

  AiCallsCompanion toCompanion(bool nullToAbsent) {
    return AiCallsCompanion(
      id: Value(id),
      noteId: noteId == null && nullToAbsent
          ? const Value.absent()
          : Value(noteId),
      at: Value(at),
      model: Value(model),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      costMicroUsd: costMicroUsd == null && nullToAbsent
          ? const Value.absent()
          : Value(costMicroUsd),
    );
  }

  factory AiCallRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiCallRow(
      id: serializer.fromJson<int>(json['id']),
      noteId: serializer.fromJson<int?>(json['noteId']),
      at: serializer.fromJson<DateTime>(json['at']),
      model: serializer.fromJson<String>(json['model']),
      inputTokens: serializer.fromJson<int>(json['inputTokens']),
      outputTokens: serializer.fromJson<int>(json['outputTokens']),
      costMicroUsd: serializer.fromJson<int?>(json['costMicroUsd']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'noteId': serializer.toJson<int?>(noteId),
      'at': serializer.toJson<DateTime>(at),
      'model': serializer.toJson<String>(model),
      'inputTokens': serializer.toJson<int>(inputTokens),
      'outputTokens': serializer.toJson<int>(outputTokens),
      'costMicroUsd': serializer.toJson<int?>(costMicroUsd),
    };
  }

  AiCallRow copyWith({
    int? id,
    Value<int?> noteId = const Value.absent(),
    DateTime? at,
    String? model,
    int? inputTokens,
    int? outputTokens,
    Value<int?> costMicroUsd = const Value.absent(),
  }) => AiCallRow(
    id: id ?? this.id,
    noteId: noteId.present ? noteId.value : this.noteId,
    at: at ?? this.at,
    model: model ?? this.model,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    costMicroUsd: costMicroUsd.present ? costMicroUsd.value : this.costMicroUsd,
  );
  AiCallRow copyWithCompanion(AiCallsCompanion data) {
    return AiCallRow(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      at: data.at.present ? data.at.value : this.at,
      model: data.model.present ? data.model.value : this.model,
      inputTokens: data.inputTokens.present
          ? data.inputTokens.value
          : this.inputTokens,
      outputTokens: data.outputTokens.present
          ? data.outputTokens.value
          : this.outputTokens,
      costMicroUsd: data.costMicroUsd.present
          ? data.costMicroUsd.value
          : this.costMicroUsd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiCallRow(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('at: $at, ')
          ..write('model: $model, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('costMicroUsd: $costMicroUsd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    noteId,
    at,
    model,
    inputTokens,
    outputTokens,
    costMicroUsd,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiCallRow &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.at == this.at &&
          other.model == this.model &&
          other.inputTokens == this.inputTokens &&
          other.outputTokens == this.outputTokens &&
          other.costMicroUsd == this.costMicroUsd);
}

class AiCallsCompanion extends UpdateCompanion<AiCallRow> {
  final Value<int> id;
  final Value<int?> noteId;
  final Value<DateTime> at;
  final Value<String> model;
  final Value<int> inputTokens;
  final Value<int> outputTokens;
  final Value<int?> costMicroUsd;
  const AiCallsCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.at = const Value.absent(),
    this.model = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.costMicroUsd = const Value.absent(),
  });
  AiCallsCompanion.insert({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    required DateTime at,
    required String model,
    required int inputTokens,
    required int outputTokens,
    this.costMicroUsd = const Value.absent(),
  }) : at = Value(at),
       model = Value(model),
       inputTokens = Value(inputTokens),
       outputTokens = Value(outputTokens);
  static Insertable<AiCallRow> custom({
    Expression<int>? id,
    Expression<int>? noteId,
    Expression<DateTime>? at,
    Expression<String>? model,
    Expression<int>? inputTokens,
    Expression<int>? outputTokens,
    Expression<int>? costMicroUsd,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (at != null) 'at': at,
      if (model != null) 'model': model,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      if (costMicroUsd != null) 'cost_micro_usd': costMicroUsd,
    });
  }

  AiCallsCompanion copyWith({
    Value<int>? id,
    Value<int?>? noteId,
    Value<DateTime>? at,
    Value<String>? model,
    Value<int>? inputTokens,
    Value<int>? outputTokens,
    Value<int?>? costMicroUsd,
  }) {
    return AiCallsCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      at: at ?? this.at,
      model: model ?? this.model,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      costMicroUsd: costMicroUsd ?? this.costMicroUsd,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<int>(noteId.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (inputTokens.present) {
      map['input_tokens'] = Variable<int>(inputTokens.value);
    }
    if (outputTokens.present) {
      map['output_tokens'] = Variable<int>(outputTokens.value);
    }
    if (costMicroUsd.present) {
      map['cost_micro_usd'] = Variable<int>(costMicroUsd.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiCallsCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('at: $at, ')
          ..write('model: $model, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('costMicroUsd: $costMicroUsd')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $SeenPostsTable seenPosts = $SeenPostsTable(this);
  late final $AiCallsTable aiCalls = $AiCallsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    notes,
    seenPosts,
    aiCalls,
  ];
}

typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  required DateTime createdAt,
  required DateTime updatedAt,
  required NoteStatus status,
  required SourceKind sourceKind,
  Value<String?> sourceUrl,
  Value<String?> remoteId,
  Value<String?> creatorHandle,
  Value<String?> caption,
  Value<List<String>> mediaPaths,
  Value<String?> transcript,
  Value<List<String>> onScreenText,
  Value<String?> visualNotes,
  Value<String?> language,
  Value<String?> title,
  Value<String?> summary,
  Value<List<KeyPoint>> keyPoints,
  Value<List<ActionItem>> actions,
  Value<String?> topic,
  Value<bool> topicChosen,
  Value<List<String>> tags,
  Value<String?> personalNote,
  Value<bool> starred,
  Value<DateTime?> lastOpenedAt,
  Value<int> openCount,
  Value<String?> errorMessage,
  Value<bool> highlightsRevealed,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<NoteStatus> status,
  Value<SourceKind> sourceKind,
  Value<String?> sourceUrl,
  Value<String?> remoteId,
  Value<String?> creatorHandle,
  Value<String?> caption,
  Value<List<String>> mediaPaths,
  Value<String?> transcript,
  Value<List<String>> onScreenText,
  Value<String?> visualNotes,
  Value<String?> language,
  Value<String?> title,
  Value<String?> summary,
  Value<List<KeyPoint>> keyPoints,
  Value<List<ActionItem>> actions,
  Value<String?> topic,
  Value<bool> topicChosen,
  Value<List<String>> tags,
  Value<String?> personalNote,
  Value<bool> starred,
  Value<DateTime?> lastOpenedAt,
  Value<int> openCount,
  Value<String?> errorMessage,
  Value<bool> highlightsRevealed,
});

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<NoteStatus, NoteStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<SourceKind, SourceKind, String>
  get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatorHandle => $composableBuilder(
    column: $table.creatorHandle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get mediaPaths => $composableBuilder(
    column: $table.mediaPaths,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get onScreenText => $composableBuilder(
    column: $table.onScreenText,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get visualNotes => $composableBuilder(
    column: $table.visualNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<KeyPoint>, List<KeyPoint>, String>
  get keyPoints => $composableBuilder(
    column: $table.keyPoints,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<ActionItem>, List<ActionItem>, String>
  get actions => $composableBuilder(
    column: $table.actions,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get topicChosen => $composableBuilder(
    column: $table.topicChosen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
        column: $table.tags,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get personalNote => $composableBuilder(
    column: $table.personalNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openCount => $composableBuilder(
    column: $table.openCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get highlightsRevealed => $composableBuilder(
    column: $table.highlightsRevealed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatorHandle => $composableBuilder(
    column: $table.creatorHandle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaPaths => $composableBuilder(
    column: $table.mediaPaths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get onScreenText => $composableBuilder(
    column: $table.onScreenText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visualNotes => $composableBuilder(
    column: $table.visualNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyPoints => $composableBuilder(
    column: $table.keyPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actions => $composableBuilder(
    column: $table.actions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get topicChosen => $composableBuilder(
    column: $table.topicChosen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personalNote => $composableBuilder(
    column: $table.personalNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openCount => $composableBuilder(
    column: $table.openCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get highlightsRevealed => $composableBuilder(
    column: $table.highlightsRevealed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NoteStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SourceKind, String> get sourceKind =>
      $composableBuilder(
        column: $table.sourceKind,
        builder: (column) => column,
      );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get creatorHandle => $composableBuilder(
    column: $table.creatorHandle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get mediaPaths =>
      $composableBuilder(
        column: $table.mediaPaths,
        builder: (column) => column,
      );

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get onScreenText =>
      $composableBuilder(
        column: $table.onScreenText,
        builder: (column) => column,
      );

  GeneratedColumn<String> get visualNotes => $composableBuilder(
    column: $table.visualNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<KeyPoint>, String> get keyPoints =>
      $composableBuilder(column: $table.keyPoints, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<ActionItem>, String> get actions =>
      $composableBuilder(column: $table.actions, builder: (column) => column);

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<bool> get topicChosen => $composableBuilder(
    column: $table.topicChosen,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get personalNote => $composableBuilder(
    column: $table.personalNote,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get openCount =>
      $composableBuilder(column: $table.openCount, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get highlightsRevealed => $composableBuilder(
    column: $table.highlightsRevealed,
    builder: (column) => column,
  );
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          NoteRow,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (NoteRow, BaseReferences<_$AppDatabase, $NotesTable, NoteRow>),
          NoteRow,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<NoteStatus> status = const Value.absent(),
                Value<SourceKind> sourceKind = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> creatorHandle = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<List<String>> mediaPaths = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<List<String>> onScreenText = const Value.absent(),
                Value<String?> visualNotes = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<List<KeyPoint>> keyPoints = const Value.absent(),
                Value<List<ActionItem>> actions = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<bool> topicChosen = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<String?> personalNote = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> openCount = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<bool> highlightsRevealed = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                sourceKind: sourceKind,
                sourceUrl: sourceUrl,
                remoteId: remoteId,
                creatorHandle: creatorHandle,
                caption: caption,
                mediaPaths: mediaPaths,
                transcript: transcript,
                onScreenText: onScreenText,
                visualNotes: visualNotes,
                language: language,
                title: title,
                summary: summary,
                keyPoints: keyPoints,
                actions: actions,
                topic: topic,
                topicChosen: topicChosen,
                tags: tags,
                personalNote: personalNote,
                starred: starred,
                lastOpenedAt: lastOpenedAt,
                openCount: openCount,
                errorMessage: errorMessage,
                highlightsRevealed: highlightsRevealed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                required NoteStatus status,
                required SourceKind sourceKind,
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> creatorHandle = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<List<String>> mediaPaths = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<List<String>> onScreenText = const Value.absent(),
                Value<String?> visualNotes = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<List<KeyPoint>> keyPoints = const Value.absent(),
                Value<List<ActionItem>> actions = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<bool> topicChosen = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<String?> personalNote = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> openCount = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<bool> highlightsRevealed = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                sourceKind: sourceKind,
                sourceUrl: sourceUrl,
                remoteId: remoteId,
                creatorHandle: creatorHandle,
                caption: caption,
                mediaPaths: mediaPaths,
                transcript: transcript,
                onScreenText: onScreenText,
                visualNotes: visualNotes,
                language: language,
                title: title,
                summary: summary,
                keyPoints: keyPoints,
                actions: actions,
                topic: topic,
                topicChosen: topicChosen,
                tags: tags,
                personalNote: personalNote,
                starred: starred,
                lastOpenedAt: lastOpenedAt,
                openCount: openCount,
                errorMessage: errorMessage,
                highlightsRevealed: highlightsRevealed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, NoteRow>(table),
                  BaseReferences<_$AppDatabase, $NotesTable, NoteRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      NoteRow,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (NoteRow, BaseReferences<_$AppDatabase, $NotesTable, NoteRow>),
      NoteRow,
      PrefetchHooks Function()
    >;
typedef $$SeenPostsTableCreateCompanionBuilder = SeenPostsCompanion Function({
  required String pk,
  required DateTime seenAt,
  Value<int> rowid,
});
typedef $$SeenPostsTableUpdateCompanionBuilder = SeenPostsCompanion Function({
  Value<String> pk,
  Value<DateTime> seenAt,
  Value<int> rowid,
});

class $$SeenPostsTableFilterComposer
    extends Composer<_$AppDatabase, $SeenPostsTable> {
  $$SeenPostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeenPostsTableOrderingComposer
    extends Composer<_$AppDatabase, $SeenPostsTable> {
  $$SeenPostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeenPostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeenPostsTable> {
  $$SeenPostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pk =>
      $composableBuilder(column: $table.pk, builder: (column) => column);

  GeneratedColumn<DateTime> get seenAt =>
      $composableBuilder(column: $table.seenAt, builder: (column) => column);
}

class $$SeenPostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeenPostsTable,
          SeenPostRow,
          $$SeenPostsTableFilterComposer,
          $$SeenPostsTableOrderingComposer,
          $$SeenPostsTableAnnotationComposer,
          $$SeenPostsTableCreateCompanionBuilder,
          $$SeenPostsTableUpdateCompanionBuilder,
          (
            SeenPostRow,
            BaseReferences<_$AppDatabase, $SeenPostsTable, SeenPostRow>,
          ),
          SeenPostRow,
          PrefetchHooks Function()
        > {
  $$SeenPostsTableTableManager(_$AppDatabase db, $SeenPostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeenPostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeenPostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeenPostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> pk = const Value.absent(),
            Value<DateTime> seenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SeenPostsCompanion(pk: pk, seenAt: seenAt, rowid: rowid),
          createCompanionCallback: ({
            required String pk,
            required DateTime seenAt,
            Value<int> rowid = const Value.absent(),
          }) => SeenPostsCompanion.insert(pk: pk, seenAt: seenAt, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeenPostsTable, SeenPostRow>(table),
                  BaseReferences<_$AppDatabase, $SeenPostsTable, SeenPostRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeenPostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeenPostsTable,
      SeenPostRow,
      $$SeenPostsTableFilterComposer,
      $$SeenPostsTableOrderingComposer,
      $$SeenPostsTableAnnotationComposer,
      $$SeenPostsTableCreateCompanionBuilder,
      $$SeenPostsTableUpdateCompanionBuilder,
      (
        SeenPostRow,
        BaseReferences<_$AppDatabase, $SeenPostsTable, SeenPostRow>,
      ),
      SeenPostRow,
      PrefetchHooks Function()
    >;
typedef $$AiCallsTableCreateCompanionBuilder = AiCallsCompanion Function({
  Value<int> id,
  Value<int?> noteId,
  required DateTime at,
  required String model,
  required int inputTokens,
  required int outputTokens,
  Value<int?> costMicroUsd,
});
typedef $$AiCallsTableUpdateCompanionBuilder = AiCallsCompanion Function({
  Value<int> id,
  Value<int?> noteId,
  Value<DateTime> at,
  Value<String> model,
  Value<int> inputTokens,
  Value<int> outputTokens,
  Value<int?> costMicroUsd,
});

class $$AiCallsTableFilterComposer
    extends Composer<_$AppDatabase, $AiCallsTable> {
  $$AiCallsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costMicroUsd => $composableBuilder(
    column: $table.costMicroUsd,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiCallsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiCallsTable> {
  $$AiCallsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costMicroUsd => $composableBuilder(
    column: $table.costMicroUsd,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiCallsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiCallsTable> {
  $$AiCallsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costMicroUsd => $composableBuilder(
    column: $table.costMicroUsd,
    builder: (column) => column,
  );
}

class $$AiCallsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiCallsTable,
          AiCallRow,
          $$AiCallsTableFilterComposer,
          $$AiCallsTableOrderingComposer,
          $$AiCallsTableAnnotationComposer,
          $$AiCallsTableCreateCompanionBuilder,
          $$AiCallsTableUpdateCompanionBuilder,
          (AiCallRow, BaseReferences<_$AppDatabase, $AiCallsTable, AiCallRow>),
          AiCallRow,
          PrefetchHooks Function()
        > {
  $$AiCallsTableTableManager(_$AppDatabase db, $AiCallsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiCallsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiCallsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiCallsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> noteId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> inputTokens = const Value.absent(),
                Value<int> outputTokens = const Value.absent(),
                Value<int?> costMicroUsd = const Value.absent(),
              }) => AiCallsCompanion(
                id: id,
                noteId: noteId,
                at: at,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                costMicroUsd: costMicroUsd,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> noteId = const Value.absent(),
                required DateTime at,
                required String model,
                required int inputTokens,
                required int outputTokens,
                Value<int?> costMicroUsd = const Value.absent(),
              }) => AiCallsCompanion.insert(
                id: id,
                noteId: noteId,
                at: at,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                costMicroUsd: costMicroUsd,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiCallsTable, AiCallRow>(table),
                  BaseReferences<_$AppDatabase, $AiCallsTable, AiCallRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiCallsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiCallsTable,
      AiCallRow,
      $$AiCallsTableFilterComposer,
      $$AiCallsTableOrderingComposer,
      $$AiCallsTableAnnotationComposer,
      $$AiCallsTableCreateCompanionBuilder,
      $$AiCallsTableUpdateCompanionBuilder,
      (AiCallRow, BaseReferences<_$AppDatabase, $AiCallsTable, AiCallRow>),
      AiCallRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$SeenPostsTableTableManager get seenPosts =>
      $$SeenPostsTableTableManager(_db, _db.seenPosts);
  $$AiCallsTableTableManager get aiCalls =>
      $$AiCallsTableTableManager(_db, _db.aiCalls);
}
