import '../../core/services/on_device_ai_service.dart';
import '../../l10n/app_localizations.dart';

/// What Settings and the Library tip say about how documents are sorted on
/// this phone, and why.
String aiSortMessage(AppLocalizations l10n, OnDeviceAiStatus status) =>
    switch (status) {
      OnDeviceAiStatus.available => l10n.aiSortAvailable,
      OnDeviceAiStatus.deviceNotEligible => l10n.aiSortDeviceNotEligible,
      OnDeviceAiStatus.osTooOld => l10n.aiSortOsTooOld,
      OnDeviceAiStatus.notEnabled => l10n.aiSortNotEnabled,
      OnDeviceAiStatus.notReady => l10n.aiSortNotReady,
      OnDeviceAiStatus.languageUnsupported => l10n.aiSortLanguage,
      OnDeviceAiStatus.unsupported => l10n.aiSortUnsupported,
    };
