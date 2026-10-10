# Field labels and PreFill — plan

Status: **draft for review** (2026-10-10). Nothing here is built yet.
Release 1.1.0 (13) is uploaded to TestFlight and Play internal and held: no
store submission until Arun decides what ships in it.

## 1. Goal

Make filling a form fast and obvious:

- **A. Readable labels on forms that already have fields (AcroForm).** Today
  an imported IRS W-4 shows `topmostSubform[0].Page1[0].Step1a[0].f1_01[0]`
  as the field's name.
- **B. Labels with context.** A blank after "residing / at" is labelled "at".
  It should read "residing at".
- **C. PreFill.** The user saves their own details once, on the device.
  Matching fields on any form fill with one tap.

Out of scope: storing ID numbers (SSN, Aadhaar, passport, tax IDs), more
than one profile ("me" and "my company"), and syncing.

## 2. Pricing and entitlements

PreFill is free for everyone, including the free tier. It makes the first
two free documents feel good, and that sells Unlimited. The free tier
already counts *finished* documents, not filled fields, so nothing changes
there. No new products.

**Name:** "PreFill" is the button ("Fill from My Details"), and "My Details"
is the saved data. Settings already calls this section "My Profile"; rename
it to "My Details" in all 7 locales. "Profile" suggests an account, and the
app has none.

## 3. How it works

### What exists today (read from code)

- `UserProfile` (drift) already stores fullName, email, phone, address,
  city, state, zip and company. They're edited in Settings → My Profile.
  The privacy policy already covers "profile details" stored only on the
  device.
- Fill mode has a chip bar (`_SmartFillBar`, `fill_mode_screen.dart`). It
  has two bugs. Tapping "Name" puts the name into **the first empty text
  field, whatever its label**: an address box, a ZIP box. And city, state
  and ZIP are saved but never offered.
- AcroForm fields are labelled with the raw field name
  (`import_service.dart:316`). Field detection never runs on these
  documents.

### A. Labels for AcroForm fields

On import, in the existing background parse (`_parseFormFields`), take the
first source that gives a usable label:

1. **Tooltip** (`/TU`, Syncfusion `PdfField.tooltip`). Well-made forms have
   one. The current W-4 does not.
2. **Page text near the field**, from Syncfusion's text extractor (a text
   layer, so no OCR):
   - text field: the caption **above** it inside the same column. It may
     wrap onto a second line ("First date of / employment").
   - otherwise, the text to its **left** on the same line.
   - checkbox/radio: the text to its **right** ("Single or Married filing
     separately").
   - Drop item markers ("(a)", "Step 1:") and a trailing "$". If only an
     item number is left ("3(a)"), that is the label.
3. **Field name, made readable**, only when it's real words
   (`FirstName` → "First name"). Names like `f1_01`, `Text1` and
   `topmostSubform…` are rejected.
4. **Generic**, translated: "Text field 3", "Checkbox 2".

Checked against the real 2026 W-4 (irs.gov): f1_01 → "First name and
middle initial", f1_02 → "Last name", f1_03 → "Address", f1_04 → "City or
town, state, and ZIP code", f1_05 → "Social security number", f1_06 →
"3(a)".

`pdfFieldName` never changes, so Save as Fillable still writes into the
original fields. Already-imported documents are relabelled once, the first
time they open: any AcroForm field whose label still equals its raw name
gets a new one. No schema change.

### B. Tiny labels

In `FieldDetectionEngine._cleanLabel`, also used for A: if the label is only
a short connecting word, prefix the nearest real word before it. That search
skips earlier blanks, numbers and punctuation, and may go back to the end of
the previous line.

| Text on the page | Today | After |
|---|---|---|
| "residing / at ____" | at | residing at |
| "born on ____, at ____" | at | born at |
| "Signed at ____ on ____" | at / on | Signed at / Signed on |

There is one word list per locale: en (at, in, on, of, by, to, for, from),
fr (à, au, en, de, le, du), es (en, a, de, el), pt (em, no, na, de, a) and
hi (में, पर, को, का, की, के). ta and te forms are mostly English. The
existing engine test that expects the label "at" changes to these.

### C. PreFill

**My Details** (Settings), all optional. **Locked 2026-10-10: these 14.**

| Group | Detail | New? | Notes |
|---|---|---|---|
| Name | First name | split from fullName | |
| | Middle name | new | "Middle initial" fields get the first letter |
| | Last name | split from fullName | Existing fullName migrates: last word → last name, the rest → first name (user can correct) |
| Contact | Email | existing | |
| | Phone | existing | |
| Address | Street address (line 1) | existing `address` | |
| | Apt / suite / unit (line 2) | new | |
| | City | existing | |
| | State / Province | existing `state` | Label follows region ("State" in India) |
| | ZIP / PIN / Postal code | existing `zip` | Label follows region |
| | Country | new | |
| Work | Company / Employer | existing | |
| | Job title | new | |
| Personal | Date of birth | new | Written in each form's date style; "Age" fields computed from it |

Full name isn't stored. It's built from first + middle + last for "Full
name", "Name" and "Signature name" fields. One-box fields ("Address", "City
or town, state, and ZIP code") get the parts combined.

Not stored, on purpose: SSN, Aadhaar, PAN, passport, driving licence, tax
IDs and bank details; also marital status, gender, nationality (they
change or depend on the form) and other people's data (emergency contact).
Later, if asked for: preferred name, a second (work/mailing) address. The "Social security number" field on a W-4 stays for the
user to type. These are the details people most fear losing. Holding them
raises the cost of a lost or shared phone, and it invites review scrutiny.

**Matching** (`PrefillMatcher`, pure Dart, unit-tested). It maps a label to
a detail using normalised phrases per locale ("first name", "given name",
"prénom", "nombre", "nome", "नाम" …) and builds composite fields from
several details: "City or town, state, and ZIP code" → "Austin, TX 78701";
"Full name" → first + middle + last. It runs on detected fields and on
AcroForm fields (after A).

When the user picks a detail for a field by hand, the matcher learns that
label → detail pairing on the device, the same way field hints already learn
types.

**Flow**

1. Opening a form in Fill shows a bar: *"Fill 6 fields from My Details"*
   with **[Fill]** and a ✕. Nothing fills until the user taps Fill.
2. Fill writes only into **empty** fields that match. It never overwrites
   anything typed. Filled fields get a subtle "prefilled" tint until edited.
   An **Undo** snackbar removes the fill.
3. Tapping a field opens the text sheet with suggestion chips for that
   field's matched detail first ("First name: Priya"), then the others. This
   replaces the old chip bar's "fill the first empty field" behaviour.
4. With no details saved, the bar says *"Save your details once to fill
   forms faster"* → My Details. It's shown at most once per document and
   never blocks anything. There is no onboarding step and no required
   entry.

**Where it lives:** the app's own database on the device. It is included in
the device backup only if the user switched that on (existing opt-in), and
it's protected by the app lock when enabled. "Delete my details" in
Settings clears every field. Details never go into a PDF unless the user
fills a field with them.

## 4. Store review — risks and mitigations

Verified 2026-10-10 against the live pages:

- Apple App Privacy Details: *"Data that is processed only on device is not
  'collected' and does not need to be disclosed."*
- Google Play Data safety: *"User data accessed by your app that is only
  processed locally on the user's device and not sent off device does not
  need to be disclosed."*
- Apple 5.1.1(v): *"Apps may not require users to enter personal
  information to function, except when directly relevant to the core
  functionality of the app or required by law."*

| # | Risk | Source | Mitigation |
|---|---|---|---|
| 1 | Personal info demanded to use the app | Apple 5.1.1(v) | All details optional. No onboarding gate. The app works fully without them |
| 2 | Privacy label / Data safety out of date | Apple App Privacy; Play Data safety | Nothing leaves the device: answers stay "no data collected". Policy already names "profile details" on device; add a line naming the new details and "Delete my details" |
| 3 | Retention/deletion not explained | Apple 5.1.1(i) | Privacy policy: "Delete my details" in Settings, or delete the app |
| 4 | New feature not described to review | Apple 2.3.1(a) | Review notes: where My Details is, that it's optional and on-device, and how to see PreFill (import the sample form, tap Fill) |
| 5 | Unexpected personal data | Play User Data | The user types their own details for an obvious purpose; no prominent disclosure needed beyond the on-device line on the My Details screen |

**Wording rules** (all locales; translations must not upgrade the claim):

| Never say | Say instead |
|---|---|
| "Secure", "encrypted", "safe" storage | "Saved only on this device" |
| "Auto-fill any form" / "fills forms for you" | "Fill matching fields from My Details" |
| "Profile" / "account" | "My Details" |
| "Never leaves your phone" | "Saved only on this device. Included in your device backup only if you turn it on" |

"Encrypted" is out because the app sets no file-protection class of its own.
It relies on the OS default, so the claim would be a guess.

**For a lawyer:** none new. The app is still not a data holder, since
nothing is transmitted. DPDP / state privacy laws don't apply to data that
the user stores on their own device and that we never receive.

## 5. Build phases

1. **A + B, labels.** Import labeller and tiny-label context, with tests,
   using a generated W-4-like PDF and the real W-4. About 1 day. No schema
   change. Fits a 1.1.0 rebuild (14).
2. **C1, matcher.** `PrefillMatcher` and its tests (phrases × 7 locales,
   composites). No UI.
3. **C2, My Details.** Schema migration (split name/address, country, job
   title, DOB), migration test, Settings screen renamed and expanded,
   "Delete my details", strings in 7 locales.
4. **C3, PreFill UX.** Fill bar, empty-only fill, undo, prefilled tint,
   per-field suggestion chips replacing the old chip bar. Device check on
   both platforms.
5. **Store.** Privacy policy line and website copy, review notes, What's New.
   The store screenshots *should* change: PreFill is worth selling ("Fill
   your details in one tap"). Regenerate the captures and the header/search
   creative with a PreFill shot.

C1–C5 is about 3–4 days, released as **1.2.0**.

## 6. Decisions

1. **1.1.0 contents.** Ship A + B as 1.1.0 (14) and PreFill as 1.2.0? Or
   ship 1.1.0 (13) now, with everything in 1.2.0?
2. **Name.** "My Details" + "Fill from My Details" (renaming "My Profile").
3. ~~Which details~~ **Decided 2026-10-10:** the 14 in §3C, no ID numbers.
4. **Fill on open.** Offer, then fill on tap (recommended). Or fill
   automatically on open.
5. **Store creative.** Add a PreFill screenshot and a header/search line
   for 1.2.0.
