# Localized store listings

One file per locale. Each contains every field both consoles ask for, already
within the character limits each store enforces.

| Field | App Store | Play |
|---|---|---|
| App name | 30 | 30 |
| Subtitle | 30 | — |
| Short description | — | 80 |
| Promotional text | 170 | — |
| Keywords | 100 | — |
| Full description | 4000 | 4000 |

**These limits are counted in characters, not bytes**, so Devanagari, Tamil and
Telugu are not penalised for their UTF-8 size — but they *are* long in
characters, which is why several subtitles here are terser than the English.

**The one exception is App Store keywords: 100 UTF-8 *bytes*.** A Tamil or
Hindi character costs ~3 bytes, so an Indic keyword list holds roughly a third
as many native-script words. Spend them on the native terms; Latin terms that
are already in the app name ("scan", "sign") are indexed anyway.

Run `python3 store/listings/check_limits.py` after any edit; it fails loudly
rather than letting a console reject the upload.

## Filling the consoles

- **App Store Connect** → App Information → *Localizations* (name, subtitle,
  privacy URL) and the version page → *Localizations* (promo text, description,
  keywords, What's New).
- **Play Console** → Grow → Store presence → Main store listing → the language
  selector at the top → add each language.

The product name "Scan Sign Send" is never translated in any locale — it is the
brand and the primary search term.

Keywords are **not** translations of the English list. They are the terms
people actually search in that language and script, including Latin-script
spellings that Indian users type more often than the native script.
