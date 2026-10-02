# UI and Design System

Back to [[Index]] · Related: [[State and Data Flow]] · [[Native Bridges and Plugins]]

## App shell & layout pattern

`lib/main.dart` builds **three different `MaterialApp`s** depending on startup
state, all sharing `AppTheme.light` / `AppTheme.dark`, `ThemeMode.system`,
`kLocalizationsDelegates`, `kSupportedLocales`:

1. Splash `MaterialApp` with a `CircularProgressIndicator` while
   `isOnboardingDone()` resolves.
2. Onboarding `MaterialApp` → `OnboardingScreen(onDone: …)` (not a route).
3. `_MainApp` → `MaterialApp.router(routerConfig: routerProvider)` with
   `builder: (context, child) => AppLockGate(child: child!)`, so the lock
   overlay sits inside `Localizations`/`Directionality`.

Global error UI: `ErrorWidget.builder` returns `_FriendlyErrorWidget`
(localized when possible, English fallback). Uncaught async errors are logged
by `runZonedGuarded`.

Navigation is flat `go_router` (no `ShellRoute`, no nested navigators, no
redirects). Paths and params: see the route table in [[Index]]. Screens are
`Scaffold`-based Material 3 pages under `lib/features/<feature>/presentation/`;
there is no separate domain/data layer per feature — screens call services in
`lib/core/services/` directly.

## Theme & tokens

Defined in `lib/shared/theme/app_theme.dart` (36 lines):

| Token | Value | Notes |
|---|---|---|
| Seed colour | `#1A73E8` | `ColorScheme.fromSeed`, both brightnesses, `useMaterial3: true` |
| AppBar | `centerTitle: false`, `elevation: 0` | both themes |
| Card (light only) | `elevation: 0`, radius 12, 1px `Colors.grey.shade200` border | dark theme has no card override |
| `statusDraft` | `#FFB300` | library badges |
| `statusPressed` | `#2E7D32` | |
| `statusTemplate` | `#1565C0` | |
| `statusFillable` | `#00897B` | |

Field-type colours (`lib/shared/widgets/field_box.dart`): text `#1565C0`,
date `#6A1B9A`, checkbox `#2E7D32`, radio `#00838F`, initials `#E65100`,
signature `#BF360C`.

**Spacing & typography**: no spacing scale or custom `TextTheme` exists.
Widgets use literal `EdgeInsets` (most common: `all(32)`, `all(16)`,
`all(24)`) and `Theme.of(context).textTheme.*` with occasional literal
`fontSize` (10–18). Typography is the Material 3 default with the platform
system font.

**Dark/light**: `ThemeMode.system` only; no in-app toggle. Native splash uses
one dark colour (`#322f3c`) in both modes (`flutter_native_splash` block in
`pubspec.yaml`).

## Shared widgets (`lib/shared/widgets/`)

| Widget | File | Role |
|---|---|---|
| `PageCanvas` | `page_canvas.dart` | Draws one page image and positions field overlays in normalised coordinates |
| `FieldBox` | `field_box.dart` | Draggable/resizable field outline; per-type colour and outline style (gesture test: `test/field_box_gesture_test.dart`) |
| `fieldTypeLabel(...)` | `field_type_labels.dart` | Translated field-type names |
| `PaywallScreen` | `paywall_screen.dart` | Full-screen upsell; live store price only |
| `TextEditDialog` | `text_edit_dialog.dart` | Single-field edit dialog returning trimmed text |
| `sharePdf(...)` | `lib/shared/utils/share_pdf.dart` | Share sheet wrapper (inside `whileExternal`) |

## Localization

- ARB source: `lib/l10n/app_en.arb` (~278 keys), plus `fr`, `es`, `pt`, `hi`,
  `ta`, `te`. Config `l10n.yaml` (`nullable-getter: false`). Generated
  `lib/l10n/app_localizations*.dart` is committed.
- Access: `context.l10n.key` via `lib/core/utils/l10n_ext.dart`.
- Services without `BuildContext` throw typed exceptions (`ImportException`,
  `IapException`, `PressEmptyDocumentException`) or take strings as parameters
  (`PressCertificateStrings`); the lock prompt string is pushed into
  `AppLockNotifier.setAuthReason` from `AppLockGate.build`.
- iOS permission strings: `ios/Runner/<locale>.lproj/InfoPlist.strings`;
  `CFBundleLocalizations` lists all seven.
- Enforcement: `test/l10n_completeness_test.dart` (ARB keys and `.lproj` keys).
- Store listing text per locale: `store/listings/`, length-checked by
  `store/listings/check_limits.py`.

## Heavy assets

| Asset | Location | Use |
|---|---|---|
| Noto Sans Devanagari / Tamil / Telugu (OFL) | `assets/fonts/*.ttf`, licence `assets/fonts/OFL.txt` | Embedded into **fillable** PDF exports for hi/ta/te values (Syncfusion standard fonts are Latin-only) |
| Shaped Indic text | rendered at runtime by `lib/core/services/shaped_text.dart` | Flattened PDFs draw non-Latin-1 values as high-res PNGs because Syncfusion does no complex-script shaping |
| Launcher icon source | `branding/icon_master.png`, `icon_foreground.png`, `icon_background.png` | `dart run flutter_launcher_icons` |
| Icon renderer | `branding/make_icon_3d.py` (`--variant gold --concept scanner --install`) | Procedural 3D icon; `make_brand.py`, `make_icon.py` superseded |
| Splash | `branding/splash_mark.png`, `branding/splash_android12.png` | `dart run flutter_native_splash:create` |
| iOS asset catalog | `ios/Runner/Assets.xcassets/{AppIcon,LaunchBackground,LaunchImage}` | 1024px icon checked by `scripts/release.sh` |
| Store art | `branding/play_feature.png`, `play_store_icon_512.png`, `store_screenshots/` | Store listings |

No Lottie, Rive, or bundled raster images are used inside the app UI; icons are
Material `Icons.*`.

## Technical Debt Observations

- **Hard-coded colours bypass the theme**: the seed `#1A73E8` is repeated in
  `settings_screen.dart` and `paywall_screen.dart`; onboarding and signature
  screens use literal hex colours; `app_theme.dart` card border uses
  `Colors.grey.shade200`. These don't adapt to dark mode.
- **Light/dark theme asymmetry**: `cardTheme` is only set on the light theme.
- **No spacing/typography tokens**: literal `EdgeInsets`/`fontSize` values
  across screens.
- **Three `MaterialApp` instances** in `main.dart` duplicate theme and l10n
  wiring (mitigated by the shared `kLocalizationsDelegates` constant).
- **Large screen files**: `field_detection_screen.dart` (797 lines),
  `library_screen.dart` (672), `fill_mode_screen.dart` (610) mix layout and
  orchestration.
