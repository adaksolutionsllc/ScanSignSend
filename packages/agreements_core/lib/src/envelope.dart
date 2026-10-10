import 'dart:convert';

import 'audit_event.dart';
import 'code_kdf.dart';
import 'digest.dart';
import 'errors.dart';
import 'json_read.dart';

enum PartyRole { sender, recipient }

class Party {
  const Party({
    required this.id,
    required this.role,
    required this.name,
    this.email,
    this.phone,
    this.idRequired = false,
  });

  final String id;
  final PartyRole role;

  /// As entered by the sender; the recipient signs "as" this name.
  final String name;

  /// As entered by the sender, used to prefill sending. Full addresses ride in
  /// the PDF so the recipient's app can show "sent to you at …"; the audit
  /// page masks them.
  final String? email;
  final String? phone;

  /// Sender asked this party to present an ID (identity phase; carried now so
  /// the format doesn't change later).
  final bool idRequired;

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'name': name,
    'email': ?email,
    'phone': ?phone,
    'idRequired': idRequired,
  };

  factory Party.fromJson(Map<String, Object?> j) => Party(
    id: readString(j, 'id'),
    role: readEnum(j, 'role', PartyRole.values),
    name: readString(j, 'name'),
    email: readOptionalString(j, 'email'),
    phone: readOptionalString(j, 'phone'),
    idRequired: readOptionalBool(j, 'idRequired') ?? false,
  );
}

/// A field one party fills. Geometry is normalised to the page (0..1, top
/// left origin), matching the app's `BoundingBox`. [type] is the app's
/// `FieldType` name, kept as a string so this package doesn't depend on it.
class EnvelopeField {
  const EnvelopeField({
    required this.id,
    required this.partyId,
    required this.page,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.label = '',
    this.required = false,
  });

  static const signatureType = 'signature';

  final String id;
  final String partyId;
  final int page;
  final String type;
  final double x, y, w, h;
  final String label;
  final bool required;

  Map<String, Object?> toJson() => {
    'id': id,
    'party': partyId,
    'page': page,
    'type': type,
    'box': {'x': x, 'y': y, 'w': w, 'h': h},
    if (label.isNotEmpty) 'label': label,
    if (required) 'required': true,
  };

  factory EnvelopeField.fromJson(Map<String, Object?> j) {
    final box = readMap(j, 'box');
    return EnvelopeField(
      id: readString(j, 'id'),
      partyId: readString(j, 'party'),
      page: readInt(j, 'page'),
      type: readString(j, 'type'),
      x: readDouble(box, 'x'),
      y: readDouble(box, 'y'),
      w: readDouble(box, 'w'),
      h: readDouble(box, 'h'),
      label: readOptionalString(j, 'label') ?? '',
      required: readOptionalBool(j, 'required') ?? false,
    );
  }
}

enum EnvelopeStatus {
  /// Sender is still preparing; nothing signed yet.
  draft,

  /// Sender signed their portion; waiting for the recipient.
  awaitingRecipient,

  /// Recipient signed and sent it back; sender to check and finish.
  awaitingSender,

  completed,
}

/// The signing envelope that travels inside the PDF as `ssse-envelope.json`.
///
/// Immutable: each step returns a new envelope with one more [log] entry.
/// Fixed order for this release: sender → recipient → sender.
class Envelope {
  const Envelope._({
    required this.id,
    required this.tag,
    required this.title,
    required this.createdAt,
    required this.parties,
    required this.fields,
    required this.access,
    required this.content,
    required this.log,
  });

  static const formatName = 'ssse-envelope';
  static const formatVersion = 1;
  static const attachmentName = 'ssse-envelope.json';

  final String id;

  /// Short public tag for file names (`EV7Q3K`); matching always uses [id].
  final String tag;
  final String title;
  final DateTime createdAt;
  final List<Party> parties;
  final List<EnvelopeField> fields;
  final AccessVerifier access;

  /// The PDF the latest step produced; null until the sender signs.
  final ContentDigest? content;
  final List<AuditEvent> log;

  /// A new envelope. Throws [EnvelopeException] unless there's exactly one
  /// sender and one recipient, every field belongs to one of them, and the
  /// recipient has a signature field.
  factory Envelope.draft({
    required String id,
    required String tag,
    required String title,
    required DateTime now,
    required Party sender,
    required Party recipient,
    required List<EnvelopeField> fields,
    required AccessVerifier access,
  }) {
    final env = Envelope._(
      id: id,
      tag: tag,
      title: title,
      createdAt: now.toUtc(),
      parties: List.unmodifiable([sender, recipient]),
      fields: List.unmodifiable(fields),
      access: access,
      content: null,
      log: const [],
    );
    env._validate();
    return env;
  }

  Party get sender => parties.firstWhere((p) => p.role == PartyRole.sender);
  Party get recipient =>
      parties.firstWhere((p) => p.role == PartyRole.recipient);

  Iterable<EnvelopeField> fieldsOf(String partyId) =>
      fields.where((f) => f.partyId == partyId);

  bool _signedBy(String partyId) =>
      log.any((e) => e.kind == AuditKind.signed && e.partyId == partyId);

  EnvelopeStatus get status {
    if (log.any((e) => e.kind == AuditKind.completed)) {
      return EnvelopeStatus.completed;
    }
    if (_signedBy(recipient.id)) return EnvelopeStatus.awaitingSender;
    if (_signedBy(sender.id)) return EnvelopeStatus.awaitingRecipient;
    return EnvelopeStatus.draft;
  }

  bool get codeAccepted => log.any(
    (e) => e.kind == AuditKind.codeAccepted && e.partyId == recipient.id,
  );

  // ── Steps ────────────────────────────────────────────────────────────────

  /// Sender signed and flattened their portion into [contentAfter], the PDF
  /// the recipient will receive.
  Envelope senderSigned({
    required ContentDigest contentAfter,
    required DateTime now,
  }) {
    _require(EnvelopeStatus.draft);
    return _append(
      AuditEvent(
        kind: AuditKind.signed,
        partyId: sender.id,
        at: now.toUtc(),
        contentAfter: contentAfter,
        signerName: sender.name,
      ),
      content: contentAfter,
    );
  }

  /// Sender handed the PDF or code to another app. Kept in the sender's
  /// local copy; see [mergeReturned].
  Envelope sent({
    required SendItem item,
    required SendRoute route,
    required bool confirmed,
    String? maskedAddress,
    required DateTime now,
  }) {
    _require(EnvelopeStatus.awaitingRecipient);
    return _append(
      AuditEvent(
        kind: AuditKind.sent,
        partyId: sender.id,
        at: now.toUtc(),
        item: item,
        route: route,
        confirmed: confirmed,
        maskedAddress: maskedAddress,
      ),
    );
  }

  /// Recipient's app accepted the code. Call after [AccessVerifier.matches].
  Envelope codeWasAccepted({required DateTime now}) {
    _require(EnvelopeStatus.awaitingRecipient);
    if (codeAccepted) return this;
    return _append(
      AuditEvent(
        kind: AuditKind.codeAccepted,
        partyId: recipient.id,
        at: now.toUtc(),
      ),
    );
  }

  /// Recipient signed and flattened their portion into [contentAfter].
  Envelope recipientSigned({
    required String canonicalCode,
    required ContentDigest contentAfter,
    required DateTime now,
  }) {
    _require(EnvelopeStatus.awaitingRecipient);
    if (!codeAccepted) {
      throw const EnvelopeException(EnvelopeError.wrongState, 'code');
    }
    final before = content!;
    return _append(
      AuditEvent(
        kind: AuditKind.signed,
        partyId: recipient.id,
        at: now.toUtc(),
        contentBefore: before,
        contentAfter: contentAfter,
        signerName: recipient.name,
        codeProof: accessCodeProof(
          canonicalCode: canonicalCode,
          envelopeId: id,
          signerName: recipient.name,
          contentSha256Hex: before.hash,
        ),
      ),
      content: contentAfter,
    );
  }

  /// Sender's app finishes a returned envelope: recomputes the recipient's
  /// code proof from the code it kept. Throws [EnvelopeError.proofMismatch]
  /// when the signer's app never had the code.
  Envelope complete({required String canonicalCode, required DateTime now}) {
    _require(EnvelopeStatus.awaitingSender);
    final signed = log.lastWhere(
      (e) => e.kind == AuditKind.signed && e.partyId == recipient.id,
    );
    final expected = accessCodeProof(
      canonicalCode: canonicalCode,
      envelopeId: id,
      signerName: signed.signerName ?? '',
      contentSha256Hex: signed.contentBefore?.hash ?? '',
    );
    if (signed.codeProof == null ||
        !constantTimeEquals(
          utf8.encode(signed.codeProof!),
          utf8.encode(expected),
        )) {
      throw const EnvelopeException(EnvelopeError.proofMismatch);
    }
    return _append(
      AuditEvent(
        kind: AuditKind.completed,
        partyId: sender.id,
        at: now.toUtc(),
        contentAfter: content,
      ),
    );
  }

  /// Combines the sender's local copy with the envelope the recipient sent
  /// back. The returned copy must describe the same envelope and keep every
  /// entry the sender sealed into the PDF, in order; the sender's local
  /// [AuditKind.sent] entries are then added back by time.
  static Envelope mergeReturned({
    required Envelope local,
    required Envelope returned,
  }) {
    if (returned.id != local.id ||
        jsonEncode(returned._identityJson()) !=
            jsonEncode(local._identityJson())) {
      throw const EnvelopeException(EnvelopeError.contentMismatch, 'identity');
    }
    final sealed = local.log.where((e) => e.kind != AuditKind.sent).toList();
    if (returned.log.length < sealed.length) {
      throw const EnvelopeException(EnvelopeError.contentMismatch, 'log');
    }
    for (var i = 0; i < sealed.length; i++) {
      if (jsonEncode(returned.log[i].toJson()) !=
          jsonEncode(sealed[i].toJson())) {
        throw const EnvelopeException(EnvelopeError.contentMismatch, 'log');
      }
    }
    if (returned.log.any((e) => e.kind == AuditKind.sent)) {
      throw const EnvelopeException(EnvelopeError.contentMismatch, 'sent');
    }
    final merged = [
      ...returned.log,
      ...local.log.where((e) => e.kind == AuditKind.sent),
    ];
    // Stable by time: equal timestamps keep their order above.
    final indexed = merged.indexed.toList()
      ..sort((a, b) {
        final c = a.$2.at.compareTo(b.$2.at);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return returned._copy(log: [for (final e in indexed) e.$2]);
  }

  // ── JSON ─────────────────────────────────────────────────────────────────

  Map<String, Object?> toJson() => {
    'format': formatName,
    'version': formatVersion,
    ..._identityJson(),
    if (content != null) 'content': content!.toJson(),
    'log': [for (final e in log) e.toJson()],
  };

  /// Everything fixed when the envelope was drafted.
  Map<String, Object?> _identityJson() => {
    'id': id,
    'tag': tag,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'parties': [for (final p in parties) p.toJson()],
    'fields': [for (final f in fields) f.toJson()],
    'access': access.toJson(),
  };

  String encode() => jsonEncode(toJson());

  /// Parses and validates an envelope. Throws [EnvelopeException]:
  /// [EnvelopeError.unsupportedVersion] when a newer app wrote it, otherwise
  /// [EnvelopeError.malformed] or a validation error.
  static Envelope decode(String json) {
    final Object? raw;
    try {
      raw = jsonDecode(json);
    } on FormatException {
      throw const EnvelopeException(EnvelopeError.malformed, 'json');
    }
    if (raw is! Map) {
      throw const EnvelopeException(EnvelopeError.malformed, 'root');
    }
    final j = Map<String, Object?>.from(raw);
    if (j['format'] != formatName) {
      throw const EnvelopeException(EnvelopeError.malformed, 'format');
    }
    final version = readInt(j, 'version');
    if (version > formatVersion) {
      throw EnvelopeException(EnvelopeError.unsupportedVersion, '$version');
    }
    final access = readMap(j, 'access');
    if (access['kdf'] != AccessVerifier.kdfName) {
      throw const EnvelopeException(EnvelopeError.malformed, 'access.kdf');
    }
    final env = Envelope._(
      id: readString(j, 'id'),
      tag: readString(j, 'tag'),
      title: readString(j, 'title'),
      createdAt: readTime(j, 'createdAt'),
      parties: List.unmodifiable(readMapList(j, 'parties').map(Party.fromJson)),
      fields: List.unmodifiable(
        readMapList(j, 'fields').map(EnvelopeField.fromJson),
      ),
      access: AccessVerifier(
        iterations: readInt(access, 'iterations'),
        salt: readBase64(access, 'salt'),
        hash: readBase64(access, 'hash'),
      ),
      content: readOptionalDigest(j, 'content'),
      log: List.unmodifiable(readMapList(j, 'log').map(AuditEvent.fromJson)),
    );
    env._validate();
    return env;
  }

  // ── Internals ────────────────────────────────────────────────────────────

  void _validate() {
    final ids = parties.map((p) => p.id).toSet();
    if (parties.length != 2 ||
        ids.length != 2 ||
        parties.where((p) => p.role == PartyRole.sender).length != 1) {
      throw const EnvelopeException(EnvelopeError.invalidParties);
    }
    if (fields.any((f) => !ids.contains(f.partyId)) ||
        log.any((e) => !ids.contains(e.partyId))) {
      throw const EnvelopeException(EnvelopeError.unknownParty);
    }
    if (fields.map((f) => f.id).toSet().length != fields.length) {
      throw const EnvelopeException(EnvelopeError.malformed, 'fields.id');
    }
    if (!fieldsOf(
      recipient.id,
    ).any((f) => f.type == EnvelopeField.signatureType)) {
      throw const EnvelopeException(EnvelopeError.recipientCannotSign);
    }
    // A safe verifier needs real work per guess; refuse files that lower it.
    if (access.iterations < 1000 || access.salt.length < 16) {
      throw const EnvelopeException(EnvelopeError.malformed, 'access');
    }
  }

  void _require(EnvelopeStatus s) {
    if (status != s) {
      throw EnvelopeException(EnvelopeError.wrongState, status.name);
    }
  }

  Envelope _append(AuditEvent e, {ContentDigest? content}) =>
      _copy(log: [...log, e], content: content);

  Envelope _copy({List<AuditEvent>? log, ContentDigest? content}) =>
      Envelope._(
        id: id,
        tag: tag,
        title: title,
        createdAt: createdAt,
        parties: parties,
        fields: fields,
        access: access,
        content: content ?? this.content,
        log: List.unmodifiable(log ?? this.log),
      );
}
