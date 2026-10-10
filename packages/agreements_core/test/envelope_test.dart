import 'package:agreements_core/agreements_core.dart';
import 'package:test/test.dart';

const kdf = DartPbkdf2Sha256();
final t0 = DateTime.utc(2026, 10, 9, 10);

const sender = Party(
  id: 'p1',
  role: PartyRole.sender,
  name: 'Oak Street Rentals',
);
const recipient = Party(
  id: 'p2',
  role: PartyRole.recipient,
  name: 'Priya Raman',
  email: 'priya.raman@gmail.com',
  phone: '+91 98765 54821',
);

EnvelopeField field(String id, String party, String type) => EnvelopeField(
  id: id,
  partyId: party,
  page: 0,
  type: type,
  x: 0.1,
  y: 0.8,
  w: 0.3,
  h: 0.05,
);

final fields = [
  field('f1', 'p1', 'signature'),
  field('f2', 'p2', 'text'),
  field('f3', 'p2', 'signature'),
];

ContentDigest digest(String s) => ContentDigest.of(s.codeUnits);

Future<(Envelope, String)> draft() async {
  final code = AccessCode.generate();
  final access = await AccessVerifier.create(code, kdf, iterations: 1000);
  final env = Envelope.draft(
    id: 'env-1',
    tag: 'EV7Q3K',
    title: 'Lease – 12 Oak St',
    now: t0,
    sender: sender,
    recipient: recipient,
    fields: fields,
    access: access,
  );
  return (env, code);
}

Matcher throwsEnvelope(EnvelopeError e) => throwsA(
  isA<EnvelopeException>().having((x) => x.error, 'error', e),
);

void main() {
  test('full cycle: sender → recipient → sender', () async {
    final (draftEnv, code) = await draft();
    expect(draftEnv.status, EnvelopeStatus.draft);

    // Sender signs, seals into the PDF (JSON round trip), then sends.
    final sealed = draftEnv.senderSigned(
      contentAfter: digest('pdf-1'),
      now: t0.add(const Duration(minutes: 1)),
    );
    expect(sealed.status, EnvelopeStatus.awaitingRecipient);
    final inPdf = sealed.encode();
    final local = sealed
        .sent(
          item: SendItem.pdf,
          route: SendRoute.email,
          confirmed: true,
          maskedAddress: maskEmail(recipient.email!),
          now: t0.add(const Duration(minutes: 2)),
        )
        .sent(
          item: SendItem.code,
          route: SendRoute.whatsapp,
          confirmed: false,
          maskedAddress: maskPhone(recipient.phone!),
          now: t0.add(const Duration(minutes: 3)),
        );

    // Recipient opens it, enters the code, signs.
    var r = Envelope.decode(inPdf);
    expect(r.status, EnvelopeStatus.awaitingRecipient);
    expect(r.fieldsOf('p2').map((f) => f.id), ['f2', 'f3']);
    expect(
      () => r.recipientSigned(
        canonicalCode: code,
        contentAfter: digest('pdf-2'),
        now: t0,
      ),
      throwsEnvelope(EnvelopeError.wrongState),
      reason: 'cannot sign before the code is accepted',
    );
    expect(await r.access.matches(code, kdf), isTrue);
    r = r
        .codeWasAccepted(now: t0.add(const Duration(hours: 4)))
        .recipientSigned(
          canonicalCode: code,
          contentAfter: digest('pdf-2'),
          now: t0.add(const Duration(hours: 4, minutes: 1)),
        );
    expect(r.status, EnvelopeStatus.awaitingSender);
    final returned = r.encode();

    // Sender merges and completes.
    final merged = Envelope.mergeReturned(
      local: local,
      returned: Envelope.decode(returned),
    );
    expect(merged.log.map((e) => e.kind), [
      AuditKind.signed,
      AuditKind.sent,
      AuditKind.sent,
      AuditKind.codeAccepted,
      AuditKind.signed,
    ]);
    final done = merged.complete(
      canonicalCode: code,
      now: t0.add(const Duration(days: 1)),
    );
    expect(done.status, EnvelopeStatus.completed);
    expect(done.content, digest('pdf-2'));
    expect(Envelope.decode(done.encode()).status, EnvelopeStatus.completed);
  });

  test('complete rejects a proof made without the code', () async {
    final (d, code) = await draft();
    final sealed = d.senderSigned(contentAfter: digest('a'), now: t0);
    final forged = sealed
        .codeWasAccepted(now: t0)
        .recipientSigned(
          canonicalCode: AccessCode.generate(), // a modified app guessing
          contentAfter: digest('b'),
          now: t0,
        );
    expect(
      () => forged.complete(canonicalCode: code, now: t0),
      throwsEnvelope(EnvelopeError.proofMismatch),
    );
  });

  test('merge rejects a returned copy that rewrote history', () async {
    final (d, _) = await draft();
    final local = d.senderSigned(contentAfter: digest('a'), now: t0);
    final tampered = Envelope.decode(
      local.encode().replaceFirst('Oak Street Rentals', 'Someone Else'),
    );
    expect(
      () => Envelope.mergeReturned(local: local, returned: tampered),
      throwsEnvelope(EnvelopeError.contentMismatch),
    );
    final other = Envelope.decode(local.encode().replaceAll('env-1', 'env-2'));
    expect(
      () => Envelope.mergeReturned(local: local, returned: other),
      throwsEnvelope(EnvelopeError.contentMismatch),
    );
  });

  test('steps out of order are refused', () async {
    final (d, code) = await draft();
    expect(
      () => d.complete(canonicalCode: code, now: t0),
      throwsEnvelope(EnvelopeError.wrongState),
    );
    final s = d.senderSigned(contentAfter: digest('a'), now: t0);
    expect(
      () => s.senderSigned(contentAfter: digest('a'), now: t0),
      throwsEnvelope(EnvelopeError.wrongState),
    );
  });

  test('draft validation', () async {
    final access = await AccessVerifier.create('K7QM4XD29P', kdf,
        iterations: 1000);
    Envelope make(List<EnvelopeField> f, {Party r = recipient}) =>
        Envelope.draft(
          id: 'x',
          tag: 'T',
          title: 't',
          now: t0,
          sender: sender,
          recipient: r,
          fields: f,
          access: access,
        );
    expect(() => make([field('a', 'p2', 'text')]),
        throwsEnvelope(EnvelopeError.recipientCannotSign));
    expect(() => make([field('a', 'p9', 'signature')]),
        throwsEnvelope(EnvelopeError.unknownParty));
    expect(
      () => make([field('a', 'p2', 'signature')],
          r: const Party(id: 'p1', role: PartyRole.recipient, name: 'x')),
      throwsEnvelope(EnvelopeError.invalidParties),
    );
  });

  test('decode errors are typed', () async {
    final (d, _) = await draft();
    final json = d.encode();
    expect(() => Envelope.decode('nope'),
        throwsEnvelope(EnvelopeError.malformed));
    expect(() => Envelope.decode(json.replaceFirst('"version":1', '"version":2')),
        throwsEnvelope(EnvelopeError.unsupportedVersion));
    expect(() => Envelope.decode(json.replaceFirst('"title":', '"titel":')),
        throwsEnvelope(EnvelopeError.malformed));
    expect(
      () => Envelope.decode(json.replaceFirst('"iterations":1000', '"iterations":1')),
      throwsEnvelope(EnvelopeError.malformed),
    );
  });
}
