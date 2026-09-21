import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// `context.l10n.someKey` — shorter than `AppLocalizations.of(context)` at every
/// call site, and it keeps the import list in each screen down to one line.
extension L10nExt on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The delegates and locales every [WidgetsApp] in this app must pass.
///
/// There are four separate app widgets (splash, onboarding, the router app and
/// the lock screen), and a missing delegate on any one of them shows that
/// surface in English regardless of device language — so they all read from
/// here rather than repeating the list.
const kLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

List<Locale> get kSupportedLocales => AppLocalizations.supportedLocales;
