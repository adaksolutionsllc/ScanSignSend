# Product context: Scan Sign Send

Read by the shared `feedback-analyst` and `idea-architect` agents
(claude-config/agents/). The Product Inbox pipeline sends only the
"About" section to web research. Everything else stays local.

## About

- Name: Scan Sign Send (store name "Scan Sign Send — Offline PDF").
  Publisher: ADAK Ventures. Category: Productivity.
- What: an offline document scanner and e-signature app. Scan or import a
  form, detect its fields, fill, sign with a finger, flatten to PDF, send.
- Business: free download with a free tier (2 documents of up to 2 pages).
  One-time in-app purchase ($9.99 base, per-country pricing) for unlimited.
- Promise to users: no account, no subscription, no cloud. Documents never
  leave the phone.
- Platforms: iOS and Android. Languages: en, fr, es, pt (Brazil), hi, ta, te.
- Seed competitors: Adobe Fill & Sign, Adobe Scan, CamScanner, Genius Scan,
  SignEasy, Microsoft Lens, Apple Notes scanner with Markup.

## Internal

- Stack: Flutter 3.x, go_router, flutter_riverpod (hand-written providers,
  no codegen), drift (SQLite), syncfusion PDF and signature pad, local_auth,
  google_mlkit_text_recognition, in_app_purchase. See `CLAUDE.md`.
- Product rules a plan must not break:
  - No server, no network calls, no accounts, no analytics, no subscription.
  - Every user-facing string is localized in all 7 languages.
  - Free tier limits and the one-time purchase stay as they are unless the
    owner decides otherwise (`store/PRICING.md`).
- Store documents: `store/STORE_LISTING.md`, `store/SUBMISSION_CHECKLIST.md`,
  `STORE_RELEASE.md`.
- Architecture notes: `docs/.llm_wiki/`.
