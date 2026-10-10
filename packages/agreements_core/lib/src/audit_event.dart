import 'digest.dart';
import 'json_read.dart';

enum AuditKind {
  /// A party signed and flattened their portion ([AuditEvent.contentAfter]).
  signed,

  /// The sender handed the PDF or the code to another app (sender's log only;
  /// merged into the envelope when the file comes back).
  sent,

  /// The recipient's app accepted the access code against the verifier.
  codeAccepted,

  /// The sender's app checked the returned file and the code proof.
  completed,
}

/// How the sender sent something. Addresses are stored masked.
enum SendRoute { email, sms, whatsapp, shareSheet }

/// What was sent.
enum SendItem { pdf, code }

class AuditEvent {
  const AuditEvent({
    required this.kind,
    required this.partyId,
    required this.at,
    this.contentBefore,
    this.contentAfter,
    this.signerName,
    this.codeProof,
    this.route,
    this.item,
    this.maskedAddress,
    this.confirmed,
  });

  final AuditKind kind;
  final String partyId;

  /// The acting device's clock, UTC.
  final DateTime at;

  final ContentDigest? contentBefore;
  final ContentDigest? contentAfter;

  /// [AuditKind.signed]: the name the party signed as.
  final String? signerName;

  /// Recipient's [AuditKind.signed]: see `accessCodeProof`.
  final String? codeProof;

  /// [AuditKind.sent] only.
  final SendRoute? route;
  final SendItem? item;
  final String? maskedAddress;

  /// [AuditKind.sent]: true when the OS reported it sent (iOS composers);
  /// false when we only know it was handed to another app (Android, share
  /// sheet).
  final bool? confirmed;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'party': partyId,
    'at': at.toUtc().toIso8601String(),
    if (contentBefore != null) 'before': contentBefore!.toJson(),
    if (contentAfter != null) 'after': contentAfter!.toJson(),
    'signerName': ?signerName,
    'codeProof': ?codeProof,
    if (route != null) 'route': route!.name,
    if (item != null) 'item': item!.name,
    'address': ?maskedAddress,
    'confirmed': ?confirmed,
  };

  factory AuditEvent.fromJson(Map<String, Object?> j) => AuditEvent(
    kind: readEnum(j, 'kind', AuditKind.values),
    partyId: readString(j, 'party'),
    at: readTime(j, 'at'),
    contentBefore: readOptionalDigest(j, 'before'),
    contentAfter: readOptionalDigest(j, 'after'),
    signerName: readOptionalString(j, 'signerName'),
    codeProof: readOptionalString(j, 'codeProof'),
    route: readOptionalEnum(j, 'route', SendRoute.values),
    item: readOptionalEnum(j, 'item', SendItem.values),
    maskedAddress: readOptionalString(j, 'address'),
    confirmed: readOptionalBool(j, 'confirmed'),
  );
}
