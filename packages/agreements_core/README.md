# agreements_core

The envelope layer for two-party signing (`docs/two-party-signing.md`), kept
free of Flutter so it can live in this app or move to a separate one
unchanged.

- `Envelope` — the JSON that rides inside the PDF (`ssse-envelope.json`).
- `AccessCode` — 10-character Crockford base32 codes with a Luhn mod 32 check.
- `AccessVerifier` / `CodeKdf` — slow PBKDF2 verifier stored in the envelope.
  The app supplies an OS-backed `CodeKdf`; `DartPbkdf2Sha256` is for tests.
- `EnvelopeFlow` — sender → recipient → sender transitions, as typed errors.

No user-facing text lives here: failures are `EnvelopeException`s with a code
the app translates.

```bash
dart test        # from this directory
```
