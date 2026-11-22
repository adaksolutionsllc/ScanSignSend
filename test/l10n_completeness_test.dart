// Guards the translation set.
//
// A missing key doesn't fail the build — gen-l10n silently falls back to
// English — so a half-translated screen ships looking fine in review and broken
// to the people it was translated for. These tests make the gap loud instead.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/l10n/app_localizations.dart';

/// Every locale shipped in lib/l10n. Keep in sync with CFBundleLocalizations
/// in ios/Runner/Info.plist.
const _expectedLocales = {'en', 'fr', 'es', 'pt', 'hi', 'ta', 'te'};

Map<String, dynamic> _readArb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Message keys only — `@@locale` and the `@key` metadata entries aren't
/// translatable strings.
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Argument names a message declares: a plain `{name}` slot, or the argument
/// of an ICU `{name, plural, ...}` / `{name, select, ...}` construct.
///
/// Matching a bare `{\w+` would also pick up the literal text inside plural
/// branches (`{No fields found}`), so the two forms are matched explicitly.
Set<String> _placeholders(String value) => {
  ...RegExp(r'\{(\w+)\}').allMatches(value).map((m) => m.group(1)!),
  ...RegExp(
    r'\{(\w+),\s*(?:plural|select)',
  ).allMatches(value).map((m) => m.group(1)!),
};

void main() {
  late Map<String, dynamic> english;
  late Set<String> englishKeys;

  setUpAll(() {
    english = _readArb('en');
    englishKeys = _messageKeys(english);
  });

  test('every expected locale has an .arb file and nothing extra', () {
    final onDisk = Directory('lib/l10n')
        .listSync()
        .map((e) => e.path)
        .where((p) => p.endsWith('.arb'))
        .map((p) => RegExp(r'app_(\w+)\.arb$').firstMatch(p)!.group(1)!)
        .toSet();
    expect(onDisk, _expectedLocales);
  });

  test('AppLocalizations exposes exactly the shipped locales', () {
    final generated = AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .toSet();
    expect(generated, _expectedLocales);
  });

  test('no locale is missing a key or carries a stale one', () {
    for (final locale in _expectedLocales.where((l) => l != 'en')) {
      final keys = _messageKeys(_readArb(locale));
      expect(
        englishKeys.difference(keys),
        isEmpty,
        reason:
            '$locale is missing keys — those screens would silently '
            'fall back to English',
      );
      expect(
        keys.difference(englishKeys),
        isEmpty,
        reason:
            '$locale has keys English no longer defines (stale after a '
            'rename?)',
      );
    }
  });

  test('translations keep every placeholder the English message declares', () {
    for (final locale in _expectedLocales.where((l) => l != 'en')) {
      final arb = _readArb(locale);
      for (final key in englishKeys) {
        final expected = _placeholders(english[key] as String);
        if (expected.isEmpty) continue;
        final actual = _placeholders(arb[key] as String);
        // A dropped placeholder means the value never reaches the user; an
        // invented one throws at format time.
        expect(
          actual,
          containsAll(expected),
          reason: '$locale/$key dropped a placeholder',
        );
      }
    }
  });

  test('no translation was left as the untouched English string', () {
    // Matching English is only acceptable where the word genuinely is the same
    // in that language. Listing these per-locale rather than globally keeps the
    // check sharp: a cognate in French must not excuse untranslated Tamil.
    const cognates = <String, Set<String>>{
      // The product name is never translated.
      'fr': {
        'certDocument',
        'captureDefaultDocumentName',
        'documentFallbackTitle',
        'detectBadgeDate',
        'detectFieldType',
        'fieldTypeDate',
        'fieldTypeSignature',
        'filterOriginal',
        'fieldTypeRadioShort',
        'settingsSectionSignatures',
        'searchPageCount',
        'extractedName',
        'textPageN',
        'sendFormat',
        'sendFormatImages',
        'receiptDate',
        'receiptTotal',
        'receiptDocument',
      },
      'es': {
        'filterOriginal',
        'statusEditable',
        'myDetailsGroupPersonal',
        'receiptTotal',
      },
      'pt': {'filterOriginal', 'receiptTotal'},
      'hi': {},
      'ta': {},
      'te': {},
    };
    for (final locale in _expectedLocales.where((l) => l != 'en')) {
      final arb = _readArb(locale);
      // autoDocumentTitle and sendSizeChange are only placeholders and a
      // dash or arrow, no words. PDF and Word are names.
      final allowed = {
        'appTitle',
        'autoDocumentTitle',
        'sendSizeChange',
        'sendFormatPdf',
        'sendFormatWord',
        ...?cognates[locale],
      };
      final untranslated =
          englishKeys
              .where((k) => !allowed.contains(k))
              .where((k) => arb[k] == english[k])
              .toList()
            ..sort();
      expect(
        untranslated,
        isEmpty,
        reason: '$locale still holds the English text for these keys',
      );
    }
  });

  test('every Siri phrase and intent title has its English key', () {
    // AppShortcuts.swift's literals are the keys iOS looks up; a changed
    // phrase with a stale key would show in English in every language.
    final swift = File('ios/Runner/AppShortcuts.swift').readAsStringSync();
    final phrases = {
      for (final m in RegExp(
        r'^\s*"([^"]*\\\(\.applicationName\)[^"]*)",?$',
        multiLine: true,
      ).allMatches(swift))
        m.group(1)!.replaceAll(r'\(.applicationName)', r'${applicationName}'),
    };
    final titles = {
      for (final m in RegExp(
        r'static var title: LocalizedStringResource = "([^"]+)"',
      ).allMatches(swift))
        m.group(1)!,
    };
    expect(phrases, hasLength(5));
    expect(titles, hasLength(3));
    expect(
      _strings('ios/Runner/en.lproj/AppShortcuts.strings').keys.toSet(),
      phrases,
    );
    expect(
      _strings('ios/Runner/en.lproj/Localizable.strings').keys.toSet(),
      titles,
    );
  });

  test('every locale translates the iOS permission prompts', () {
    // iOS reads these from <locale>.lproj/InfoPlist.strings, outside gen-l10n,
    // so a missing file shows the camera / Face ID prompt in English.
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final usageKeys = RegExp(
      r'<key>(NS\w+UsageDescription)</key>',
    ).allMatches(plist).map((m) => m.group(1)!).toSet();
    expect(usageKeys, isNotEmpty);
    final english = File(
      'ios/Runner/en.lproj/InfoPlist.strings',
    ).readAsStringSync();
    for (final locale in _expectedLocales) {
      final strings = File(
        'ios/Runner/$locale.lproj/InfoPlist.strings',
      ).readAsStringSync();
      final entries = {
        for (final m in RegExp(r'"(\w+)"\s*=\s*"(.*)";').allMatches(strings))
          m.group(1)!: m.group(2)!,
      };
      expect(
        entries.keys.toSet(),
        usageKeys,
        reason: '$locale InfoPlist.strings is out of sync with Info.plist',
      );
      // Native text outside gen-l10n: the Share Extension (Photos → Share),
      // and Siri / Shortcuts (intent titles and phrases).
      for (final file in _nativeStrings) {
        final strings = _strings(file.replaceAll('<l>', locale));
        final english = _strings(file.replaceAll('<l>', 'en'));
        expect(
          strings.keys.toSet(),
          english.keys.toSet(),
          reason: '$locale ${file.replaceAll('<l>', locale)} is out of sync',
        );
        if (locale == 'en') continue;
        for (final key in strings.keys) {
          expect(
            strings[key],
            isNot(english[key]),
            reason: '$locale "$key" is still English in $file',
          );
          if (key.contains(r'${applicationName}')) {
            expect(
              strings[key],
              contains(r'${applicationName}'),
              reason: '$locale "$key": a Siri phrase must name the app',
            );
          }
        }
      }
      if (locale == 'en') continue;
      for (final key in usageKeys) {
        expect(
          english.contains('"${entries[key]}"'),
          isFalse,
          reason: '$locale/$key is still the English prompt',
        );
      }
    }
  });
}

/// Native .strings files that must exist in every locale (`<l>`).
const _nativeStrings = [
  'ios/ShareExtension/<l>.lproj/Localizable.strings',
  'ios/Runner/<l>.lproj/Localizable.strings',
  'ios/Runner/<l>.lproj/AppShortcuts.strings',
];

/// The "key" = "value"; pairs of an iOS .strings file.
Map<String, String> _strings(String path) => {
  for (final m in RegExp(
    r'^"([^"]+)"\s*=\s*"(.*)";$',
    multiLine: true,
  ).allMatches(File(path).readAsStringSync()))
    m.group(1)!: m.group(2)!,
};
