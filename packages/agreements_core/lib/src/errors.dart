/// Why an envelope operation was refused. The app maps each code to a
/// translated message; nothing here is shown to users directly.
enum EnvelopeError {
  /// The JSON isn't an envelope, or a required key is missing or mistyped.
  malformed,

  /// Written by a newer app version than this one understands.
  unsupportedVersion,

  /// The step isn't allowed in the envelope's current state.
  wrongState,

  /// Parties aren't exactly one sender and one recipient, or ids repeat.
  invalidParties,

  /// A field names a party that isn't on the envelope.
  unknownParty,

  /// The recipient has no signature field to sign.
  recipientCannotSign,

  /// The PDF the step started from isn't the one the envelope describes.
  contentMismatch,

  /// The access-code proof doesn't match the code the sender kept.
  proofMismatch,
}

class EnvelopeException implements Exception {
  const EnvelopeException(this.error, [this.detail]);

  final EnvelopeError error;

  /// For logs only (a key name, a state); never shown to users.
  final String? detail;

  @override
  String toString() =>
      'EnvelopeException(${error.name}${detail == null ? '' : ': $detail'})';
}
