// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'Scan Sign Send';

  @override
  String get actionCancel => 'ரத்து';

  @override
  String get actionSave => 'சேமி';

  @override
  String get actionDelete => 'நீக்கு';

  @override
  String get actionRemove => 'அகற்று';

  @override
  String get actionConfirm => 'உறுதிப்படுத்து';

  @override
  String get actionBack => 'பின்';

  @override
  String get actionSkip => 'தவிர்';

  @override
  String get actionNext => 'அடுத்து';

  @override
  String get actionOpen => 'திற';

  @override
  String get actionEdit => 'திருத்து';

  @override
  String get actionShare => 'பகிர்';

  @override
  String get actionTryAgain => 'மீண்டும் முயற்சி';

  @override
  String get actionClear => 'அழி';

  @override
  String get documentFallbackTitle => 'ஆவணம்';

  @override
  String get errorGenericTitle => 'இங்கே ஏதோ தவறு நேர்ந்தது.';

  @override
  String get errorGenericBody =>
      'பின் சென்று இந்த ஆவணத்தை மீண்டும் திறக்கவும்.';

  @override
  String get lockTitle => 'Scan Sign Send பூட்டப்பட்டுள்ளது';

  @override
  String get lockBody => 'தொடர Face ID அல்லது உங்கள் கைரேகையால் திறக்கவும்.';

  @override
  String get lockUnlock => 'திறக்கவும்';

  @override
  String get onboardScanTitle => 'ஸ்கேன்';

  @override
  String get onboardScanBody =>
      'எந்த காகித ஆவணத்தையும் ஸ்கேன் செய்ய உங்கள் கேமராவைப் பயன்படுத்துங்கள். விளிம்புகள் தானாகக் கண்டறியப்பட்டு படம் சுத்தம் செய்யப்படும்.';

  @override
  String get onboardSignTitle => 'கையொப்பம்';

  @override
  String get onboardSignBody =>
      'புலங்களைத் தட்டி நிரப்புங்கள். விரலால் உங்கள் கையொப்பத்தைச் சேர்க்கவும். உங்கள் தரவு ஒருபோதும் சாதனத்தை விட்டு வெளியேறாது.';

  @override
  String get onboardSendTitle => 'அனுப்பு';

  @override
  String get onboardSendBody =>
      'கையொப்பமிட்ட PDF-ஐ Mail, Messages, AirDrop அல்லது எந்த ஆப் வழியாகவும் பகிரவும். ஒரு முறை கொள்முதல் — எப்போதும் வரம்பற்ற ஆவணங்கள்.';

  @override
  String get onboardGetStarted => 'தொடங்குங்கள்';

  @override
  String get librarySearchHint => 'ஆவணங்களைத் தேடு…';

  @override
  String get libraryTabAll => 'அனைத்தும்';

  @override
  String get libraryTabDraft => 'வரைவு';

  @override
  String get libraryTabCompleted => 'முடிந்தது';

  @override
  String get libraryTabTemplate => 'வார்ப்புரு';

  @override
  String get libraryImportTooltip => 'PDF / படத்தை இறக்குமதி செய்';

  @override
  String get libraryNewScan => 'புதிய ஸ்கேன்';

  @override
  String get libraryRenameTooltip => 'பெயர் மாற்று';

  @override
  String get libraryUseTemplate => 'வார்ப்புருவைப் பயன்படுத்து';

  @override
  String get libraryDeleteTitle => 'ஆவணத்தை நீக்கவா?';

  @override
  String libraryDeleteBody(String title) {
    return '“$title” நீக்கவா? இதைத் திரும்பப் பெற முடியாது.';
  }

  @override
  String get libraryRenameTitle => 'ஆவணத்தின் பெயரை மாற்று';

  @override
  String get libraryDocumentNameHint => 'ஆவணத்தின் பெயர்';

  @override
  String libraryUseTemplateFailed(String error) {
    return 'வார்ப்புருவைப் பயன்படுத்த முடியவில்லை: $error';
  }

  @override
  String get statusCompleted => 'முடிந்தது';

  @override
  String get statusEditable => 'திருத்தக்கூடியது';

  @override
  String get statusTemplate => 'வார்ப்புரு';

  @override
  String get statusDraft => 'வரைவு';

  @override
  String get emptyDraftsTitle => 'வரைவுகள் இல்லை';

  @override
  String get emptyDraftsBody => 'வரைவை உருவாக்க புதிய ஸ்கேனைத் தொடங்குங்கள்.';

  @override
  String get emptyPressedTitle => 'முடிக்கப்பட்ட ஆவணங்கள் இல்லை';

  @override
  String get emptyPressedBody =>
      'ஒரு வரைவை நிரப்பி இறுதி செய்தால் அது இங்கே தோன்றும்.';

  @override
  String get emptyTemplatesTitle => 'இதுவரை வார்ப்புருக்கள் இல்லை';

  @override
  String get emptyTemplatesBody =>
      'ஒரு ஆவணத்தை இறுதி செய்யும்போது, மீண்டும் பயன்படுத்தக்கூடிய\nவார்ப்புரு இங்கே தானாகச் சேமிக்கப்படும்.';

  @override
  String get emptyAllTitle => 'இதுவரை ஆவணங்கள் இல்லை';

  @override
  String get emptyAllBody =>
      'தொடங்க “புதிய ஸ்கேன்” என்பதைத் தட்டவும்.\nஸ்கேன் → கையொப்பம் → அனுப்பு.';

  @override
  String searchNoResults(String query) {
    return '“$query” க்கு முடிவுகள் இல்லை';
  }

  @override
  String get captureTitle => 'ஆவணத்தை ஸ்கேன் செய்';

  @override
  String get captureLaunching => 'ஸ்கேனர் திறக்கிறது…';

  @override
  String get captureSavingPages => 'பக்கங்கள் சேமிக்கப்படுகின்றன…';

  @override
  String get captureImporting => 'இறக்குமதி ஆகிறது…';

  @override
  String captureScanFailed(String error) {
    return 'ஸ்கேன் தோல்வி: $error';
  }

  @override
  String captureImportFailed(String error) {
    return 'இறக்குமதி தோல்வி: $error';
  }

  @override
  String get captureScanWithCamera => 'கேமராவால் ஸ்கேன் செய்';

  @override
  String get captureImportPdfImage => 'PDF / படத்தை இறக்குமதி செய்';

  @override
  String get captureUpTo20Pages => 'ஒரு ஸ்கேனுக்கு 20 பக்கங்கள் வரை';

  @override
  String captureDefaultDocumentName(String date) {
    return 'ஆவணம் $date';
  }

  @override
  String get reviewTitle => 'பக்கங்களைச் சரிபார்';

  @override
  String get reviewSaveOrder => 'வரிசையைச் சேமி';

  @override
  String get reviewNoPagesFound => 'பக்கங்கள் எதுவும் கிடைக்கவில்லை.';

  @override
  String get reviewDetectFields => 'புலங்களைக் கண்டறி →';

  @override
  String reviewRotateFailed(String error) {
    return 'சுழற்ற முடியவில்லை: $error';
  }

  @override
  String get reviewDeletePageTitle => 'பக்கத்தை நீக்கவா?';

  @override
  String reviewDeletePageBody(int number) {
    return 'பக்கம் $number ஐ அகற்றவா?';
  }

  @override
  String reviewPageOf(int current, int total) {
    return 'பக்கம் $current / $total';
  }

  @override
  String get reviewRotateTooltip => '90° சுழற்று';

  @override
  String get reviewDeletePageTooltip => 'பக்கத்தை நீக்கு';

  @override
  String get filterOriginal => 'அசல்';

  @override
  String get filterEnhanced => 'மேம்பட்டது';

  @override
  String get filterBw => 'கருப்பு-வெள்ளை';

  @override
  String get detectTitle => 'புலங்களைக் கண்டறி';

  @override
  String get detectFormFieldsFoundTitle => 'படிவப் புலங்கள் கண்டறியப்பட்டன';

  @override
  String get detectFormFieldsFoundBody =>
      'இந்த PDF-இல் ஏற்கெனவே படிவப் புலங்கள் உள்ளன.\nநீங்களே புலங்களைச் சேர்க்கலாம் அல்லது நேரடியாக நிரப்பத் தொடரலாம்.';

  @override
  String get detectContinueToFill => 'நிரப்பத் தொடரவும்';

  @override
  String get detectConfirmAll => 'அனைத்தையும் உறுதிப்படுத்து';

  @override
  String get detectStarting => 'தொடங்குகிறது…';

  @override
  String get detectReading => 'உங்கள் ஆவணம் படிக்கப்படுகிறது…';

  @override
  String detectAnalysingPage(int current, int total) {
    return 'பக்கம் $current / $total பகுப்பாய்வு…';
  }

  @override
  String get detectUnknownError => 'அறியப்படாத பிழை';

  @override
  String get detectOnDeviceNote =>
      'அனைத்து செயலாக்கமும் உங்கள் சாதனத்திலேயே நடக்கிறது.';

  @override
  String get detectFailed => 'கண்டறிதல் தோல்வி';

  @override
  String get detectNoPages => 'பக்கங்கள் இல்லை.';

  @override
  String get detectSkipToFill => 'நேரடியாக நிரப்ப →';

  @override
  String detectFillFieldsCount(int count) {
    return 'புலங்களை நிரப்பு ($count) →';
  }

  @override
  String get detectBadgeText => 'உரை';

  @override
  String get detectBadgeDate => 'தேதி';

  @override
  String get detectBadgeCheck => 'தேர்வு';

  @override
  String get detectBadgeSign => 'கையொப்பம்';

  @override
  String get detectEditField => 'புலத்தைத் திருத்து';

  @override
  String get detectFieldType => 'வகை';

  @override
  String get detectFieldLabelHint => 'லேபிள் / புலத்தின் பெயர்';

  @override
  String get detectRequiredField => 'கட்டாயப் புலம்';

  @override
  String get detectAddField => 'புலம் சேர்';

  @override
  String detectAddTypedField(String type) {
    return '$type புலம் சேர்';
  }

  @override
  String get fieldTypeText => 'உரை';

  @override
  String get fieldTypeDate => 'தேதி';

  @override
  String get fieldTypeCheckbox => 'தேர்வுப்பெட்டி';

  @override
  String get fieldTypeSignature => 'கையொப்பம்';

  @override
  String get fieldTypeCheckShort => 'தேர்வு';

  @override
  String get fieldTypeSignShort => 'கையொப்பம்';

  @override
  String get fillFallbackTitle => 'ஆவணத்தை நிரப்பு';

  @override
  String get fillEditFields => 'புலங்களைத் திருத்து';

  @override
  String get fillReviewAndFinish => 'சரிபார்த்து முடி';

  @override
  String get fillNoPages => 'இந்த ஆவணத்தில் பக்கங்கள் இல்லை.';

  @override
  String get fillTextFieldFallback => 'உரைப் புலம்';

  @override
  String get fillEnterValueHint => 'மதிப்பை உள்ளிடவும்…';

  @override
  String get fillChipName => 'பெயர்';

  @override
  String get fillChipEmail => 'மின்னஞ்சல்';

  @override
  String get fillChipPhone => 'தொலைபேசி';

  @override
  String get fillChipAddress => 'முகவரி';

  @override
  String get fillChipCompany => 'நிறுவனம்';

  @override
  String get fillChipToday => 'இன்று';

  @override
  String get fillTapToFill => 'நிரப்பத் தட்டவும்…';

  @override
  String get fillTapForDate => 'தேதிக்குத் தட்டவும்…';

  @override
  String get fillTapToCheck => 'தேர்வு செய்யத் தட்டவும்';

  @override
  String get fillTapToSign => 'கையொப்பமிடத் தட்டவும்…';

  @override
  String get fillPdfNotFound => 'PDF கிடைக்கவில்லை';

  @override
  String get fillImageNotFound => 'படம் கிடைக்கவில்லை';

  @override
  String get fillScanOrImport =>
      'புதிய ஆவணத்தை ஸ்கேன் செய்யவும் அல்லது இறக்குமதி செய்யவும்';

  @override
  String get pressTitle => 'சரிபார்த்து முடி';

  @override
  String get pressFieldSummary => 'புலச் சுருக்கம்';

  @override
  String get pressFilled => 'நிரப்பப்பட்டது';

  @override
  String get pressUnfilled => 'நிரப்பப்படவில்லை';

  @override
  String get pressSaveDraft => 'வரைவைச் சேமி';

  @override
  String get pressFlattenAndSign =>
      'தட்டையாக்கி கையொப்பமிடு (ஆவணம் பூட்டப்படும்)';

  @override
  String pressExportFailed(String error) {
    return 'ஏற்றுமதி தோல்வி: $error';
  }

  @override
  String get pressConfirmTitle => 'இந்த ஆவணத்தைத் தட்டையாக்கிப் பூட்டவா?';

  @override
  String get pressConfirmBody =>
      'தட்டையாக்கும்போது உங்கள் உள்ளீடுகள் புதிய PDF-இல் நிரந்தரமாகப் பதிக்கப்படும். அதன் பிறகு உங்களால் கூட அதைத் திருத்த முடியாது.';

  @override
  String get pressConfirmLiveFields =>
      'இந்த ஆவணத்தில் ஊடாடும் படிவப் புலங்கள் உள்ளன. தட்டையாக்கினால் அவை நீக்கப்படும் — அவற்றைத் திருத்தக்கூடியதாக வைக்க “வரைவைச் சேமி” என்பதைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get pressConfirmNote =>
      'குறிப்பு: இங்கே வரையப்படும் கையொப்பம் ஒரு காட்சிக் குறியே தவிர, சான்றளிக்கப்பட்ட மின் கையொப்பம் அல்ல.';

  @override
  String get pressFlattenAndLock => 'தட்டையாக்கிப் பூட்டு';

  @override
  String pressFailed(String error) {
    return 'செயல்முறை தோல்வி: $error';
  }

  @override
  String get pressWorking => 'செயல்படுகிறது…';

  @override
  String get pressNotFilled => 'நிரப்பப்படவில்லை';

  @override
  String get pressChecked => 'தேர்வு செய்யப்பட்டது ✓';

  @override
  String get pressUnchecked => 'தேர்வு செய்யப்படவில்லை';

  @override
  String get pressSignatureCaptured => 'கையொப்பம் பதிவாகியது';

  @override
  String get signTitle => 'இங்கே கையொப்பமிடுங்கள்';

  @override
  String get signSwitchInk => 'மை நிறத்தை மாற்று';

  @override
  String get signSaveAsMine => 'என் கையொப்பமாகச் சேமி';

  @override
  String get signReuseSubtitle => 'எதிர்கால ஆவணங்களில் மீண்டும் பயன்படுத்து';

  @override
  String get signSaving => 'சேமிக்கிறது…';

  @override
  String get signUseThis => 'இந்தக் கையொப்பத்தைப் பயன்படுத்து';

  @override
  String get signDrawFirst => 'முதலில் உங்கள் கையொப்பத்தை வரையவும்.';

  @override
  String get signDefaultLabel => 'என் கையொப்பம்';

  @override
  String signSaveFailed(String error) {
    return 'கையொப்பத்தைச் சேமிக்க முடியவில்லை: $error';
  }

  @override
  String get signaturesTitle => 'சேமித்த கையொப்பங்கள்';

  @override
  String get signaturesEmpty => 'இதுவரை கையொப்பம் சேமிக்கப்படவில்லை';

  @override
  String get signaturesAdd => 'கையொப்பம் சேர்';

  @override
  String get signaturesDefaultBadge => 'இயல்புநிலை';

  @override
  String get signaturesSetDefault => 'இயல்புநிலையாக அமை';

  @override
  String get signaturesDeleteTitle => 'கையொப்பத்தை நீக்கவா?';

  @override
  String signaturesDeleteBody(String label) {
    return '“$label” நீக்கவா?';
  }

  @override
  String get sendTitle => 'ஆவணத்தை அனுப்பு';

  @override
  String get sendBackToLibrary => 'நூலகத்திற்குத் திரும்பு';

  @override
  String get sendDocumentSent => 'ஆவணம் அனுப்பப்பட்டது!';

  @override
  String get sendReadyToSend => 'அனுப்பத் தயார்';

  @override
  String get sendSharedBody => 'இறுதி PDF பகிரப்பட்டது.';

  @override
  String get sendReadyBody =>
      'உங்கள் இறுதி PDF-ஐ Mail, Messages, AirDrop அல்லது எந்த ஆப் வழியாகவும் பகிரவும்.';

  @override
  String get sendOpeningShareSheet => 'பகிர்வுத் திரை திறக்கிறது…';

  @override
  String get sendSharePressed => 'இறுதி ஆவணத்தைப் பகிர்';

  @override
  String get sendPreviewDocument => 'ஆவணத்தை முன்னோட்டமிடு';

  @override
  String get sendShareAgain => 'மீண்டும் பகிர்';

  @override
  String get sendNotYetPressed => 'ஆவணம் இன்னும் இறுதி செய்யப்படவில்லை.';

  @override
  String get sendPressedPdfNotFound => 'இறுதி PDF கோப்பு கிடைக்கவில்லை.';

  @override
  String get sendShareMessage => 'Scan Sign Send மூலம் கையொப்பமிடப்பட்டது';

  @override
  String sendShareFailed(String error) {
    return 'பகிர்வு தோல்வி: $error';
  }

  @override
  String get viewerPdfNotFound => 'PDF கோப்பு கிடைக்கவில்லை.';

  @override
  String get viewerSearchHint => 'ஆவணத்தில் தேடு…';

  @override
  String get viewerSearchTooltip => 'தேடு';

  @override
  String get viewerNoExportedPdf => 'பார்க்க ஏற்றுமதி செய்த PDF இன்னும் இல்லை';

  @override
  String get viewerNoExportedPdfBody =>
      'இந்த ஆவணத்தை நிரப்பி ஏற்றுமதி செய்யுங்கள் (வரைவு அல்லது தட்டையானது), பிறகு அது இங்கே தோன்றும்.';

  @override
  String get settingsTitle => 'அமைப்புகள்';

  @override
  String get settingsSectionProfile => 'என் சுயவிவரம்';

  @override
  String get settingsSectionSignatures => 'கையொப்பங்கள்';

  @override
  String get settingsSectionSecurity => 'பாதுகாப்பு';

  @override
  String get settingsSectionAi => 'AI கண்டறிதல் (v1.1)';

  @override
  String get settingsSectionPurchase => 'கொள்முதல்';

  @override
  String get settingsFullName => 'முழுப் பெயர்';

  @override
  String get settingsEmail => 'மின்னஞ்சல்';

  @override
  String get settingsPhone => 'தொலைபேசி';

  @override
  String get settingsAddress => 'முகவரி';

  @override
  String get settingsCity => 'நகரம்';

  @override
  String get settingsState => 'மாநிலம்';

  @override
  String get settingsZip => 'அஞ்சல் குறியீடு';

  @override
  String get settingsCompany => 'நிறுவனம்';

  @override
  String get settingsManageSignatures => 'கையொப்பங்களை நிர்வகி';

  @override
  String get settingsBiometricLock => 'பயோமெட்ரிக் ஆப் பூட்டு';

  @override
  String get settingsBiometricLockSubtitle =>
      'திறக்கும்போது Face ID / கைரேகை கேட்கவும்';

  @override
  String get settingsNoBiometrics =>
      'இந்தச் சாதனத்தில் பயோமெட்ரிக் பதிவு செய்யப்படவில்லை. முதலில் Face ID / கைரேகையை அமைக்கவும்.';

  @override
  String get settingsAiDetection => 'மேம்பட்ட AI கண்டறிதல்';

  @override
  String get settingsAiDetectionSubtitle =>
      'புலங்களைச் சிறப்பாக அறிய சாதனத்திலேயே ஒரு மாதிரியைப் பயன்படுத்துகிறது';

  @override
  String get settingsUnlockFullAccess => 'முழு அணுகலைத் திற';

  @override
  String get settingsUnlockSubtitle => 'ஒரு முறை கொள்முதல் — விலையைப் பார்க்க';

  @override
  String get settingsRestorePurchase => 'கொள்முதலை மீட்டமை';

  @override
  String get settingsFullAccessUnlocked => 'முழு அணுகல் திறக்கப்பட்டது';

  @override
  String get settingsThankYou => 'உங்கள் கொள்முதலுக்கு நன்றி!';

  @override
  String get settingsCheckingPurchases =>
      'முந்தைய கொள்முதல்கள் சரிபார்க்கப்படுகின்றன…';

  @override
  String get settingsRestored => 'முழு அணுகல் மீட்டமைக்கப்பட்டது. நன்றி!';

  @override
  String get settingsNoPreviousPurchase =>
      'இந்தக் கணக்கில் முந்தைய கொள்முதல் எதுவும் இல்லை.';

  @override
  String settingsRestoreFailed(String error) {
    return 'மீட்டமைப்பு தோல்வி: $error';
  }

  @override
  String get settingsTapToSet => 'அமைக்கத் தட்டவும்';

  @override
  String settingsEditLabel(String label) {
    return '$label திருத்து';
  }

  @override
  String get paywallTitle => 'முழு அணுகலைத் திற';

  @override
  String get paywallHeadline => 'Scan Sign Send — முழு அணுகல்';

  @override
  String get paywallSubhead => 'ஒரு முறை கொள்முதல். சந்தா இல்லை. கணக்கு இல்லை.';

  @override
  String get paywallBenefitUnlimited => 'வரம்பற்ற ஆவணங்கள்';

  @override
  String get paywallBenefitTemplates =>
      'மீண்டும் பயன்படுத்தக்கூடிய வார்ப்புருக்கள்';

  @override
  String get paywallBenefitSignatures => 'பல சேமித்த கையொப்பங்கள்';

  @override
  String get paywallBenefitAutofill => 'சுயவிவரத் தானியங்கி நிரப்புதல்';

  @override
  String get paywallBenefitLock => 'பயோமெட்ரிக் ஆப் பூட்டு';

  @override
  String get paywallBenefitOffline =>
      'எப்போதும் ஆஃப்லைன் — உங்கள் தரவு சாதனத்திலேயே இருக்கும்';

  @override
  String paywallUnlockForPrice(String price) {
    return 'திற — $price';
  }

  @override
  String get paywallRestore => 'கொள்முதலை மீட்டமை';

  @override
  String get paywallPaymentDisclosure =>
      'உறுதிப்படுத்தும்போது உங்கள் App Store / Play கணக்கிலிருந்து கட்டணம் பிடிக்கப்படும்.';

  @override
  String get paywallNoPreviousPurchase =>
      'இந்தக் கணக்கில் முந்தைய கொள்முதல் எதுவும் இல்லை.';

  @override
  String get dateFormatShort => 'd MMM yyyy';

  @override
  String get dateFormatInput => 'dd/MM/yyyy';

  @override
  String get biometricReason => 'Scan Sign Send ஐத் திறக்கவும்';

  @override
  String get certTitle => 'கையொப்பச் சான்றிதழ்';

  @override
  String get certDocument => 'ஆவணம்';

  @override
  String get certSignedOn => 'கையொப்பமிட்ட நாள்';

  @override
  String get certMethod => 'முறை';

  @override
  String get certMethodValue => 'சாதனத்தில் (Scan Sign Send)';

  @override
  String get certNote => 'குறிப்பு';

  @override
  String get certNoteValue =>
      'கையொப்பங்கள் உள்ளூரில் பதிவு செய்யப்பட்டன. கிளவுட் செயலாக்கம் இல்லை.';

  @override
  String get certDateFormat => 'd MMMM yyyy — h:mm a';

  @override
  String get importErrorUnreadable =>
      'இந்த PDF-ஐத் திறக்க முடியவில்லை. இது கடவுச்சொல்லால் பாதுகாக்கப்பட்டிருக்கலாம் அல்லது சேதமடைந்திருக்கலாம்.';

  @override
  String get importErrorNoPages => 'இந்த PDF-இல் பக்கங்கள் இல்லை.';

  @override
  String get pressErrorNoPages => 'இந்த ஆவணத்தில் இறுதி செய்ய பக்கங்கள் இல்லை.';

  @override
  String get exportErrorNoPages =>
      'இந்த ஆவணத்தில் ஏற்றுமதி செய்ய பக்கங்கள் இல்லை.';

  @override
  String get iapUnavailable =>
      'இந்தச் சாதனத்தில் ஆப்-உள் கொள்முதல் கிடைக்கவில்லை.';

  @override
  String get iapProductNotFound => 'ஸ்டோரில் தயாரிப்பு கிடைக்கவில்லை.';

  @override
  String detectFieldsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count புலங்கள் கிடைத்தன',
      one: '1 புலம் கிடைத்தது',
      zero: 'புலங்கள் எதுவும் கிடைக்கவில்லை',
    );
    return '$_temp0';
  }

  @override
  String detectFillFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count புலங்களை நிரப்பு →',
      one: '1 புலத்தை நிரப்பு →',
    );
    return '$_temp0';
  }

  @override
  String get detectPinchHint =>
      'புலத்தைச் சேர்க்க கீழே உள்ள கருவியைத் தட்டவும் · தேர்ந்தெடுக்க புலத்தைத் தட்டவும்';

  @override
  String get importErrorUnreadableImage =>
      'இந்தப் படத்தைத் திறக்க முடியவில்லை. JPEG, PNG அல்லது HEIC புகைப்படத்தை முயற்சிக்கவும்.';

  @override
  String get iapErrorUnavailable =>
      'இந்தச் சாதனத்தில் இப்போது வாங்குதல்கள் கிடைக்கவில்லை.';

  @override
  String get iapErrorProductNotFound =>
      'ஸ்டோரை அணுக முடியவில்லை. பின்னர் மீண்டும் முயற்சிக்கவும்.';

  @override
  String get iapErrorPurchaseFailed =>
      'வாங்குதலை முடிக்க முடியவில்லை. உங்களிடம் கட்டணம் வசூலிக்கப்படவில்லை.';

  @override
  String get settingsBackupTitle => 'சாதன காப்புப்பிரதியில் சேர்';

  @override
  String get settingsBackupSubtitleIos =>
      'முடக்கம்: ஆவணங்களும் கையொப்பங்களும் இந்த iPhone-இல் மட்டுமே இருக்கும். இயக்கம்: அவை உங்கள் iCloud காப்புப்பிரதியில் சேர்க்கப்படும்.';

  @override
  String get settingsBackupSubtitleAndroid =>
      'முடக்கம்: ஆவணங்களும் கையொப்பங்களும் இந்தத் தொலைபேசியில் மட்டுமே இருக்கும். இயக்கம்: அவை உங்கள் மறைகுறியாக்கப்பட்ட Google காப்புப்பிரதியிலும் புதிய தொலைபேசிக்கு மாறும்போதும் சேர்க்கப்படும்.';

  @override
  String get fieldTypeRadio => 'ரேடியோ பொத்தான்';

  @override
  String get fieldTypeRadioShort => 'ரேடியோ';

  @override
  String get fieldTypeInitials => 'சுருக்கொப்பம்';

  @override
  String get fillTapToInitial => 'சுருக்கொப்பமிட தட்டவும்';

  @override
  String get signInitialsTitle => 'உங்கள் சுருக்கொப்பத்தை வரையவும்';

  @override
  String get pressRadioSelected => 'தேர்ந்தெடுக்கப்பட்டது';

  @override
  String get pressRadioNotSelected => 'தேர்ந்தெடுக்கப்படவில்லை';

  @override
  String get detectSelectedHint =>
      'நகர்த்த இழுக்கவும் · அளவை மாற்ற பிஞ்ச் செய்யவும் அல்லது மூலையை இழுக்கவும் · திருத்த மீண்டும் தட்டவும்';

  @override
  String get detectRadioAddChoiceHint =>
      'இந்தக் கேள்விக்கு மற்றொரு தேர்வைச் சேர்க்க மீண்டும் ரேடியோவைத் தட்டவும்';

  @override
  String get detectFieldDeleted => 'புலம் நீக்கப்பட்டது';

  @override
  String get actionUndo => 'செயல்தவிர்';

  @override
  String get detectFormFieldLocked =>
      'இந்தப் புலம் PDF-இன் சொந்தப் படிவத்தின் பகுதி. அடுத்த படியில் நிரப்பவும்.';

  @override
  String get libraryImport => 'இறக்குமதி';

  @override
  String get settingsForgetLearned => 'கற்ற புல முறைகளை மறந்துவிடு';

  @override
  String get settingsForgetLearnedSubtitle =>
      'நீங்கள் சேர்க்கும், மாற்றும், நீக்கும் புலங்களிலிருந்து கண்டறிதல் கற்றுக்கொள்கிறது — இந்தச் சாதனத்தில் மட்டும்.';

  @override
  String get settingsForgetLearnedDone => 'கற்ற புல முறைகள் அழிக்கப்பட்டன';

  @override
  String paywallReasonAllowance(int count) {
    return 'உங்கள் $count இலவச ஆவணங்களைப் பயன்படுத்திவிட்டீர்கள்.';
  }

  @override
  String paywallReasonPages(int count) {
    return 'இலவச ஆவணங்களில் அதிகபட்சம் $count பக்கங்கள் இருக்கலாம்.';
  }

  @override
  String get paywallBenefitAnyLength => 'எந்த நீளமுள்ள ஆவணங்களும்';

  @override
  String pageLimitTitle(int count) {
    return 'இலவச ஆவணங்கள்: அதிகபட்சம் $count பக்கங்கள்';
  }

  @override
  String pageLimitBody(int pages, int limit) {
    return 'இந்த ஆவணத்தில் $pages பக்கங்கள் உள்ளன. எந்த நீளமுள்ள ஆவணங்களுக்கும் முழு அணுகலைத் திறக்கவும், அல்லது முதல் $limit பக்கங்களை வைத்துக்கொள்ளவும்.';
  }

  @override
  String pageLimitKeepFirst(int count) {
    return 'முதல் $count பக்கங்களை வைத்துக்கொள்';
  }

  @override
  String pressFreeRemaining(int left, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other:
          'முடிப்பது உங்கள் $total இலவச ஆவணங்களில் 1-ஐப் பயன்படுத்தும் ($left மீதம்)',
      one: 'முடிப்பது உங்கள் கடைசி இலவச ஆவணத்தைப் பயன்படுத்தும்',
      zero: 'உங்கள் $total இலவச ஆவணங்களைப் பயன்படுத்திவிட்டீர்கள்',
    );
    return '$_temp0';
  }
}
