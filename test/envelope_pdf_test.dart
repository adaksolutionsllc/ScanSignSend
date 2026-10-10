import 'dart:typed_data';
import 'dart:ui';

import 'package:agreements_core/agreements_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/services/envelope_pdf.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

final t0 = DateTime.utc(2026, 10, 9);
const kdf = DartPbkdf2Sha256();

Uint8List onePagePdf(String text) {
  final d = PdfDocument();
  d.pages.add().graphics.drawString(
    text,
    PdfStandardFont(PdfFontFamily.helvetica, 12),
  );
  final out = Uint8List.fromList(d.saveSync());
  d.dispose();
  return out;
}

/// Draws [text] onto [content] the way a party's flatten step does: loaded
/// and saved, so the earlier bytes stay a prefix.
Uint8List drawOn(Uint8List content, String text) {
  final d = PdfDocument(inputBytes: content);
  d.pages[0].graphics.drawString(
    text,
    PdfStandardFont(PdfFontFamily.helvetica, 12),
    bounds: const Rect.fromLTWH(0, 100, 300, 20),
  );
  final out = Uint8List.fromList(d.saveSync());
  d.dispose();
  return out;
}

Future<(Envelope, String)> draft() async {
  final code = AccessCode.generate();
  return (
    Envelope.draft(
      id: 'env-1',
      tag: 'EV7Q3K',
      title: 'Lease',
      now: t0,
      sender: const Party(id: 'p1', role: PartyRole.sender, name: 'Landlord'),
      recipient: const Party(
        id: 'p2',
        role: PartyRole.recipient,
        name: 'Tenant',
      ),
      fields: const [
        EnvelopeField(
          id: 'f1',
          partyId: 'p2',
          page: 0,
          type: 'signature',
          x: .1,
          y: .8,
          w: .3,
          h: .05,
        ),
      ],
      access: await AccessVerifier.create(code, kdf, iterations: 1000),
    ),
    code,
  );
}

void main() {
  test('an ordinary PDF has no envelope', () {
    final pdf = onePagePdf('plain');
    expect(EnvelopePdf.hasEnvelope(pdf), isFalse);
    expect(EnvelopePdf.open(pdf), isNull);
  });

  test('round trip through both parties', () async {
    final (d, code) = await draft();

    // Sender: content 1 = sender's portion flattened.
    final c1 = drawOn(onePagePdf('Lease terms'), 'Landlord signature');
    final e1 = d.senderSigned(contentAfter: ContentDigest.of(c1), now: t0);
    final file1 = EnvelopePdf.seal(c1, e1);
    expect(EnvelopePdf.hasEnvelope(file1), isTrue);

    // Recipient opens it; content excludes the envelope update.
    final o1 = EnvelopePdf.open(file1)!;
    expect(o1.integrity, EnvelopeIntegrity.intact);
    expect(o1.content, c1);
    expect(o1.envelope.status, EnvelopeStatus.awaitingRecipient);

    final c2 = drawOn(o1.content!, 'Tenant signature');
    // Each party's step only appends to the previous content.
    expect(ContentDigest.of(c1).matchesPrefixOf(c2), isTrue);
    final e2 = o1.envelope
        .codeWasAccepted(now: t0)
        .recipientSigned(
          canonicalCode: code,
          contentAfter: ContentDigest.of(c2),
          now: t0,
        );
    final file2 = EnvelopePdf.seal(c2, e2);

    // Sender gets it back.
    final o2 = EnvelopePdf.open(file2)!;
    expect(o2.integrity, EnvelopeIntegrity.intact);
    expect(o2.content, c2);
    final done = Envelope.mergeReturned(
      local: e1,
      returned: o2.envelope,
    ).complete(canonicalCode: code, now: t0);
    expect(done.status, EnvelopeStatus.completed);
  });

  test('a full re-save in another editor is detected', () async {
    final (d, _) = await draft();
    final c1 = onePagePdf('Lease terms');
    final file = EnvelopePdf.seal(
      c1,
      d.senderSigned(contentAfter: ContentDigest.of(c1), now: t0),
    );
    final re = PdfDocument(inputBytes: file)
      ..fileStructure.incrementalUpdate = false;
    final resaved = Uint8List.fromList(re.saveSync());
    re.dispose();

    final o = EnvelopePdf.open(resaved)!;
    expect(o.integrity, EnvelopeIntegrity.modified);
    expect(o.content, isNull);
  });

  test('seal refuses content the envelope does not describe', () async {
    final (d, _) = await draft();
    final c1 = onePagePdf('a');
    final e1 = d.senderSigned(contentAfter: ContentDigest.of(c1), now: t0);
    expect(
      () => EnvelopePdf.seal(onePagePdf('b'), e1),
      throwsA(isA<EnvelopeException>()),
    );
  });
}
