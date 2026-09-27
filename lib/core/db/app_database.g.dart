// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ocrTextMeta = const VerificationMeta(
    'ocrText',
  );
  @override
  late final GeneratedColumn<String> ocrText = GeneratedColumn<String>(
    'ocr_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _pressedPdfPathMeta = const VerificationMeta(
    'pressedPdfPath',
  );
  @override
  late final GeneratedColumn<String> pressedPdfPath = GeneratedColumn<String>(
    'pressed_pdf_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fillablePdfPathMeta = const VerificationMeta(
    'fillablePdfPath',
  );
  @override
  late final GeneratedColumn<String> fillablePdfPath = GeneratedColumn<String>(
    'fillable_pdf_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isTemplateMeta = const VerificationMeta(
    'isTemplate',
  );
  @override
  late final GeneratedColumn<bool> isTemplate = GeneratedColumn<bool>(
    'is_template',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_template" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _textSizeMeta = const VerificationMeta(
    'textSize',
  );
  @override
  late final GeneratedColumn<double> textSize = GeneratedColumn<double>(
    'text_size',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    title,
    status,
    pageCount,
    ocrText,
    createdAt,
    updatedAt,
    pressedPdfPath,
    fillablePdfPath,
    isTemplate,
    textSize,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Document> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('ocr_text')) {
      context.handle(
        _ocrTextMeta,
        ocrText.isAcceptableOrUnknown(data['ocr_text']!, _ocrTextMeta),
      );
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
    if (data.containsKey('pressed_pdf_path')) {
      context.handle(
        _pressedPdfPathMeta,
        pressedPdfPath.isAcceptableOrUnknown(
          data['pressed_pdf_path']!,
          _pressedPdfPathMeta,
        ),
      );
    }
    if (data.containsKey('fillable_pdf_path')) {
      context.handle(
        _fillablePdfPathMeta,
        fillablePdfPath.isAcceptableOrUnknown(
          data['fillable_pdf_path']!,
          _fillablePdfPathMeta,
        ),
      );
    }
    if (data.containsKey('is_template')) {
      context.handle(
        _isTemplateMeta,
        isTemplate.isAcceptableOrUnknown(data['is_template']!, _isTemplateMeta),
      );
    }
    if (data.containsKey('text_size')) {
      context.handle(
        _textSizeMeta,
        textSize.isAcceptableOrUnknown(data['text_size']!, _textSizeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      ocrText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      pressedPdfPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pressed_pdf_path'],
      ),
      fillablePdfPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fillable_pdf_path'],
      ),
      isTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_template'],
      )!,
      textSize: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}text_size'],
      ),
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class Document extends DataClass implements Insertable<Document> {
  final int id;
  final String uuid;
  final String title;
  final String status;
  final int pageCount;
  final String ocrText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? pressedPdfPath;
  final String? fillablePdfPath;
  final bool isTemplate;
  final double? textSize;
  const Document({
    required this.id,
    required this.uuid,
    required this.title,
    required this.status,
    required this.pageCount,
    required this.ocrText,
    required this.createdAt,
    required this.updatedAt,
    this.pressedPdfPath,
    this.fillablePdfPath,
    required this.isTemplate,
    this.textSize,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['title'] = Variable<String>(title);
    map['status'] = Variable<String>(status);
    map['page_count'] = Variable<int>(pageCount);
    map['ocr_text'] = Variable<String>(ocrText);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || pressedPdfPath != null) {
      map['pressed_pdf_path'] = Variable<String>(pressedPdfPath);
    }
    if (!nullToAbsent || fillablePdfPath != null) {
      map['fillable_pdf_path'] = Variable<String>(fillablePdfPath);
    }
    map['is_template'] = Variable<bool>(isTemplate);
    if (!nullToAbsent || textSize != null) {
      map['text_size'] = Variable<double>(textSize);
    }
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      title: Value(title),
      status: Value(status),
      pageCount: Value(pageCount),
      ocrText: Value(ocrText),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pressedPdfPath: pressedPdfPath == null && nullToAbsent
          ? const Value.absent()
          : Value(pressedPdfPath),
      fillablePdfPath: fillablePdfPath == null && nullToAbsent
          ? const Value.absent()
          : Value(fillablePdfPath),
      isTemplate: Value(isTemplate),
      textSize: textSize == null && nullToAbsent
          ? const Value.absent()
          : Value(textSize),
    );
  }

  factory Document.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      title: serializer.fromJson<String>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      ocrText: serializer.fromJson<String>(json['ocrText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      pressedPdfPath: serializer.fromJson<String?>(json['pressedPdfPath']),
      fillablePdfPath: serializer.fromJson<String?>(json['fillablePdfPath']),
      isTemplate: serializer.fromJson<bool>(json['isTemplate']),
      textSize: serializer.fromJson<double?>(json['textSize']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'title': serializer.toJson<String>(title),
      'status': serializer.toJson<String>(status),
      'pageCount': serializer.toJson<int>(pageCount),
      'ocrText': serializer.toJson<String>(ocrText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'pressedPdfPath': serializer.toJson<String?>(pressedPdfPath),
      'fillablePdfPath': serializer.toJson<String?>(fillablePdfPath),
      'isTemplate': serializer.toJson<bool>(isTemplate),
      'textSize': serializer.toJson<double?>(textSize),
    };
  }

  Document copyWith({
    int? id,
    String? uuid,
    String? title,
    String? status,
    int? pageCount,
    String? ocrText,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> pressedPdfPath = const Value.absent(),
    Value<String?> fillablePdfPath = const Value.absent(),
    bool? isTemplate,
    Value<double?> textSize = const Value.absent(),
  }) => Document(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    title: title ?? this.title,
    status: status ?? this.status,
    pageCount: pageCount ?? this.pageCount,
    ocrText: ocrText ?? this.ocrText,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pressedPdfPath: pressedPdfPath.present
        ? pressedPdfPath.value
        : this.pressedPdfPath,
    fillablePdfPath: fillablePdfPath.present
        ? fillablePdfPath.value
        : this.fillablePdfPath,
    isTemplate: isTemplate ?? this.isTemplate,
    textSize: textSize.present ? textSize.value : this.textSize,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      ocrText: data.ocrText.present ? data.ocrText.value : this.ocrText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      pressedPdfPath: data.pressedPdfPath.present
          ? data.pressedPdfPath.value
          : this.pressedPdfPath,
      fillablePdfPath: data.fillablePdfPath.present
          ? data.fillablePdfPath.value
          : this.fillablePdfPath,
      isTemplate: data.isTemplate.present
          ? data.isTemplate.value
          : this.isTemplate,
      textSize: data.textSize.present ? data.textSize.value : this.textSize,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('pageCount: $pageCount, ')
          ..write('ocrText: $ocrText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pressedPdfPath: $pressedPdfPath, ')
          ..write('fillablePdfPath: $fillablePdfPath, ')
          ..write('isTemplate: $isTemplate, ')
          ..write('textSize: $textSize')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    title,
    status,
    pageCount,
    ocrText,
    createdAt,
    updatedAt,
    pressedPdfPath,
    fillablePdfPath,
    isTemplate,
    textSize,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.title == this.title &&
          other.status == this.status &&
          other.pageCount == this.pageCount &&
          other.ocrText == this.ocrText &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.pressedPdfPath == this.pressedPdfPath &&
          other.fillablePdfPath == this.fillablePdfPath &&
          other.isTemplate == this.isTemplate &&
          other.textSize == this.textSize);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> title;
  final Value<String> status;
  final Value<int> pageCount;
  final Value<String> ocrText;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> pressedPdfPath;
  final Value<String?> fillablePdfPath;
  final Value<bool> isTemplate;
  final Value<double?> textSize;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pressedPdfPath = const Value.absent(),
    this.fillablePdfPath = const Value.absent(),
    this.isTemplate = const Value.absent(),
    this.textSize = const Value.absent(),
  });
  DocumentsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String title,
    this.status = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.ocrText = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.pressedPdfPath = const Value.absent(),
    this.fillablePdfPath = const Value.absent(),
    this.isTemplate = const Value.absent(),
    this.textSize = const Value.absent(),
  }) : uuid = Value(uuid),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Document> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? title,
    Expression<String>? status,
    Expression<int>? pageCount,
    Expression<String>? ocrText,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? pressedPdfPath,
    Expression<String>? fillablePdfPath,
    Expression<bool>? isTemplate,
    Expression<double>? textSize,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (pageCount != null) 'page_count': pageCount,
      if (ocrText != null) 'ocr_text': ocrText,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pressedPdfPath != null) 'pressed_pdf_path': pressedPdfPath,
      if (fillablePdfPath != null) 'fillable_pdf_path': fillablePdfPath,
      if (isTemplate != null) 'is_template': isTemplate,
      if (textSize != null) 'text_size': textSize,
    });
  }

  DocumentsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? title,
    Value<String>? status,
    Value<int>? pageCount,
    Value<String>? ocrText,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? pressedPdfPath,
    Value<String?>? fillablePdfPath,
    Value<bool>? isTemplate,
    Value<double?>? textSize,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      status: status ?? this.status,
      pageCount: pageCount ?? this.pageCount,
      ocrText: ocrText ?? this.ocrText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pressedPdfPath: pressedPdfPath ?? this.pressedPdfPath,
      fillablePdfPath: fillablePdfPath ?? this.fillablePdfPath,
      isTemplate: isTemplate ?? this.isTemplate,
      textSize: textSize ?? this.textSize,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (ocrText.present) {
      map['ocr_text'] = Variable<String>(ocrText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (pressedPdfPath.present) {
      map['pressed_pdf_path'] = Variable<String>(pressedPdfPath.value);
    }
    if (fillablePdfPath.present) {
      map['fillable_pdf_path'] = Variable<String>(fillablePdfPath.value);
    }
    if (isTemplate.present) {
      map['is_template'] = Variable<bool>(isTemplate.value);
    }
    if (textSize.present) {
      map['text_size'] = Variable<double>(textSize.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('pageCount: $pageCount, ')
          ..write('ocrText: $ocrText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pressedPdfPath: $pressedPdfPath, ')
          ..write('fillablePdfPath: $fillablePdfPath, ')
          ..write('isTemplate: $isTemplate, ')
          ..write('textSize: $textSize')
          ..write(')'))
        .toString();
  }
}

class $PagesTable extends Pages with TableInfo<$PagesTable, Page> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PagesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<int> documentId = GeneratedColumn<int>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id)',
    ),
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeFilterMeta = const VerificationMeta(
    'activeFilter',
  );
  @override
  late final GeneratedColumn<String> activeFilter = GeneratedColumn<String>(
    'active_filter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('enhanced'),
  );
  static const VerificationMeta _ocrTextMeta = const VerificationMeta(
    'ocrText',
  );
  @override
  late final GeneratedColumn<String> ocrText = GeneratedColumn<String>(
    'ocr_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    pageIndex,
    imagePath,
    activeFilter,
    ocrText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Page> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('active_filter')) {
      context.handle(
        _activeFilterMeta,
        activeFilter.isAcceptableOrUnknown(
          data['active_filter']!,
          _activeFilterMeta,
        ),
      );
    }
    if (data.containsKey('ocr_text')) {
      context.handle(
        _ocrTextMeta,
        ocrText.isAcceptableOrUnknown(data['ocr_text']!, _ocrTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Page map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Page(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}document_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      activeFilter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_filter'],
      )!,
      ocrText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_text'],
      )!,
    );
  }

  @override
  $PagesTable createAlias(String alias) {
    return $PagesTable(attachedDatabase, alias);
  }
}

class Page extends DataClass implements Insertable<Page> {
  final int id;
  final int documentId;
  final int pageIndex;
  final String imagePath;
  final String activeFilter;
  final String ocrText;
  const Page({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.imagePath,
    required this.activeFilter,
    required this.ocrText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['document_id'] = Variable<int>(documentId);
    map['page_index'] = Variable<int>(pageIndex);
    map['image_path'] = Variable<String>(imagePath);
    map['active_filter'] = Variable<String>(activeFilter);
    map['ocr_text'] = Variable<String>(ocrText);
    return map;
  }

  PagesCompanion toCompanion(bool nullToAbsent) {
    return PagesCompanion(
      id: Value(id),
      documentId: Value(documentId),
      pageIndex: Value(pageIndex),
      imagePath: Value(imagePath),
      activeFilter: Value(activeFilter),
      ocrText: Value(ocrText),
    );
  }

  factory Page.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Page(
      id: serializer.fromJson<int>(json['id']),
      documentId: serializer.fromJson<int>(json['documentId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      activeFilter: serializer.fromJson<String>(json['activeFilter']),
      ocrText: serializer.fromJson<String>(json['ocrText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'documentId': serializer.toJson<int>(documentId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'imagePath': serializer.toJson<String>(imagePath),
      'activeFilter': serializer.toJson<String>(activeFilter),
      'ocrText': serializer.toJson<String>(ocrText),
    };
  }

  Page copyWith({
    int? id,
    int? documentId,
    int? pageIndex,
    String? imagePath,
    String? activeFilter,
    String? ocrText,
  }) => Page(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    pageIndex: pageIndex ?? this.pageIndex,
    imagePath: imagePath ?? this.imagePath,
    activeFilter: activeFilter ?? this.activeFilter,
    ocrText: ocrText ?? this.ocrText,
  );
  Page copyWithCompanion(PagesCompanion data) {
    return Page(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      activeFilter: data.activeFilter.present
          ? data.activeFilter.value
          : this.activeFilter,
      ocrText: data.ocrText.present ? data.ocrText.value : this.ocrText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Page(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('imagePath: $imagePath, ')
          ..write('activeFilter: $activeFilter, ')
          ..write('ocrText: $ocrText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, documentId, pageIndex, imagePath, activeFilter, ocrText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Page &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.pageIndex == this.pageIndex &&
          other.imagePath == this.imagePath &&
          other.activeFilter == this.activeFilter &&
          other.ocrText == this.ocrText);
}

class PagesCompanion extends UpdateCompanion<Page> {
  final Value<int> id;
  final Value<int> documentId;
  final Value<int> pageIndex;
  final Value<String> imagePath;
  final Value<String> activeFilter;
  final Value<String> ocrText;
  const PagesCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.activeFilter = const Value.absent(),
    this.ocrText = const Value.absent(),
  });
  PagesCompanion.insert({
    this.id = const Value.absent(),
    required int documentId,
    required int pageIndex,
    required String imagePath,
    this.activeFilter = const Value.absent(),
    this.ocrText = const Value.absent(),
  }) : documentId = Value(documentId),
       pageIndex = Value(pageIndex),
       imagePath = Value(imagePath);
  static Insertable<Page> custom({
    Expression<int>? id,
    Expression<int>? documentId,
    Expression<int>? pageIndex,
    Expression<String>? imagePath,
    Expression<String>? activeFilter,
    Expression<String>? ocrText,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (imagePath != null) 'image_path': imagePath,
      if (activeFilter != null) 'active_filter': activeFilter,
      if (ocrText != null) 'ocr_text': ocrText,
    });
  }

  PagesCompanion copyWith({
    Value<int>? id,
    Value<int>? documentId,
    Value<int>? pageIndex,
    Value<String>? imagePath,
    Value<String>? activeFilter,
    Value<String>? ocrText,
  }) {
    return PagesCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageIndex: pageIndex ?? this.pageIndex,
      imagePath: imagePath ?? this.imagePath,
      activeFilter: activeFilter ?? this.activeFilter,
      ocrText: ocrText ?? this.ocrText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<int>(documentId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (activeFilter.present) {
      map['active_filter'] = Variable<String>(activeFilter.value);
    }
    if (ocrText.present) {
      map['ocr_text'] = Variable<String>(ocrText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PagesCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('imagePath: $imagePath, ')
          ..write('activeFilter: $activeFilter, ')
          ..write('ocrText: $ocrText')
          ..write(')'))
        .toString();
  }
}

class $FieldsTable extends Fields with TableInfo<$FieldsTable, Field> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FieldsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<int> documentId = GeneratedColumn<int>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id)',
    ),
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boundingBoxJsonMeta = const VerificationMeta(
    'boundingBoxJson',
  );
  @override
  late final GeneratedColumn<String> boundingBoxJson = GeneratedColumn<String>(
    'bounding_box_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isCheckedMeta = const VerificationMeta(
    'isChecked',
  );
  @override
  late final GeneratedColumn<bool> isChecked = GeneratedColumn<bool>(
    'is_checked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_checked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFilledMeta = const VerificationMeta(
    'isFilled',
  );
  @override
  late final GeneratedColumn<bool> isFilled = GeneratedColumn<bool>(
    'is_filled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_filled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _signatureIdMeta = const VerificationMeta(
    'signatureId',
  );
  @override
  late final GeneratedColumn<int> signatureId = GeneratedColumn<int>(
    'signature_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pdfFieldNameMeta = const VerificationMeta(
    'pdfFieldName',
  );
  @override
  late final GeneratedColumn<String> pdfFieldName = GeneratedColumn<String>(
    'pdf_field_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isRequiredMeta = const VerificationMeta(
    'isRequired',
  );
  @override
  late final GeneratedColumn<bool> isRequired = GeneratedColumn<bool>(
    'is_required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_required" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceKindMeta = const VerificationMeta(
    'sourceKind',
  );
  @override
  late final GeneratedColumn<String> sourceKind = GeneratedColumn<String>(
    'source_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('app'),
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    pageIndex,
    type,
    boundingBoxJson,
    label,
    value,
    isChecked,
    isFilled,
    signatureId,
    pdfFieldName,
    isRequired,
    sourceKind,
    optionsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fields';
  @override
  VerificationContext validateIntegrity(
    Insertable<Field> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('bounding_box_json')) {
      context.handle(
        _boundingBoxJsonMeta,
        boundingBoxJson.isAcceptableOrUnknown(
          data['bounding_box_json']!,
          _boundingBoxJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_boundingBoxJsonMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('is_checked')) {
      context.handle(
        _isCheckedMeta,
        isChecked.isAcceptableOrUnknown(data['is_checked']!, _isCheckedMeta),
      );
    }
    if (data.containsKey('is_filled')) {
      context.handle(
        _isFilledMeta,
        isFilled.isAcceptableOrUnknown(data['is_filled']!, _isFilledMeta),
      );
    }
    if (data.containsKey('signature_id')) {
      context.handle(
        _signatureIdMeta,
        signatureId.isAcceptableOrUnknown(
          data['signature_id']!,
          _signatureIdMeta,
        ),
      );
    }
    if (data.containsKey('pdf_field_name')) {
      context.handle(
        _pdfFieldNameMeta,
        pdfFieldName.isAcceptableOrUnknown(
          data['pdf_field_name']!,
          _pdfFieldNameMeta,
        ),
      );
    }
    if (data.containsKey('is_required')) {
      context.handle(
        _isRequiredMeta,
        isRequired.isAcceptableOrUnknown(data['is_required']!, _isRequiredMeta),
      );
    }
    if (data.containsKey('source_kind')) {
      context.handle(
        _sourceKindMeta,
        sourceKind.isAcceptableOrUnknown(data['source_kind']!, _sourceKindMeta),
      );
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Field map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Field(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}document_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      boundingBoxJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bounding_box_json'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      isChecked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_checked'],
      )!,
      isFilled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_filled'],
      )!,
      signatureId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}signature_id'],
      ),
      pdfFieldName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_field_name'],
      ),
      isRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_required'],
      )!,
      sourceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_kind'],
      )!,
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      ),
    );
  }

  @override
  $FieldsTable createAlias(String alias) {
    return $FieldsTable(attachedDatabase, alias);
  }
}

class Field extends DataClass implements Insertable<Field> {
  final int id;
  final int documentId;
  final int pageIndex;
  final String type;
  final String boundingBoxJson;
  final String label;
  final String value;
  final bool isChecked;
  final bool isFilled;
  final int? signatureId;
  final String? pdfFieldName;
  final bool isRequired;
  final String sourceKind;
  final String? optionsJson;
  const Field({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.type,
    required this.boundingBoxJson,
    required this.label,
    required this.value,
    required this.isChecked,
    required this.isFilled,
    this.signatureId,
    this.pdfFieldName,
    required this.isRequired,
    required this.sourceKind,
    this.optionsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['document_id'] = Variable<int>(documentId);
    map['page_index'] = Variable<int>(pageIndex);
    map['type'] = Variable<String>(type);
    map['bounding_box_json'] = Variable<String>(boundingBoxJson);
    map['label'] = Variable<String>(label);
    map['value'] = Variable<String>(value);
    map['is_checked'] = Variable<bool>(isChecked);
    map['is_filled'] = Variable<bool>(isFilled);
    if (!nullToAbsent || signatureId != null) {
      map['signature_id'] = Variable<int>(signatureId);
    }
    if (!nullToAbsent || pdfFieldName != null) {
      map['pdf_field_name'] = Variable<String>(pdfFieldName);
    }
    map['is_required'] = Variable<bool>(isRequired);
    map['source_kind'] = Variable<String>(sourceKind);
    if (!nullToAbsent || optionsJson != null) {
      map['options_json'] = Variable<String>(optionsJson);
    }
    return map;
  }

  FieldsCompanion toCompanion(bool nullToAbsent) {
    return FieldsCompanion(
      id: Value(id),
      documentId: Value(documentId),
      pageIndex: Value(pageIndex),
      type: Value(type),
      boundingBoxJson: Value(boundingBoxJson),
      label: Value(label),
      value: Value(value),
      isChecked: Value(isChecked),
      isFilled: Value(isFilled),
      signatureId: signatureId == null && nullToAbsent
          ? const Value.absent()
          : Value(signatureId),
      pdfFieldName: pdfFieldName == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfFieldName),
      isRequired: Value(isRequired),
      sourceKind: Value(sourceKind),
      optionsJson: optionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(optionsJson),
    );
  }

  factory Field.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Field(
      id: serializer.fromJson<int>(json['id']),
      documentId: serializer.fromJson<int>(json['documentId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      type: serializer.fromJson<String>(json['type']),
      boundingBoxJson: serializer.fromJson<String>(json['boundingBoxJson']),
      label: serializer.fromJson<String>(json['label']),
      value: serializer.fromJson<String>(json['value']),
      isChecked: serializer.fromJson<bool>(json['isChecked']),
      isFilled: serializer.fromJson<bool>(json['isFilled']),
      signatureId: serializer.fromJson<int?>(json['signatureId']),
      pdfFieldName: serializer.fromJson<String?>(json['pdfFieldName']),
      isRequired: serializer.fromJson<bool>(json['isRequired']),
      sourceKind: serializer.fromJson<String>(json['sourceKind']),
      optionsJson: serializer.fromJson<String?>(json['optionsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'documentId': serializer.toJson<int>(documentId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'type': serializer.toJson<String>(type),
      'boundingBoxJson': serializer.toJson<String>(boundingBoxJson),
      'label': serializer.toJson<String>(label),
      'value': serializer.toJson<String>(value),
      'isChecked': serializer.toJson<bool>(isChecked),
      'isFilled': serializer.toJson<bool>(isFilled),
      'signatureId': serializer.toJson<int?>(signatureId),
      'pdfFieldName': serializer.toJson<String?>(pdfFieldName),
      'isRequired': serializer.toJson<bool>(isRequired),
      'sourceKind': serializer.toJson<String>(sourceKind),
      'optionsJson': serializer.toJson<String?>(optionsJson),
    };
  }

  Field copyWith({
    int? id,
    int? documentId,
    int? pageIndex,
    String? type,
    String? boundingBoxJson,
    String? label,
    String? value,
    bool? isChecked,
    bool? isFilled,
    Value<int?> signatureId = const Value.absent(),
    Value<String?> pdfFieldName = const Value.absent(),
    bool? isRequired,
    String? sourceKind,
    Value<String?> optionsJson = const Value.absent(),
  }) => Field(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    pageIndex: pageIndex ?? this.pageIndex,
    type: type ?? this.type,
    boundingBoxJson: boundingBoxJson ?? this.boundingBoxJson,
    label: label ?? this.label,
    value: value ?? this.value,
    isChecked: isChecked ?? this.isChecked,
    isFilled: isFilled ?? this.isFilled,
    signatureId: signatureId.present ? signatureId.value : this.signatureId,
    pdfFieldName: pdfFieldName.present ? pdfFieldName.value : this.pdfFieldName,
    isRequired: isRequired ?? this.isRequired,
    sourceKind: sourceKind ?? this.sourceKind,
    optionsJson: optionsJson.present ? optionsJson.value : this.optionsJson,
  );
  Field copyWithCompanion(FieldsCompanion data) {
    return Field(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      type: data.type.present ? data.type.value : this.type,
      boundingBoxJson: data.boundingBoxJson.present
          ? data.boundingBoxJson.value
          : this.boundingBoxJson,
      label: data.label.present ? data.label.value : this.label,
      value: data.value.present ? data.value.value : this.value,
      isChecked: data.isChecked.present ? data.isChecked.value : this.isChecked,
      isFilled: data.isFilled.present ? data.isFilled.value : this.isFilled,
      signatureId: data.signatureId.present
          ? data.signatureId.value
          : this.signatureId,
      pdfFieldName: data.pdfFieldName.present
          ? data.pdfFieldName.value
          : this.pdfFieldName,
      isRequired: data.isRequired.present
          ? data.isRequired.value
          : this.isRequired,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Field(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('type: $type, ')
          ..write('boundingBoxJson: $boundingBoxJson, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('isChecked: $isChecked, ')
          ..write('isFilled: $isFilled, ')
          ..write('signatureId: $signatureId, ')
          ..write('pdfFieldName: $pdfFieldName, ')
          ..write('isRequired: $isRequired, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('optionsJson: $optionsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    pageIndex,
    type,
    boundingBoxJson,
    label,
    value,
    isChecked,
    isFilled,
    signatureId,
    pdfFieldName,
    isRequired,
    sourceKind,
    optionsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Field &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.pageIndex == this.pageIndex &&
          other.type == this.type &&
          other.boundingBoxJson == this.boundingBoxJson &&
          other.label == this.label &&
          other.value == this.value &&
          other.isChecked == this.isChecked &&
          other.isFilled == this.isFilled &&
          other.signatureId == this.signatureId &&
          other.pdfFieldName == this.pdfFieldName &&
          other.isRequired == this.isRequired &&
          other.sourceKind == this.sourceKind &&
          other.optionsJson == this.optionsJson);
}

class FieldsCompanion extends UpdateCompanion<Field> {
  final Value<int> id;
  final Value<int> documentId;
  final Value<int> pageIndex;
  final Value<String> type;
  final Value<String> boundingBoxJson;
  final Value<String> label;
  final Value<String> value;
  final Value<bool> isChecked;
  final Value<bool> isFilled;
  final Value<int?> signatureId;
  final Value<String?> pdfFieldName;
  final Value<bool> isRequired;
  final Value<String> sourceKind;
  final Value<String?> optionsJson;
  const FieldsCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.type = const Value.absent(),
    this.boundingBoxJson = const Value.absent(),
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.isChecked = const Value.absent(),
    this.isFilled = const Value.absent(),
    this.signatureId = const Value.absent(),
    this.pdfFieldName = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.optionsJson = const Value.absent(),
  });
  FieldsCompanion.insert({
    this.id = const Value.absent(),
    required int documentId,
    required int pageIndex,
    required String type,
    required String boundingBoxJson,
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.isChecked = const Value.absent(),
    this.isFilled = const Value.absent(),
    this.signatureId = const Value.absent(),
    this.pdfFieldName = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.optionsJson = const Value.absent(),
  }) : documentId = Value(documentId),
       pageIndex = Value(pageIndex),
       type = Value(type),
       boundingBoxJson = Value(boundingBoxJson);
  static Insertable<Field> custom({
    Expression<int>? id,
    Expression<int>? documentId,
    Expression<int>? pageIndex,
    Expression<String>? type,
    Expression<String>? boundingBoxJson,
    Expression<String>? label,
    Expression<String>? value,
    Expression<bool>? isChecked,
    Expression<bool>? isFilled,
    Expression<int>? signatureId,
    Expression<String>? pdfFieldName,
    Expression<bool>? isRequired,
    Expression<String>? sourceKind,
    Expression<String>? optionsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (type != null) 'type': type,
      if (boundingBoxJson != null) 'bounding_box_json': boundingBoxJson,
      if (label != null) 'label': label,
      if (value != null) 'value': value,
      if (isChecked != null) 'is_checked': isChecked,
      if (isFilled != null) 'is_filled': isFilled,
      if (signatureId != null) 'signature_id': signatureId,
      if (pdfFieldName != null) 'pdf_field_name': pdfFieldName,
      if (isRequired != null) 'is_required': isRequired,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (optionsJson != null) 'options_json': optionsJson,
    });
  }

  FieldsCompanion copyWith({
    Value<int>? id,
    Value<int>? documentId,
    Value<int>? pageIndex,
    Value<String>? type,
    Value<String>? boundingBoxJson,
    Value<String>? label,
    Value<String>? value,
    Value<bool>? isChecked,
    Value<bool>? isFilled,
    Value<int?>? signatureId,
    Value<String?>? pdfFieldName,
    Value<bool>? isRequired,
    Value<String>? sourceKind,
    Value<String?>? optionsJson,
  }) {
    return FieldsCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageIndex: pageIndex ?? this.pageIndex,
      type: type ?? this.type,
      boundingBoxJson: boundingBoxJson ?? this.boundingBoxJson,
      label: label ?? this.label,
      value: value ?? this.value,
      isChecked: isChecked ?? this.isChecked,
      isFilled: isFilled ?? this.isFilled,
      signatureId: signatureId ?? this.signatureId,
      pdfFieldName: pdfFieldName ?? this.pdfFieldName,
      isRequired: isRequired ?? this.isRequired,
      sourceKind: sourceKind ?? this.sourceKind,
      optionsJson: optionsJson ?? this.optionsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<int>(documentId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (boundingBoxJson.present) {
      map['bounding_box_json'] = Variable<String>(boundingBoxJson.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (isChecked.present) {
      map['is_checked'] = Variable<bool>(isChecked.value);
    }
    if (isFilled.present) {
      map['is_filled'] = Variable<bool>(isFilled.value);
    }
    if (signatureId.present) {
      map['signature_id'] = Variable<int>(signatureId.value);
    }
    if (pdfFieldName.present) {
      map['pdf_field_name'] = Variable<String>(pdfFieldName.value);
    }
    if (isRequired.present) {
      map['is_required'] = Variable<bool>(isRequired.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(sourceKind.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FieldsCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('type: $type, ')
          ..write('boundingBoxJson: $boundingBoxJson, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('isChecked: $isChecked, ')
          ..write('isFilled: $isFilled, ')
          ..write('signatureId: $signatureId, ')
          ..write('pdfFieldName: $pdfFieldName, ')
          ..write('isRequired: $isRequired, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('optionsJson: $optionsJson')
          ..write(')'))
        .toString();
  }
}

class $SignaturesTable extends Signatures
    with TableInfo<$SignaturesTable, Signature> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignaturesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('My Signature'),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isInitialsMeta = const VerificationMeta(
    'isInitials',
  );
  @override
  late final GeneratedColumn<bool> isInitials = GeneratedColumn<bool>(
    'is_initials',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_initials" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    imagePath,
    isDefault,
    isInitials,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signatures';
  @override
  VerificationContext validateIntegrity(
    Insertable<Signature> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('is_initials')) {
      context.handle(
        _isInitialsMeta,
        isInitials.isAcceptableOrUnknown(data['is_initials']!, _isInitialsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Signature map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Signature(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      isInitials: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_initials'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SignaturesTable createAlias(String alias) {
    return $SignaturesTable(attachedDatabase, alias);
  }
}

class Signature extends DataClass implements Insertable<Signature> {
  final int id;
  final String label;
  final String imagePath;
  final bool isDefault;
  final bool isInitials;
  final DateTime createdAt;
  const Signature({
    required this.id,
    required this.label,
    required this.imagePath,
    required this.isDefault,
    required this.isInitials,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    map['image_path'] = Variable<String>(imagePath);
    map['is_default'] = Variable<bool>(isDefault);
    map['is_initials'] = Variable<bool>(isInitials);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SignaturesCompanion toCompanion(bool nullToAbsent) {
    return SignaturesCompanion(
      id: Value(id),
      label: Value(label),
      imagePath: Value(imagePath),
      isDefault: Value(isDefault),
      isInitials: Value(isInitials),
      createdAt: Value(createdAt),
    );
  }

  factory Signature.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Signature(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      isInitials: serializer.fromJson<bool>(json['isInitials']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
      'imagePath': serializer.toJson<String>(imagePath),
      'isDefault': serializer.toJson<bool>(isDefault),
      'isInitials': serializer.toJson<bool>(isInitials),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Signature copyWith({
    int? id,
    String? label,
    String? imagePath,
    bool? isDefault,
    bool? isInitials,
    DateTime? createdAt,
  }) => Signature(
    id: id ?? this.id,
    label: label ?? this.label,
    imagePath: imagePath ?? this.imagePath,
    isDefault: isDefault ?? this.isDefault,
    isInitials: isInitials ?? this.isInitials,
    createdAt: createdAt ?? this.createdAt,
  );
  Signature copyWithCompanion(SignaturesCompanion data) {
    return Signature(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      isInitials: data.isInitials.present
          ? data.isInitials.value
          : this.isInitials,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Signature(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('imagePath: $imagePath, ')
          ..write('isDefault: $isDefault, ')
          ..write('isInitials: $isInitials, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, label, imagePath, isDefault, isInitials, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Signature &&
          other.id == this.id &&
          other.label == this.label &&
          other.imagePath == this.imagePath &&
          other.isDefault == this.isDefault &&
          other.isInitials == this.isInitials &&
          other.createdAt == this.createdAt);
}

class SignaturesCompanion extends UpdateCompanion<Signature> {
  final Value<int> id;
  final Value<String> label;
  final Value<String> imagePath;
  final Value<bool> isDefault;
  final Value<bool> isInitials;
  final Value<DateTime> createdAt;
  const SignaturesCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isInitials = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SignaturesCompanion.insert({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    required String imagePath,
    this.isDefault = const Value.absent(),
    this.isInitials = const Value.absent(),
    required DateTime createdAt,
  }) : imagePath = Value(imagePath),
       createdAt = Value(createdAt);
  static Insertable<Signature> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? imagePath,
    Expression<bool>? isDefault,
    Expression<bool>? isInitials,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (imagePath != null) 'image_path': imagePath,
      if (isDefault != null) 'is_default': isDefault,
      if (isInitials != null) 'is_initials': isInitials,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SignaturesCompanion copyWith({
    Value<int>? id,
    Value<String>? label,
    Value<String>? imagePath,
    Value<bool>? isDefault,
    Value<bool>? isInitials,
    Value<DateTime>? createdAt,
  }) {
    return SignaturesCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      imagePath: imagePath ?? this.imagePath,
      isDefault: isDefault ?? this.isDefault,
      isInitials: isInitials ?? this.isInitials,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (isInitials.present) {
      map['is_initials'] = Variable<bool>(isInitials.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignaturesCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('imagePath: $imagePath, ')
          ..write('isDefault: $isDefault, ')
          ..write('isInitials: $isInitials, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserProfileTable extends UserProfile
    with TableInfo<$UserProfileTable, UserProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _zipMeta = const VerificationMeta('zip');
  @override
  late final GeneratedColumn<String> zip = GeneratedColumn<String>(
    'zip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _companyMeta = const VerificationMeta(
    'company',
  );
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _biometricLockEnabledMeta =
      const VerificationMeta('biometricLockEnabled');
  @override
  late final GeneratedColumn<bool> biometricLockEnabled = GeneratedColumn<bool>(
    'biometric_lock_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("biometric_lock_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _aiEnhancedDetectionMeta =
      const VerificationMeta('aiEnhancedDetection');
  @override
  late final GeneratedColumn<bool> aiEnhancedDetection = GeneratedColumn<bool>(
    'ai_enhanced_detection',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ai_enhanced_detection" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _scanCountMeta = const VerificationMeta(
    'scanCount',
  );
  @override
  late final GeneratedColumn<int> scanCount = GeneratedColumn<int>(
    'scan_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPurchasedMeta = const VerificationMeta(
    'isPurchased',
  );
  @override
  late final GeneratedColumn<bool> isPurchased = GeneratedColumn<bool>(
    'is_purchased',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_purchased" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _includeInDeviceBackupMeta =
      const VerificationMeta('includeInDeviceBackup');
  @override
  late final GeneratedColumn<bool> includeInDeviceBackup =
      GeneratedColumn<bool>(
        'include_in_device_backup',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("include_in_device_backup" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fullName,
    email,
    phone,
    address,
    city,
    state,
    zip,
    company,
    biometricLockEnabled,
    aiEnhancedDetection,
    scanCount,
    isPurchased,
    includeInDeviceBackup,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('zip')) {
      context.handle(
        _zipMeta,
        zip.isAcceptableOrUnknown(data['zip']!, _zipMeta),
      );
    }
    if (data.containsKey('company')) {
      context.handle(
        _companyMeta,
        company.isAcceptableOrUnknown(data['company']!, _companyMeta),
      );
    }
    if (data.containsKey('biometric_lock_enabled')) {
      context.handle(
        _biometricLockEnabledMeta,
        biometricLockEnabled.isAcceptableOrUnknown(
          data['biometric_lock_enabled']!,
          _biometricLockEnabledMeta,
        ),
      );
    }
    if (data.containsKey('ai_enhanced_detection')) {
      context.handle(
        _aiEnhancedDetectionMeta,
        aiEnhancedDetection.isAcceptableOrUnknown(
          data['ai_enhanced_detection']!,
          _aiEnhancedDetectionMeta,
        ),
      );
    }
    if (data.containsKey('scan_count')) {
      context.handle(
        _scanCountMeta,
        scanCount.isAcceptableOrUnknown(data['scan_count']!, _scanCountMeta),
      );
    }
    if (data.containsKey('is_purchased')) {
      context.handle(
        _isPurchasedMeta,
        isPurchased.isAcceptableOrUnknown(
          data['is_purchased']!,
          _isPurchasedMeta,
        ),
      );
    }
    if (data.containsKey('include_in_device_backup')) {
      context.handle(
        _includeInDeviceBackupMeta,
        includeInDeviceBackup.isAcceptableOrUnknown(
          data['include_in_device_backup']!,
          _includeInDeviceBackupMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      zip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zip'],
      )!,
      company: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company'],
      )!,
      biometricLockEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}biometric_lock_enabled'],
      )!,
      aiEnhancedDetection: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ai_enhanced_detection'],
      )!,
      scanCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scan_count'],
      )!,
      isPurchased: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_purchased'],
      )!,
      includeInDeviceBackup: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_in_device_backup'],
      )!,
    );
  }

  @override
  $UserProfileTable createAlias(String alias) {
    return $UserProfileTable(attachedDatabase, alias);
  }
}

class UserProfileData extends DataClass implements Insertable<UserProfileData> {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String company;
  final bool biometricLockEnabled;
  final bool aiEnhancedDetection;
  final int scanCount;
  final bool isPurchased;
  final bool includeInDeviceBackup;
  const UserProfileData({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    required this.company,
    required this.biometricLockEnabled,
    required this.aiEnhancedDetection,
    required this.scanCount,
    required this.isPurchased,
    required this.includeInDeviceBackup,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['full_name'] = Variable<String>(fullName);
    map['email'] = Variable<String>(email);
    map['phone'] = Variable<String>(phone);
    map['address'] = Variable<String>(address);
    map['city'] = Variable<String>(city);
    map['state'] = Variable<String>(state);
    map['zip'] = Variable<String>(zip);
    map['company'] = Variable<String>(company);
    map['biometric_lock_enabled'] = Variable<bool>(biometricLockEnabled);
    map['ai_enhanced_detection'] = Variable<bool>(aiEnhancedDetection);
    map['scan_count'] = Variable<int>(scanCount);
    map['is_purchased'] = Variable<bool>(isPurchased);
    map['include_in_device_backup'] = Variable<bool>(includeInDeviceBackup);
    return map;
  }

  UserProfileCompanion toCompanion(bool nullToAbsent) {
    return UserProfileCompanion(
      id: Value(id),
      fullName: Value(fullName),
      email: Value(email),
      phone: Value(phone),
      address: Value(address),
      city: Value(city),
      state: Value(state),
      zip: Value(zip),
      company: Value(company),
      biometricLockEnabled: Value(biometricLockEnabled),
      aiEnhancedDetection: Value(aiEnhancedDetection),
      scanCount: Value(scanCount),
      isPurchased: Value(isPurchased),
      includeInDeviceBackup: Value(includeInDeviceBackup),
    );
  }

  factory UserProfileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileData(
      id: serializer.fromJson<int>(json['id']),
      fullName: serializer.fromJson<String>(json['fullName']),
      email: serializer.fromJson<String>(json['email']),
      phone: serializer.fromJson<String>(json['phone']),
      address: serializer.fromJson<String>(json['address']),
      city: serializer.fromJson<String>(json['city']),
      state: serializer.fromJson<String>(json['state']),
      zip: serializer.fromJson<String>(json['zip']),
      company: serializer.fromJson<String>(json['company']),
      biometricLockEnabled: serializer.fromJson<bool>(
        json['biometricLockEnabled'],
      ),
      aiEnhancedDetection: serializer.fromJson<bool>(
        json['aiEnhancedDetection'],
      ),
      scanCount: serializer.fromJson<int>(json['scanCount']),
      isPurchased: serializer.fromJson<bool>(json['isPurchased']),
      includeInDeviceBackup: serializer.fromJson<bool>(
        json['includeInDeviceBackup'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fullName': serializer.toJson<String>(fullName),
      'email': serializer.toJson<String>(email),
      'phone': serializer.toJson<String>(phone),
      'address': serializer.toJson<String>(address),
      'city': serializer.toJson<String>(city),
      'state': serializer.toJson<String>(state),
      'zip': serializer.toJson<String>(zip),
      'company': serializer.toJson<String>(company),
      'biometricLockEnabled': serializer.toJson<bool>(biometricLockEnabled),
      'aiEnhancedDetection': serializer.toJson<bool>(aiEnhancedDetection),
      'scanCount': serializer.toJson<int>(scanCount),
      'isPurchased': serializer.toJson<bool>(isPurchased),
      'includeInDeviceBackup': serializer.toJson<bool>(includeInDeviceBackup),
    };
  }

  UserProfileData copyWith({
    int? id,
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? zip,
    String? company,
    bool? biometricLockEnabled,
    bool? aiEnhancedDetection,
    int? scanCount,
    bool? isPurchased,
    bool? includeInDeviceBackup,
  }) => UserProfileData(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    city: city ?? this.city,
    state: state ?? this.state,
    zip: zip ?? this.zip,
    company: company ?? this.company,
    biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
    aiEnhancedDetection: aiEnhancedDetection ?? this.aiEnhancedDetection,
    scanCount: scanCount ?? this.scanCount,
    isPurchased: isPurchased ?? this.isPurchased,
    includeInDeviceBackup: includeInDeviceBackup ?? this.includeInDeviceBackup,
  );
  UserProfileData copyWithCompanion(UserProfileCompanion data) {
    return UserProfileData(
      id: data.id.present ? data.id.value : this.id,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      city: data.city.present ? data.city.value : this.city,
      state: data.state.present ? data.state.value : this.state,
      zip: data.zip.present ? data.zip.value : this.zip,
      company: data.company.present ? data.company.value : this.company,
      biometricLockEnabled: data.biometricLockEnabled.present
          ? data.biometricLockEnabled.value
          : this.biometricLockEnabled,
      aiEnhancedDetection: data.aiEnhancedDetection.present
          ? data.aiEnhancedDetection.value
          : this.aiEnhancedDetection,
      scanCount: data.scanCount.present ? data.scanCount.value : this.scanCount,
      isPurchased: data.isPurchased.present
          ? data.isPurchased.value
          : this.isPurchased,
      includeInDeviceBackup: data.includeInDeviceBackup.present
          ? data.includeInDeviceBackup.value
          : this.includeInDeviceBackup,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileData(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('state: $state, ')
          ..write('zip: $zip, ')
          ..write('company: $company, ')
          ..write('biometricLockEnabled: $biometricLockEnabled, ')
          ..write('aiEnhancedDetection: $aiEnhancedDetection, ')
          ..write('scanCount: $scanCount, ')
          ..write('isPurchased: $isPurchased, ')
          ..write('includeInDeviceBackup: $includeInDeviceBackup')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fullName,
    email,
    phone,
    address,
    city,
    state,
    zip,
    company,
    biometricLockEnabled,
    aiEnhancedDetection,
    scanCount,
    isPurchased,
    includeInDeviceBackup,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileData &&
          other.id == this.id &&
          other.fullName == this.fullName &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.city == this.city &&
          other.state == this.state &&
          other.zip == this.zip &&
          other.company == this.company &&
          other.biometricLockEnabled == this.biometricLockEnabled &&
          other.aiEnhancedDetection == this.aiEnhancedDetection &&
          other.scanCount == this.scanCount &&
          other.isPurchased == this.isPurchased &&
          other.includeInDeviceBackup == this.includeInDeviceBackup);
}

class UserProfileCompanion extends UpdateCompanion<UserProfileData> {
  final Value<int> id;
  final Value<String> fullName;
  final Value<String> email;
  final Value<String> phone;
  final Value<String> address;
  final Value<String> city;
  final Value<String> state;
  final Value<String> zip;
  final Value<String> company;
  final Value<bool> biometricLockEnabled;
  final Value<bool> aiEnhancedDetection;
  final Value<int> scanCount;
  final Value<bool> isPurchased;
  final Value<bool> includeInDeviceBackup;
  const UserProfileCompanion({
    this.id = const Value.absent(),
    this.fullName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.state = const Value.absent(),
    this.zip = const Value.absent(),
    this.company = const Value.absent(),
    this.biometricLockEnabled = const Value.absent(),
    this.aiEnhancedDetection = const Value.absent(),
    this.scanCount = const Value.absent(),
    this.isPurchased = const Value.absent(),
    this.includeInDeviceBackup = const Value.absent(),
  });
  UserProfileCompanion.insert({
    this.id = const Value.absent(),
    this.fullName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.state = const Value.absent(),
    this.zip = const Value.absent(),
    this.company = const Value.absent(),
    this.biometricLockEnabled = const Value.absent(),
    this.aiEnhancedDetection = const Value.absent(),
    this.scanCount = const Value.absent(),
    this.isPurchased = const Value.absent(),
    this.includeInDeviceBackup = const Value.absent(),
  });
  static Insertable<UserProfileData> custom({
    Expression<int>? id,
    Expression<String>? fullName,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<String>? city,
    Expression<String>? state,
    Expression<String>? zip,
    Expression<String>? company,
    Expression<bool>? biometricLockEnabled,
    Expression<bool>? aiEnhancedDetection,
    Expression<int>? scanCount,
    Expression<bool>? isPurchased,
    Expression<bool>? includeInDeviceBackup,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fullName != null) 'full_name': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (zip != null) 'zip': zip,
      if (company != null) 'company': company,
      if (biometricLockEnabled != null)
        'biometric_lock_enabled': biometricLockEnabled,
      if (aiEnhancedDetection != null)
        'ai_enhanced_detection': aiEnhancedDetection,
      if (scanCount != null) 'scan_count': scanCount,
      if (isPurchased != null) 'is_purchased': isPurchased,
      if (includeInDeviceBackup != null)
        'include_in_device_backup': includeInDeviceBackup,
    });
  }

  UserProfileCompanion copyWith({
    Value<int>? id,
    Value<String>? fullName,
    Value<String>? email,
    Value<String>? phone,
    Value<String>? address,
    Value<String>? city,
    Value<String>? state,
    Value<String>? zip,
    Value<String>? company,
    Value<bool>? biometricLockEnabled,
    Value<bool>? aiEnhancedDetection,
    Value<int>? scanCount,
    Value<bool>? isPurchased,
    Value<bool>? includeInDeviceBackup,
  }) {
    return UserProfileCompanion(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      company: company ?? this.company,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      aiEnhancedDetection: aiEnhancedDetection ?? this.aiEnhancedDetection,
      scanCount: scanCount ?? this.scanCount,
      isPurchased: isPurchased ?? this.isPurchased,
      includeInDeviceBackup:
          includeInDeviceBackup ?? this.includeInDeviceBackup,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (zip.present) {
      map['zip'] = Variable<String>(zip.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (biometricLockEnabled.present) {
      map['biometric_lock_enabled'] = Variable<bool>(
        biometricLockEnabled.value,
      );
    }
    if (aiEnhancedDetection.present) {
      map['ai_enhanced_detection'] = Variable<bool>(aiEnhancedDetection.value);
    }
    if (scanCount.present) {
      map['scan_count'] = Variable<int>(scanCount.value);
    }
    if (isPurchased.present) {
      map['is_purchased'] = Variable<bool>(isPurchased.value);
    }
    if (includeInDeviceBackup.present) {
      map['include_in_device_backup'] = Variable<bool>(
        includeInDeviceBackup.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileCompanion(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('state: $state, ')
          ..write('zip: $zip, ')
          ..write('company: $company, ')
          ..write('biometricLockEnabled: $biometricLockEnabled, ')
          ..write('aiEnhancedDetection: $aiEnhancedDetection, ')
          ..write('scanCount: $scanCount, ')
          ..write('isPurchased: $isPurchased, ')
          ..write('includeInDeviceBackup: $includeInDeviceBackup')
          ..write(')'))
        .toString();
  }
}

class $FieldHintsTable extends FieldHints
    with TableInfo<$FieldHintsTable, FieldHint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FieldHintsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _phraseMeta = const VerificationMeta('phrase');
  @override
  late final GeneratedColumn<String> phrase = GeneratedColumn<String>(
    'phrase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acceptedMeta = const VerificationMeta(
    'accepted',
  );
  @override
  late final GeneratedColumn<int> accepted = GeneratedColumn<int>(
    'accepted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rejectedMeta = const VerificationMeta(
    'rejected',
  );
  @override
  late final GeneratedColumn<int> rejected = GeneratedColumn<int>(
    'rejected',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  List<GeneratedColumn> get $columns => [
    id,
    phrase,
    type,
    accepted,
    rejected,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'field_hints';
  @override
  VerificationContext validateIntegrity(
    Insertable<FieldHint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('phrase')) {
      context.handle(
        _phraseMeta,
        phrase.isAcceptableOrUnknown(data['phrase']!, _phraseMeta),
      );
    } else if (isInserting) {
      context.missing(_phraseMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('accepted')) {
      context.handle(
        _acceptedMeta,
        accepted.isAcceptableOrUnknown(data['accepted']!, _acceptedMeta),
      );
    }
    if (data.containsKey('rejected')) {
      context.handle(
        _rejectedMeta,
        rejected.isAcceptableOrUnknown(data['rejected']!, _rejectedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {phrase, type},
  ];
  @override
  FieldHint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FieldHint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      phrase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      accepted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accepted'],
      )!,
      rejected: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rejected'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FieldHintsTable createAlias(String alias) {
    return $FieldHintsTable(attachedDatabase, alias);
  }
}

class FieldHint extends DataClass implements Insertable<FieldHint> {
  final int id;
  final String phrase;
  final String type;
  final int accepted;
  final int rejected;
  final DateTime updatedAt;
  const FieldHint({
    required this.id,
    required this.phrase,
    required this.type,
    required this.accepted,
    required this.rejected,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['phrase'] = Variable<String>(phrase);
    map['type'] = Variable<String>(type);
    map['accepted'] = Variable<int>(accepted);
    map['rejected'] = Variable<int>(rejected);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FieldHintsCompanion toCompanion(bool nullToAbsent) {
    return FieldHintsCompanion(
      id: Value(id),
      phrase: Value(phrase),
      type: Value(type),
      accepted: Value(accepted),
      rejected: Value(rejected),
      updatedAt: Value(updatedAt),
    );
  }

  factory FieldHint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FieldHint(
      id: serializer.fromJson<int>(json['id']),
      phrase: serializer.fromJson<String>(json['phrase']),
      type: serializer.fromJson<String>(json['type']),
      accepted: serializer.fromJson<int>(json['accepted']),
      rejected: serializer.fromJson<int>(json['rejected']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'phrase': serializer.toJson<String>(phrase),
      'type': serializer.toJson<String>(type),
      'accepted': serializer.toJson<int>(accepted),
      'rejected': serializer.toJson<int>(rejected),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FieldHint copyWith({
    int? id,
    String? phrase,
    String? type,
    int? accepted,
    int? rejected,
    DateTime? updatedAt,
  }) => FieldHint(
    id: id ?? this.id,
    phrase: phrase ?? this.phrase,
    type: type ?? this.type,
    accepted: accepted ?? this.accepted,
    rejected: rejected ?? this.rejected,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FieldHint copyWithCompanion(FieldHintsCompanion data) {
    return FieldHint(
      id: data.id.present ? data.id.value : this.id,
      phrase: data.phrase.present ? data.phrase.value : this.phrase,
      type: data.type.present ? data.type.value : this.type,
      accepted: data.accepted.present ? data.accepted.value : this.accepted,
      rejected: data.rejected.present ? data.rejected.value : this.rejected,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FieldHint(')
          ..write('id: $id, ')
          ..write('phrase: $phrase, ')
          ..write('type: $type, ')
          ..write('accepted: $accepted, ')
          ..write('rejected: $rejected, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, phrase, type, accepted, rejected, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FieldHint &&
          other.id == this.id &&
          other.phrase == this.phrase &&
          other.type == this.type &&
          other.accepted == this.accepted &&
          other.rejected == this.rejected &&
          other.updatedAt == this.updatedAt);
}

class FieldHintsCompanion extends UpdateCompanion<FieldHint> {
  final Value<int> id;
  final Value<String> phrase;
  final Value<String> type;
  final Value<int> accepted;
  final Value<int> rejected;
  final Value<DateTime> updatedAt;
  const FieldHintsCompanion({
    this.id = const Value.absent(),
    this.phrase = const Value.absent(),
    this.type = const Value.absent(),
    this.accepted = const Value.absent(),
    this.rejected = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  FieldHintsCompanion.insert({
    this.id = const Value.absent(),
    required String phrase,
    required String type,
    this.accepted = const Value.absent(),
    this.rejected = const Value.absent(),
    required DateTime updatedAt,
  }) : phrase = Value(phrase),
       type = Value(type),
       updatedAt = Value(updatedAt);
  static Insertable<FieldHint> custom({
    Expression<int>? id,
    Expression<String>? phrase,
    Expression<String>? type,
    Expression<int>? accepted,
    Expression<int>? rejected,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (phrase != null) 'phrase': phrase,
      if (type != null) 'type': type,
      if (accepted != null) 'accepted': accepted,
      if (rejected != null) 'rejected': rejected,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  FieldHintsCompanion copyWith({
    Value<int>? id,
    Value<String>? phrase,
    Value<String>? type,
    Value<int>? accepted,
    Value<int>? rejected,
    Value<DateTime>? updatedAt,
  }) {
    return FieldHintsCompanion(
      id: id ?? this.id,
      phrase: phrase ?? this.phrase,
      type: type ?? this.type,
      accepted: accepted ?? this.accepted,
      rejected: rejected ?? this.rejected,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (phrase.present) {
      map['phrase'] = Variable<String>(phrase.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (accepted.present) {
      map['accepted'] = Variable<int>(accepted.value);
    }
    if (rejected.present) {
      map['rejected'] = Variable<int>(rejected.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FieldHintsCompanion(')
          ..write('id: $id, ')
          ..write('phrase: $phrase, ')
          ..write('type: $type, ')
          ..write('accepted: $accepted, ')
          ..write('rejected: $rejected, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $PagesTable pages = $PagesTable(this);
  late final $FieldsTable fields = $FieldsTable(this);
  late final $SignaturesTable signatures = $SignaturesTable(this);
  late final $UserProfileTable userProfile = $UserProfileTable(this);
  late final $FieldHintsTable fieldHints = $FieldHintsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    documents,
    pages,
    fields,
    signatures,
    userProfile,
    fieldHints,
  ];
}

typedef $$DocumentsTableCreateCompanionBuilder =
    DocumentsCompanion Function({
      Value<int> id,
      required String uuid,
      required String title,
      Value<String> status,
      Value<int> pageCount,
      Value<String> ocrText,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> pressedPdfPath,
      Value<String?> fillablePdfPath,
      Value<bool> isTemplate,
      Value<double?> textSize,
    });
typedef $$DocumentsTableUpdateCompanionBuilder =
    DocumentsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> title,
      Value<String> status,
      Value<int> pageCount,
      Value<String> ocrText,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> pressedPdfPath,
      Value<String?> fillablePdfPath,
      Value<bool> isTemplate,
      Value<double?> textSize,
    });

final class $$DocumentsTableReferences
    extends BaseReferences<_$AppDatabase, $DocumentsTable, Document> {
  $$DocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PagesTable, List<Page>> _pagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pages,
    aliasName: $_aliasNameGenerator(db.documents.id, db.pages.documentId),
  );

  $$PagesTableProcessedTableManager get pagesRefs {
    final manager = $$PagesTableTableManager(
      $_db,
      $_db.pages,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FieldsTable, List<Field>> _fieldsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.fields,
    aliasName: $_aliasNameGenerator(db.documents.id, db.fields.documentId),
  );

  $$FieldsTableProcessedTableManager get fieldsRefs {
    final manager = $$FieldsTableTableManager(
      $_db,
      $_db.fields,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_fieldsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
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

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
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

  ColumnFilters<String> get pressedPdfPath => $composableBuilder(
    column: $table.pressedPdfPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fillablePdfPath => $composableBuilder(
    column: $table.fillablePdfPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get textSize => $composableBuilder(
    column: $table.textSize,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pagesRefs(
    Expression<bool> Function($$PagesTableFilterComposer f) f,
  ) {
    final $$PagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pages,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagesTableFilterComposer(
            $db: $db,
            $table: $db.pages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> fieldsRefs(
    Expression<bool> Function($$FieldsTableFilterComposer f) f,
  ) {
    final $$FieldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fields,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FieldsTableFilterComposer(
            $db: $db,
            $table: $db.fields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
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

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
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

  ColumnOrderings<String> get pressedPdfPath => $composableBuilder(
    column: $table.pressedPdfPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fillablePdfPath => $composableBuilder(
    column: $table.fillablePdfPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get textSize => $composableBuilder(
    column: $table.textSize,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get ocrText =>
      $composableBuilder(column: $table.ocrText, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get pressedPdfPath => $composableBuilder(
    column: $table.pressedPdfPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fillablePdfPath => $composableBuilder(
    column: $table.fillablePdfPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get textSize =>
      $composableBuilder(column: $table.textSize, builder: (column) => column);

  Expression<T> pagesRefs<T extends Object>(
    Expression<T> Function($$PagesTableAnnotationComposer a) f,
  ) {
    final $$PagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pages,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagesTableAnnotationComposer(
            $db: $db,
            $table: $db.pages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> fieldsRefs<T extends Object>(
    Expression<T> Function($$FieldsTableAnnotationComposer a) f,
  ) {
    final $$FieldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fields,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FieldsTableAnnotationComposer(
            $db: $db,
            $table: $db.fields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          Document,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (Document, $$DocumentsTableReferences),
          Document,
          PrefetchHooks Function({bool pagesRefs, bool fieldsRefs})
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> ocrText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> pressedPdfPath = const Value.absent(),
                Value<String?> fillablePdfPath = const Value.absent(),
                Value<bool> isTemplate = const Value.absent(),
                Value<double?> textSize = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                uuid: uuid,
                title: title,
                status: status,
                pageCount: pageCount,
                ocrText: ocrText,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pressedPdfPath: pressedPdfPath,
                fillablePdfPath: fillablePdfPath,
                isTemplate: isTemplate,
                textSize: textSize,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String title,
                Value<String> status = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> ocrText = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> pressedPdfPath = const Value.absent(),
                Value<String?> fillablePdfPath = const Value.absent(),
                Value<bool> isTemplate = const Value.absent(),
                Value<double?> textSize = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                uuid: uuid,
                title: title,
                status: status,
                pageCount: pageCount,
                ocrText: ocrText,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pressedPdfPath: pressedPdfPath,
                fillablePdfPath: fillablePdfPath,
                isTemplate: isTemplate,
                textSize: textSize,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({pagesRefs = false, fieldsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (pagesRefs) db.pages,
                if (fieldsRefs) db.fields,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (pagesRefs)
                    await $_getPrefetchedData<Document, $DocumentsTable, Page>(
                      currentTable: table,
                      referencedTable: $$DocumentsTableReferences
                          ._pagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DocumentsTableReferences(db, table, p0).pagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.documentId == item.id),
                      typedResults: items,
                    ),
                  if (fieldsRefs)
                    await $_getPrefetchedData<Document, $DocumentsTable, Field>(
                      currentTable: table,
                      referencedTable: $$DocumentsTableReferences
                          ._fieldsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DocumentsTableReferences(db, table, p0).fieldsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.documentId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      Document,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (Document, $$DocumentsTableReferences),
      Document,
      PrefetchHooks Function({bool pagesRefs, bool fieldsRefs})
    >;
typedef $$PagesTableCreateCompanionBuilder =
    PagesCompanion Function({
      Value<int> id,
      required int documentId,
      required int pageIndex,
      required String imagePath,
      Value<String> activeFilter,
      Value<String> ocrText,
    });
typedef $$PagesTableUpdateCompanionBuilder =
    PagesCompanion Function({
      Value<int> id,
      Value<int> documentId,
      Value<int> pageIndex,
      Value<String> imagePath,
      Value<String> activeFilter,
      Value<String> ocrText,
    });

final class $$PagesTableReferences
    extends BaseReferences<_$AppDatabase, $PagesTable, Page> {
  $$PagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DocumentsTable _documentIdTable(_$AppDatabase db) => db.documents
      .createAlias($_aliasNameGenerator(db.pages.documentId, db.documents.id));

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<int>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PagesTableFilterComposer extends Composer<_$AppDatabase, $PagesTable> {
  $$PagesTableFilterComposer({
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

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeFilter => $composableBuilder(
    column: $table.activeFilter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagesTableOrderingComposer
    extends Composer<_$AppDatabase, $PagesTable> {
  $$PagesTableOrderingComposer({
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

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeFilter => $composableBuilder(
    column: $table.activeFilter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PagesTable> {
  $$PagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get activeFilter => $composableBuilder(
    column: $table.activeFilter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ocrText =>
      $composableBuilder(column: $table.ocrText, builder: (column) => column);

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PagesTable,
          Page,
          $$PagesTableFilterComposer,
          $$PagesTableOrderingComposer,
          $$PagesTableAnnotationComposer,
          $$PagesTableCreateCompanionBuilder,
          $$PagesTableUpdateCompanionBuilder,
          (Page, $$PagesTableReferences),
          Page,
          PrefetchHooks Function({bool documentId})
        > {
  $$PagesTableTableManager(_$AppDatabase db, $PagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> documentId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String> activeFilter = const Value.absent(),
                Value<String> ocrText = const Value.absent(),
              }) => PagesCompanion(
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                imagePath: imagePath,
                activeFilter: activeFilter,
                ocrText: ocrText,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int documentId,
                required int pageIndex,
                required String imagePath,
                Value<String> activeFilter = const Value.absent(),
                Value<String> ocrText = const Value.absent(),
              }) => PagesCompanion.insert(
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                imagePath: imagePath,
                activeFilter: activeFilter,
                ocrText: ocrText,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PagesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable: $$PagesTableReferences
                                    ._documentIdTable(db),
                                referencedColumn: $$PagesTableReferences
                                    ._documentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PagesTable,
      Page,
      $$PagesTableFilterComposer,
      $$PagesTableOrderingComposer,
      $$PagesTableAnnotationComposer,
      $$PagesTableCreateCompanionBuilder,
      $$PagesTableUpdateCompanionBuilder,
      (Page, $$PagesTableReferences),
      Page,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$FieldsTableCreateCompanionBuilder =
    FieldsCompanion Function({
      Value<int> id,
      required int documentId,
      required int pageIndex,
      required String type,
      required String boundingBoxJson,
      Value<String> label,
      Value<String> value,
      Value<bool> isChecked,
      Value<bool> isFilled,
      Value<int?> signatureId,
      Value<String?> pdfFieldName,
      Value<bool> isRequired,
      Value<String> sourceKind,
      Value<String?> optionsJson,
    });
typedef $$FieldsTableUpdateCompanionBuilder =
    FieldsCompanion Function({
      Value<int> id,
      Value<int> documentId,
      Value<int> pageIndex,
      Value<String> type,
      Value<String> boundingBoxJson,
      Value<String> label,
      Value<String> value,
      Value<bool> isChecked,
      Value<bool> isFilled,
      Value<int?> signatureId,
      Value<String?> pdfFieldName,
      Value<bool> isRequired,
      Value<String> sourceKind,
      Value<String?> optionsJson,
    });

final class $$FieldsTableReferences
    extends BaseReferences<_$AppDatabase, $FieldsTable, Field> {
  $$FieldsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DocumentsTable _documentIdTable(_$AppDatabase db) => db.documents
      .createAlias($_aliasNameGenerator(db.fields.documentId, db.documents.id));

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<int>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FieldsTableFilterComposer
    extends Composer<_$AppDatabase, $FieldsTable> {
  $$FieldsTableFilterComposer({
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

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boundingBoxJson => $composableBuilder(
    column: $table.boundingBoxJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isChecked => $composableBuilder(
    column: $table.isChecked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFilled => $composableBuilder(
    column: $table.isFilled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get signatureId => $composableBuilder(
    column: $table.signatureId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfFieldName => $composableBuilder(
    column: $table.pdfFieldName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FieldsTableOrderingComposer
    extends Composer<_$AppDatabase, $FieldsTable> {
  $$FieldsTableOrderingComposer({
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

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boundingBoxJson => $composableBuilder(
    column: $table.boundingBoxJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isChecked => $composableBuilder(
    column: $table.isChecked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFilled => $composableBuilder(
    column: $table.isFilled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get signatureId => $composableBuilder(
    column: $table.signatureId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfFieldName => $composableBuilder(
    column: $table.pdfFieldName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FieldsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FieldsTable> {
  $$FieldsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get boundingBoxJson => $composableBuilder(
    column: $table.boundingBoxJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<bool> get isChecked =>
      $composableBuilder(column: $table.isChecked, builder: (column) => column);

  GeneratedColumn<bool> get isFilled =>
      $composableBuilder(column: $table.isFilled, builder: (column) => column);

  GeneratedColumn<int> get signatureId => $composableBuilder(
    column: $table.signatureId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfFieldName => $composableBuilder(
    column: $table.pdfFieldName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FieldsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FieldsTable,
          Field,
          $$FieldsTableFilterComposer,
          $$FieldsTableOrderingComposer,
          $$FieldsTableAnnotationComposer,
          $$FieldsTableCreateCompanionBuilder,
          $$FieldsTableUpdateCompanionBuilder,
          (Field, $$FieldsTableReferences),
          Field,
          PrefetchHooks Function({bool documentId})
        > {
  $$FieldsTableTableManager(_$AppDatabase db, $FieldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FieldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FieldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FieldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> documentId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> boundingBoxJson = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<bool> isChecked = const Value.absent(),
                Value<bool> isFilled = const Value.absent(),
                Value<int?> signatureId = const Value.absent(),
                Value<String?> pdfFieldName = const Value.absent(),
                Value<bool> isRequired = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String?> optionsJson = const Value.absent(),
              }) => FieldsCompanion(
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                type: type,
                boundingBoxJson: boundingBoxJson,
                label: label,
                value: value,
                isChecked: isChecked,
                isFilled: isFilled,
                signatureId: signatureId,
                pdfFieldName: pdfFieldName,
                isRequired: isRequired,
                sourceKind: sourceKind,
                optionsJson: optionsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int documentId,
                required int pageIndex,
                required String type,
                required String boundingBoxJson,
                Value<String> label = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<bool> isChecked = const Value.absent(),
                Value<bool> isFilled = const Value.absent(),
                Value<int?> signatureId = const Value.absent(),
                Value<String?> pdfFieldName = const Value.absent(),
                Value<bool> isRequired = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String?> optionsJson = const Value.absent(),
              }) => FieldsCompanion.insert(
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                type: type,
                boundingBoxJson: boundingBoxJson,
                label: label,
                value: value,
                isChecked: isChecked,
                isFilled: isFilled,
                signatureId: signatureId,
                pdfFieldName: pdfFieldName,
                isRequired: isRequired,
                sourceKind: sourceKind,
                optionsJson: optionsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$FieldsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable: $$FieldsTableReferences
                                    ._documentIdTable(db),
                                referencedColumn: $$FieldsTableReferences
                                    ._documentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FieldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FieldsTable,
      Field,
      $$FieldsTableFilterComposer,
      $$FieldsTableOrderingComposer,
      $$FieldsTableAnnotationComposer,
      $$FieldsTableCreateCompanionBuilder,
      $$FieldsTableUpdateCompanionBuilder,
      (Field, $$FieldsTableReferences),
      Field,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$SignaturesTableCreateCompanionBuilder =
    SignaturesCompanion Function({
      Value<int> id,
      Value<String> label,
      required String imagePath,
      Value<bool> isDefault,
      Value<bool> isInitials,
      required DateTime createdAt,
    });
typedef $$SignaturesTableUpdateCompanionBuilder =
    SignaturesCompanion Function({
      Value<int> id,
      Value<String> label,
      Value<String> imagePath,
      Value<bool> isDefault,
      Value<bool> isInitials,
      Value<DateTime> createdAt,
    });

class $$SignaturesTableFilterComposer
    extends Composer<_$AppDatabase, $SignaturesTable> {
  $$SignaturesTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInitials => $composableBuilder(
    column: $table.isInitials,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignaturesTableOrderingComposer
    extends Composer<_$AppDatabase, $SignaturesTable> {
  $$SignaturesTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInitials => $composableBuilder(
    column: $table.isInitials,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignaturesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignaturesTable> {
  $$SignaturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<bool> get isInitials => $composableBuilder(
    column: $table.isInitials,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SignaturesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignaturesTable,
          Signature,
          $$SignaturesTableFilterComposer,
          $$SignaturesTableOrderingComposer,
          $$SignaturesTableAnnotationComposer,
          $$SignaturesTableCreateCompanionBuilder,
          $$SignaturesTableUpdateCompanionBuilder,
          (
            Signature,
            BaseReferences<_$AppDatabase, $SignaturesTable, Signature>,
          ),
          Signature,
          PrefetchHooks Function()
        > {
  $$SignaturesTableTableManager(_$AppDatabase db, $SignaturesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignaturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignaturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SignaturesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<bool> isInitials = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SignaturesCompanion(
                id: id,
                label: label,
                imagePath: imagePath,
                isDefault: isDefault,
                isInitials: isInitials,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                required String imagePath,
                Value<bool> isDefault = const Value.absent(),
                Value<bool> isInitials = const Value.absent(),
                required DateTime createdAt,
              }) => SignaturesCompanion.insert(
                id: id,
                label: label,
                imagePath: imagePath,
                isDefault: isDefault,
                isInitials: isInitials,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignaturesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignaturesTable,
      Signature,
      $$SignaturesTableFilterComposer,
      $$SignaturesTableOrderingComposer,
      $$SignaturesTableAnnotationComposer,
      $$SignaturesTableCreateCompanionBuilder,
      $$SignaturesTableUpdateCompanionBuilder,
      (Signature, BaseReferences<_$AppDatabase, $SignaturesTable, Signature>),
      Signature,
      PrefetchHooks Function()
    >;
typedef $$UserProfileTableCreateCompanionBuilder =
    UserProfileCompanion Function({
      Value<int> id,
      Value<String> fullName,
      Value<String> email,
      Value<String> phone,
      Value<String> address,
      Value<String> city,
      Value<String> state,
      Value<String> zip,
      Value<String> company,
      Value<bool> biometricLockEnabled,
      Value<bool> aiEnhancedDetection,
      Value<int> scanCount,
      Value<bool> isPurchased,
      Value<bool> includeInDeviceBackup,
    });
typedef $$UserProfileTableUpdateCompanionBuilder =
    UserProfileCompanion Function({
      Value<int> id,
      Value<String> fullName,
      Value<String> email,
      Value<String> phone,
      Value<String> address,
      Value<String> city,
      Value<String> state,
      Value<String> zip,
      Value<String> company,
      Value<bool> biometricLockEnabled,
      Value<bool> aiEnhancedDetection,
      Value<int> scanCount,
      Value<bool> isPurchased,
      Value<bool> includeInDeviceBackup,
    });

class $$UserProfileTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableFilterComposer({
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

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zip => $composableBuilder(
    column: $table.zip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get biometricLockEnabled => $composableBuilder(
    column: $table.biometricLockEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get aiEnhancedDetection => $composableBuilder(
    column: $table.aiEnhancedDetection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scanCount => $composableBuilder(
    column: $table.scanCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPurchased => $composableBuilder(
    column: $table.isPurchased,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInDeviceBackup => $composableBuilder(
    column: $table.includeInDeviceBackup,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableOrderingComposer({
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

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zip => $composableBuilder(
    column: $table.zip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get biometricLockEnabled => $composableBuilder(
    column: $table.biometricLockEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aiEnhancedDetection => $composableBuilder(
    column: $table.aiEnhancedDetection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scanCount => $composableBuilder(
    column: $table.scanCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPurchased => $composableBuilder(
    column: $table.isPurchased,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInDeviceBackup => $composableBuilder(
    column: $table.includeInDeviceBackup,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get zip =>
      $composableBuilder(column: $table.zip, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<bool> get biometricLockEnabled => $composableBuilder(
    column: $table.biometricLockEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get aiEnhancedDetection => $composableBuilder(
    column: $table.aiEnhancedDetection,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scanCount =>
      $composableBuilder(column: $table.scanCount, builder: (column) => column);

  GeneratedColumn<bool> get isPurchased => $composableBuilder(
    column: $table.isPurchased,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get includeInDeviceBackup => $composableBuilder(
    column: $table.includeInDeviceBackup,
    builder: (column) => column,
  );
}

class $$UserProfileTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfileTable,
          UserProfileData,
          $$UserProfileTableFilterComposer,
          $$UserProfileTableOrderingComposer,
          $$UserProfileTableAnnotationComposer,
          $$UserProfileTableCreateCompanionBuilder,
          $$UserProfileTableUpdateCompanionBuilder,
          (
            UserProfileData,
            BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileData>,
          ),
          UserProfileData,
          PrefetchHooks Function()
        > {
  $$UserProfileTableTableManager(_$AppDatabase db, $UserProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> zip = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<bool> biometricLockEnabled = const Value.absent(),
                Value<bool> aiEnhancedDetection = const Value.absent(),
                Value<int> scanCount = const Value.absent(),
                Value<bool> isPurchased = const Value.absent(),
                Value<bool> includeInDeviceBackup = const Value.absent(),
              }) => UserProfileCompanion(
                id: id,
                fullName: fullName,
                email: email,
                phone: phone,
                address: address,
                city: city,
                state: state,
                zip: zip,
                company: company,
                biometricLockEnabled: biometricLockEnabled,
                aiEnhancedDetection: aiEnhancedDetection,
                scanCount: scanCount,
                isPurchased: isPurchased,
                includeInDeviceBackup: includeInDeviceBackup,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> zip = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<bool> biometricLockEnabled = const Value.absent(),
                Value<bool> aiEnhancedDetection = const Value.absent(),
                Value<int> scanCount = const Value.absent(),
                Value<bool> isPurchased = const Value.absent(),
                Value<bool> includeInDeviceBackup = const Value.absent(),
              }) => UserProfileCompanion.insert(
                id: id,
                fullName: fullName,
                email: email,
                phone: phone,
                address: address,
                city: city,
                state: state,
                zip: zip,
                company: company,
                biometricLockEnabled: biometricLockEnabled,
                aiEnhancedDetection: aiEnhancedDetection,
                scanCount: scanCount,
                isPurchased: isPurchased,
                includeInDeviceBackup: includeInDeviceBackup,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfileTable,
      UserProfileData,
      $$UserProfileTableFilterComposer,
      $$UserProfileTableOrderingComposer,
      $$UserProfileTableAnnotationComposer,
      $$UserProfileTableCreateCompanionBuilder,
      $$UserProfileTableUpdateCompanionBuilder,
      (
        UserProfileData,
        BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileData>,
      ),
      UserProfileData,
      PrefetchHooks Function()
    >;
typedef $$FieldHintsTableCreateCompanionBuilder =
    FieldHintsCompanion Function({
      Value<int> id,
      required String phrase,
      required String type,
      Value<int> accepted,
      Value<int> rejected,
      required DateTime updatedAt,
    });
typedef $$FieldHintsTableUpdateCompanionBuilder =
    FieldHintsCompanion Function({
      Value<int> id,
      Value<String> phrase,
      Value<String> type,
      Value<int> accepted,
      Value<int> rejected,
      Value<DateTime> updatedAt,
    });

class $$FieldHintsTableFilterComposer
    extends Composer<_$AppDatabase, $FieldHintsTable> {
  $$FieldHintsTableFilterComposer({
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

  ColumnFilters<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accepted => $composableBuilder(
    column: $table.accepted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FieldHintsTableOrderingComposer
    extends Composer<_$AppDatabase, $FieldHintsTable> {
  $$FieldHintsTableOrderingComposer({
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

  ColumnOrderings<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accepted => $composableBuilder(
    column: $table.accepted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FieldHintsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FieldHintsTable> {
  $$FieldHintsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get phrase =>
      $composableBuilder(column: $table.phrase, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get accepted =>
      $composableBuilder(column: $table.accepted, builder: (column) => column);

  GeneratedColumn<int> get rejected =>
      $composableBuilder(column: $table.rejected, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FieldHintsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FieldHintsTable,
          FieldHint,
          $$FieldHintsTableFilterComposer,
          $$FieldHintsTableOrderingComposer,
          $$FieldHintsTableAnnotationComposer,
          $$FieldHintsTableCreateCompanionBuilder,
          $$FieldHintsTableUpdateCompanionBuilder,
          (
            FieldHint,
            BaseReferences<_$AppDatabase, $FieldHintsTable, FieldHint>,
          ),
          FieldHint,
          PrefetchHooks Function()
        > {
  $$FieldHintsTableTableManager(_$AppDatabase db, $FieldHintsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FieldHintsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FieldHintsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FieldHintsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> phrase = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> accepted = const Value.absent(),
                Value<int> rejected = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => FieldHintsCompanion(
                id: id,
                phrase: phrase,
                type: type,
                accepted: accepted,
                rejected: rejected,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String phrase,
                required String type,
                Value<int> accepted = const Value.absent(),
                Value<int> rejected = const Value.absent(),
                required DateTime updatedAt,
              }) => FieldHintsCompanion.insert(
                id: id,
                phrase: phrase,
                type: type,
                accepted: accepted,
                rejected: rejected,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FieldHintsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FieldHintsTable,
      FieldHint,
      $$FieldHintsTableFilterComposer,
      $$FieldHintsTableOrderingComposer,
      $$FieldHintsTableAnnotationComposer,
      $$FieldHintsTableCreateCompanionBuilder,
      $$FieldHintsTableUpdateCompanionBuilder,
      (FieldHint, BaseReferences<_$AppDatabase, $FieldHintsTable, FieldHint>),
      FieldHint,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$PagesTableTableManager get pages =>
      $$PagesTableTableManager(_db, _db.pages);
  $$FieldsTableTableManager get fields =>
      $$FieldsTableTableManager(_db, _db.fields);
  $$SignaturesTableTableManager get signatures =>
      $$SignaturesTableTableManager(_db, _db.signatures);
  $$UserProfileTableTableManager get userProfile =>
      $$UserProfileTableTableManager(_db, _db.userProfile);
  $$FieldHintsTableTableManager get fieldHints =>
      $$FieldHintsTableTableManager(_db, _db.fieldHints);
}
