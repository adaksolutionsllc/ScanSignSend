import 'dart:convert';
import 'dart:typed_data';

import 'package:agreements_core/agreements_core.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Whether the PDF still holds exactly the content its envelope describes.
enum EnvelopeIntegrity {
  intact,

  /// The bytes the envelope hashed have changed, e.g. the file was re-saved
  /// in Preview or another editor. The envelope can't continue.
  modified,
}

class OpenedEnvelope {
  const OpenedEnvelope(this.envelope, this.integrity, this.content);

  final Envelope envelope;
  final EnvelopeIntegrity integrity;

  /// The content PDF the envelope describes (the file's prefix); null unless
  /// [integrity] is intact.
  final Uint8List? content;
}

/// Puts an [Envelope] inside a PDF and reads it back.
///
/// The envelope is a PDF file attachment written as an incremental update, so
/// the content PDF stays an exact byte prefix of the file and
/// [Envelope.content] can hash it. Pure functions over bytes, safe to run in
/// an isolate.
abstract final class EnvelopePdf {
  /// [content] with [envelope] attached. The envelope must already describe
  /// [content] (see [Envelope.senderSigned] / [Envelope.recipientSigned]).
  static Uint8List seal(Uint8List content, Envelope envelope) {
    if (envelope.content != ContentDigest.of(content)) {
      throw const EnvelopeException(EnvelopeError.contentMismatch, 'seal');
    }
    final doc = PdfDocument(inputBytes: content);
    try {
      // Loaded documents save incrementally; keep it explicit, since the
      // whole integrity check depends on it.
      doc.fileStructure.incrementalUpdate = true;
      doc.attachments.add(
        PdfAttachment(
          Envelope.attachmentName,
          utf8.encode(envelope.encode()),
          description: 'Scan Sign Send envelope',
          mimeType: 'application/json',
        ),
      );
      final out = Uint8List.fromList(doc.saveSync());
      // Never hand out a file that would fail its own check.
      if (!envelope.content!.matchesPrefixOf(out)) {
        throw const EnvelopeException(EnvelopeError.contentMismatch, 'prefix');
      }
      return out;
    } finally {
      doc.dispose();
    }
  }

  /// The envelope in [file], or null when the PDF has none (an ordinary PDF).
  /// Throws [EnvelopeException] when an envelope is present but unreadable or
  /// from a newer app version.
  static OpenedEnvelope? open(Uint8List file) {
    final String? json;
    final doc = PdfDocument(inputBytes: file);
    try {
      json = _attachment(doc);
    } finally {
      doc.dispose();
    }
    if (json == null) return null;

    final envelope = Envelope.decode(json);
    final digest = envelope.content;
    if (digest == null || !digest.matchesPrefixOf(file)) {
      return OpenedEnvelope(envelope, EnvelopeIntegrity.modified, null);
    }
    return OpenedEnvelope(
      envelope,
      EnvelopeIntegrity.intact,
      Uint8List.sublistView(file, 0, digest.length),
    );
  }

  /// Quick check for routing an opened file, without validating it.
  static bool hasEnvelope(Uint8List file) {
    final doc = PdfDocument(inputBytes: file);
    try {
      return _attachment(doc) != null;
    } finally {
      doc.dispose();
    }
  }

  static String? _attachment(PdfDocument doc) {
    for (var i = 0; i < doc.attachments.count; i++) {
      final a = doc.attachments[i];
      if (a.fileName == Envelope.attachmentName) {
        try {
          return utf8.decode(a.data);
        } on FormatException {
          throw const EnvelopeException(EnvelopeError.malformed, 'utf8');
        }
      }
    }
    return null;
  }
}
