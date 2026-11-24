import '../../l10n/app_localizations.dart';

/// Whole minutes for a rough time shown to the user, or null when it is
/// under a minute.
int? roughMinutes(Duration d) =>
    d.inSeconds < 50 ? null : (d.inSeconds / 60).round().clamp(1, 999);

/// "About N minutes left" or "Less than a minute left".
String timeLeftText(AppLocalizations l10n, Duration left) =>
    switch (roughMinutes(left)) {
      final m? => l10n.progressMinutesLeft(m),
      null => l10n.progressUnderMinuteLeft,
    };
