# Two-party signing with signer ID — plan

Status: **in progress** on `feature/agreements` (from 2026-10-09). Packaging
is still open: inside Scan Sign Send or a separate "Agreements"-type app in a
monorepo. The envelope core is built to work either way (§7). §2 pricing
assumes the in-app tier and changes if it becomes a separate app.

## 1. Goal

Let one person (the **sender**, e.g. a property manager) send a form to one
other person (the **recipient**, e.g. a tenant), who fills their fields, states
who they are, optionally backs that statement with a government ID, signs, and
sends it back — with no server and no accounts.

Target buyer: small property-management firms and independent landlords
(leases, move-in/out inspections, pet addenda, maintenance authorisations).

Out of scope for this release: 3+ signers (later, higher tier), team licences,
selfie / face matching, any network code.

## 2. Pricing and entitlements

| Tier | Includes | New buyer | Upgrade |
|---|---|---|---|
| Full Access *(exists)* | Unlimited scan, fill, press, fillable export | $9.99 | — |
| **Pro Agreements** *(new)* | Full Access + sending two-party envelopes, access code, optional signer ID | $19.99 | $9.99 for Full Access owners |
| **Pro Multi-Party Agreements** *(later)* | + 3 or more signers | $29.99 | $9.99 from Pro Agreements, $19.99 from Full Access |

Tagline (Pro Agreements): "Send agreements and forms for signature, with access
code and optional ID." The "and forms" covers inspection reports and
authorisations, which aren't agreements.

Rules:
- **Recipients never pay.** Opening, filling and signing a received envelope is
  free and does not use the free-tier quota. Only *creating* an envelope needs
  the tier.
- Two new non-consumables on both stores (IDs are permanent — confirm before
  creating them; lowercase for Play):
  - `com.adakventures.scansignsend.pro` — $19.99, includes Full Access
  - `com.adakventures.scansignsend.proupgrade` — $9.99, shown in-app only
    to Full Access owners; grants the same tier if bought any other way
- Regional (PPP) prices follow `store/PRICING.md` §3.
- `IapService` moves from one `isPurchased` flag to an entitlement level
  (`free < fullAccess < pro < proMultiParty`), resolved from every owned
  product on purchase and restore. `FreeUsageService` checks `>= fullAccess`;
  envelope code checks `>= pro`. Nothing new reads `isPurchased` directly.
- **Family Sharing stays off** for every product (the existing `fullaccess` is
  off too). It can never be turned off
  once on, and a six-member family group would cover a small firm's staff.
- Product IDs stay plain (`pro`, later `promultiparty` / upgrade variants) so
  a future rename of the display names doesn't leave them looking wrong.
- Market to small firms, but no tier is *called* "Small Firm" / "Business":
  that implies a team licence, and each purchase covers one Apple / Google
  account.
- Check every translated display name against the store name limits before
  creating the products; "Multi-Party" may need a shorter form in some locales.

## 3. How it works

### 3.1 The envelope travels inside the PDF

The sender exports a fillable PDF with an embedded envelope:

- PDF embedded file `ssse-envelope.json` + a marker in XMP metadata
- Contents: envelope ID, format version, the two parties (name, role, the
  recipient's email and/or mobile number), signing order, field → party map,
  `idRequired` per party, the sender's public key (for the ID copy, §3.4),
  and the audit log
- The first page carries a visible line for people opening it elsewhere:
  "Open this file in Scan Sign Send to sign."

### 3.2 Flow (fixed order: sender → recipient → sender)

1. **Sender** imports/scans the form, assigns each field to *Me* or *Recipient*
   (colour-coded), toggles "Ask recipient for ID", fills and signs their own
   fields, then sends. Their portion is **flattened into the page** at this
   point so the recipient can't alter it; the recipient's fields stay live.
2. **Recipient** opens the PDF from Mail / WhatsApp / Files → app recognises the
   envelope → "Signing as <name>". Only their fields are editable. Then the
   identity statement (§3.3), signature, and share back to the sender.
   Their portion is flattened before sharing.
3. **Sender** opens the returned file → app verifies the hash chain → presses
   the final PDF with the audit page → stored as complete.

If the chain doesn't verify (the file was re-saved in Preview or another
editor), the app says so plainly and won't continue the envelope.

### 3.2a Sending to the recipient's email or number

The sender enters the recipient's email and/or mobile number. The app uses
them to prefill sending; the share sheet itself can't prefill a recipient.

| What | iOS | Android | Logged as |
|---|---|---|---|
| PDF by email | `MFMailComposeViewController`, recipient and attachment prefilled | `ACTION_SEND` with `EXTRA_EMAIL` and the PDF | iOS: "sent" from the composer result. Android: "handed to <app>" (Android doesn't report whether it was sent) |
| Code by SMS | `MFMessageComposeViewController`, number and text prefilled | `ACTION_SENDTO smsto:` with text | as above |
| Code by WhatsApp | `https://wa.me/<number>?text=<code message>` (text only) | same link | "opened WhatsApp to <number>" |
| Anything else | Share sheet fallback | Share sheet fallback | "shared via share sheet" |

- If Mail isn't set up on the iPhone (`canSendMail` is false), fall back to the
  share sheet.
- WhatsApp links can't attach files, which suits the code. A PDF going by
  WhatsApp goes through the share sheet, and the sender picks the chat.
- The audit page shows the address masked (`p•••@gmail.com`,
  `+91 ••••• •4821`), labelled "as entered by the sender".
- The app only hands addresses to the OS composer, so there's still no network
  code and the privacy labels don't change.

### 3.3 Identity statement and ID checks

Before signing, the recipient confirms:

> I, **Priya Raman**, holder of **Passport ••4821** (issued by India), confirm I
> am the person signing this document.

When the sender required ID, the recipient scans it (VisionKit / ML Kit
document scanner) or picks it with the **system photo picker**. Checks run on
the recipient's device; the audit page records which tier was reached:

| Tier | ID types | Check |
|---|---|---|
| Strong | Passports, ID cards and visas with an MRZ | MRZ check digits |
| Strong | US / Canada driving licences | PDF417 barcode (ML Kit barcode scanning) |
| Format | Aadhaar | Verhoeff checksum |
| Format | PAN | Pattern `AAAAA9999A` |
| Basic | Any other government ID | OCR text + name match + unexpired date |

All tiers: expiry check, fuzzy match against the typed full name. A failed
name match blocks signing. The on-device LLM is **not** in this release; checks
are deterministic so every device behaves the same.

No face detection, selfie or biometric matching — that would bring biometric
privacy laws (e.g. Illinois BIPA) and more review scrutiny.

**Aadhaar:** the copy is masked (first 8 digits blacked out) before it is
encrypted, in line with UIDAI's guidance on masked Aadhaar copies.

### 3.4 The ID copy goes only to the sender

- The ID image is encrypted to the sender's public key (from the envelope) and
  embedded in the returned PDF. Only the sender's device can open it.
- The sender's key pair is created on first envelope and kept in the
  Keychain / Android Keystore, device-only. Losing the device loses access to
  past ID copies — said plainly in the UI.
- The sender can view and **delete** stored ID copies per document; the app tells
  them that holding tenant IDs makes them responsible for that data.
- The recipient sees before uploading: "Your ID will be shared with
  <sender> only. Scan Sign Send never receives it."

### 3.5 Access code (sent outside the app)

Shows that whoever signed received a message the sender sent outside the app,
to an address or number the sender chose. This is the same idea as DocuSign's
access code.

- When sending, the app creates a **random** 10-character code (Crockford
  base32, about 45 bits, from the OS secure random generator, shown as
  `K7QM-4XD2-9P`). It must not be derived from the name, file name or date:
  those are written in the PDF, so anyone holding the file could work the code
  out.
- The sender sends the code through the prefilled composer (§3.2a), by a
  different route than the PDF where possible (PDF by email, code by SMS or
  WhatsApp). The route and address go into the audit log; the app keeps the
  code on the sender's device only.
- **Checked on the recipient's device, then confirmed by the sender:**
  - The envelope carries a slow verifier: PBKDF2-HMAC-SHA256 of the code with
    a random salt and 600,000 iterations, using OS crypto. The recipient's app
    checks against it and rejects a wrong code immediately. Each check takes
    about 0.5 s on a phone. Guessing a 45-bit code offline against this would
    take decades per GPU, so storing the verifier in the PDF is safe. **The
    code length is what keeps it safe**: a 6-digit code could be cracked in
    seconds and must never be used.
  - The recipient's app also records
    `HMAC-SHA256(code, envelopeId ‖ recipient name ‖ PDF hash at signing)`.
    The sender's app recomputes it from the code it kept when the file comes
    back. That catches a modified app that skipped the check.
  - The last character is a check symbol, so a typo is flagged before the slow
    check runs.
- The file name may carry a short, public envelope tag
  (`Lease – 12 Oak St – EV7Q3K.pdf`) for people to read. Matching uses the
  envelope ID embedded in the PDF, because messaging apps sometimes rename
  files.
- No screenshots: the app records the code entry itself, which is better
  evidence than a screenshot, and chat screenshots would pull other people's
  messages into the record.
- Audit line: "Access code sent by the sender via WhatsApp to +91 ••••• •4821 on
  7 Oct 2026; entered correctly by the signer at 14:32." The route and address
  are as stated by the sender.
- The access code is on for every envelope. ID (§3.3) is an optional extra on
  top.

### 3.6 Audit page

Extends today's certificate page (`press_service.dart` `_appendCertPage`):
per party — name, role, signed-at, identity statement, access-code result (§3.5), ID summary (type, issuer,
last 4, check tier, SHA-256 of the image), and the hash chain (SHA-256 of the
PDF before/after each step). Wording rules: "ID presented", "checks passed on
the signer's device" — never "identity verified", "notarised" or "legally
binding".

## 4. App Store / Google Play review — risks and what we do

| # | Risk | Source | Mitigation |
|---|---|---|---|
| 1 | Reviewer can't test the recipient side or the ID step (2.1 rejection) | Apple 2.1(a) | Built-in **sample envelope** (Settings → "Try a sample envelope") addressed to the ICAO specimen name; its access code, the specimen ID image and steps in review notes. Reviewer never uses a real ID. |
| 2 | Apps needing sensitive user info must come from a legal entity | Apple 5.1.1(ix) | Already submitted by ADAK Ventures LLC. No action. |
| 3 | IAP features not disclosed in listing | Apple 2.3.2 | Description and screenshots say which features need which purchase; recipients sign free. |
| 4 | Overclaiming (legally binding, verified identity, DocuSign alternative in keywords) | Apple 2.3.1 / 2.3.7, Play Metadata & Misrepresentation | No legal-validity or verification claims; no competitor names in keywords/title/subtitle. Comparison only in plain description text, if at all. |
| 5 | Restore must cover all products | Apple 3.1.1 | Restore resolves the highest tier from all owned products. |
| 6 | Broad photo permission rejected | Play Photo & Video Permissions policy | Keep `READ_MEDIA_*` stripped (manifest already does); use the system photo picker / document scanner only. |
| 7 | Privacy labels / Data safety | Apple App Privacy, Play Data safety | Stay "Data Not Collected" / "No data collected": the app has no network code; files leave only through the OS share sheet at the user's request and the developer can't access them. Add a prominent in-app disclosure before the ID step anyway. Revisit if any network code is ever added. |
| 8 | Encryption export compliance | Apple export compliance; `ITSAppUsesNonExemptEncryption = false` today | Do the ID encryption with **OS crypto** (CryptoKit on iOS, Keystore/Tink on Android) via a platform channel, not a Dart crypto package, so the exempt "standard OS encryption" answer still holds. Re-answer the questionnaire in App Store Connect for this version. |
| 9 | App can't receive PDFs from Mail/WhatsApp | — (functional) | Add `CFBundleDocumentTypes` (PDF) + `LSSupportsOpeningDocumentsInPlace` on iOS; `VIEW`/`SEND` intent filters for `application/pdf` on Android. Neither exists today. |
| 10 | New IAPs must ship with a binary | App Store Connect | Create both products, add review screenshots, attach them to the version submission. |
| 11 | Separate "Business" app to allow volume purchasing | Apple 4.3 (spam / duplicate apps) | Don't. IAPs can't be bought through Apple Business Manager; firms buy per account. Accept this until there's demand for a team option. |
| 12 | Play Billing Library deadline | Play | `in_app_purchase_android` 0.5.0 uses Billing 8.0.0 — fine until 2027-08-31. |
| 13 | Privacy policy out of date | Apple 5.1.1(i), Play User Data policy | Update `store/PRIVACY_POLICY.md` (and the website copy) for ID handling, the sender-only encrypted copy, and deletion. |

### Wording rules (store listing, in-app text, audit page, all 7 locales)

| Never say | Say instead |
|---|---|
| legally binding, court-admissible, notarised | send agreements for signature |
| verified identity, ID verification, KYC | ID presented; checks passed on the signer's device |
| eIDAS / ESIGN / IT Act compliant | (nothing; no compliance claims) |
| secure signature, tamper-proof | tamper-evident audit trail |
| DocuSign / Adobe Sign alternative (anywhere in metadata) | works offline, nothing uploaded, no subscription |

- Translations follow the English meaning, never a stronger word (e.g. no
  "vérifié", "verificado", "सत्यापित" for ID checks). Review every translated
  string for this before release.
- The App Review notes describe each new feature step by step (2.3.1(a)).

Legal (not store) items to check with a lawyer before marketing to US property
managers: state laws on collecting/retaining ID data (e.g. California's limits
on scanning driver's licences), India's DPDP Act for Indian landlords. The app
stores nothing centrally, which helps, but the sender becomes the data holder.

## 5. Build phases

1. **Plumbing** — entitlement levels in `IapService`; PDF open-in handlers;
   envelope format (embed/read in Syncfusion); schema: `Parties`,
   `AuditEvents`, `Fields.partyId`, `Documents.envelopeId`.
2. **Envelope flow** — party assignment in the editor, `signatureBlock` field
   (signature + printed name + date), partial flatten per party, recipient
   "signing as" mode, access code, hash chain, audit page.
3. **Identity** — statement, ID capture, tiered checks, Aadhaar masking,
   OS-crypto encryption to sender, ID copy viewer/delete.
4. **Store** — products in both consoles, sample envelope + specimen ID,
   listing copy (7 locales), privacy policy, review notes.

## 6. Decisions

- Tier names, prices and product IDs: §2.
- Family Sharing: off for every product, including the existing `fullaccess`.
- Sender enters the recipient's email and/or mobile number; used to prefill
  sending (§3.2a).

## 7. Implementation notes

**Packaging-neutral core.** `packages/agreements_core` is pure Dart (only
`crypto`): envelope model and JSON, access codes, verifier, code proof, signing
flow, masking. The app depends on it by path; a separate app would do the same
from a monorepo. No user-facing text: failures are `EnvelopeException` codes.

**Tamper evidence without circularity.** The envelope can't hash the file
that contains it. Instead `Envelope.content` is `{length, sha256}` of the
*content* PDF, and `EnvelopePdf.seal` (`lib/core/services/envelope_pdf.dart`)
adds the envelope as a PDF incremental update, which only appends. On open,
the file's first `length` bytes must hash to `sha256`; a full re-save in any
other editor rewrites them and is reported as modified. Each party's flatten
step loads the previous content and saves incrementally too, so every earlier
version stays an exact prefix of the final file. (Appended updates can still
paint over earlier content, so this is tamper-*evident*, not tamper-proof.)

**What travels and what stays.** The PDF carries what's known when it's
sealed: parties, field→party map, verifier, content digest, log. The sender's
send receipts ("sent by SMS to …") stay in the sender's local copy and are
merged in by `Envelope.mergeReturned` when the file comes back. The merge
refuses a returned copy whose fixed fields or earlier log entries changed.

**Code check.** The access code is 9 random Crockford base32 symbols plus a
Luhn mod 32 check symbol, which catches every single-symbol typo and 99.8% of
neighbour swaps (measured). `AccessVerifier` (PBKDF2-SHA256, 600k iterations) runs
through a `CodeKdf` the app supplies. Still to build: the OS-backed one
(CommonCrypto / javax.crypto over a platform channel); Dart's is too slow at
600k. Envelopes with fewer than 1,000 iterations or a short salt are rejected.
The recipient can only sign after `codeWasAccepted`. The sender's `complete`
recomputes the HMAC proof from the code it kept.

**Next.** Schema (`Envelopes` table holding the sender's local envelope JSON +
code, `Fields.partyId`, `Documents.envelopeId`), OS `CodeKdf` channel, party
assignment in the field editor, sender seal/send flow, recipient "signing as"
mode via the open-in handler (`EnvelopePdf.hasEnvelope` routes it), audit
page.
