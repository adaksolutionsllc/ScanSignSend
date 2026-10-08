// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appTitle => 'Scan Sign Send';

  @override
  String get actionCancel => 'రద్దు';

  @override
  String get actionSave => 'సేవ్ చేయి';

  @override
  String get actionDelete => 'తొలగించు';

  @override
  String get actionRemove => 'తీసివేయి';

  @override
  String get actionConfirm => 'నిర్ధారించు';

  @override
  String get actionBack => 'వెనుకకు';

  @override
  String get actionSkip => 'దాటవేయి';

  @override
  String get actionNext => 'తదుపరి';

  @override
  String get actionOpen => 'తెరువు';

  @override
  String get actionEdit => 'సవరించు';

  @override
  String get actionShare => 'షేర్ చేయి';

  @override
  String get actionTryAgain => 'మళ్లీ ప్రయత్నించు';

  @override
  String get actionClear => 'తుడిచివేయి';

  @override
  String get documentFallbackTitle => 'పత్రం';

  @override
  String get errorGenericTitle => 'ఇక్కడ ఏదో పొరపాటు జరిగింది.';

  @override
  String get errorGenericBody => 'వెనుకకు వెళ్లి ఈ పత్రాన్ని మళ్లీ తెరవండి.';

  @override
  String get lockTitle => 'Scan Sign Send లాక్ చేయబడింది';

  @override
  String get lockBody =>
      'కొనసాగించడానికి Face ID లేదా మీ వేలిముద్రతో అన్‌లాక్ చేయండి.';

  @override
  String get lockUnlock => 'అన్‌లాక్ చేయి';

  @override
  String get onboardScanTitle => 'స్కాన్';

  @override
  String get onboardScanBody =>
      'ఏ కాగితపు పత్రాన్నైనా స్కాన్ చేయడానికి మీ కెమెరాను ఉపయోగించండి. అంచులు వాటంతట అవే గుర్తించబడి చిత్రం శుభ్రపరచబడుతుంది.';

  @override
  String get onboardSignTitle => 'సంతకం';

  @override
  String get onboardSignBody =>
      'ఫీల్డ్‌లను నొక్కి పూరించండి. మీ వేలితో సంతకం జోడించండి. మీ డేటా ఎప్పుడూ మీ పరికరాన్ని విడిచిపెట్టదు.';

  @override
  String get onboardSendTitle => 'పంపు';

  @override
  String get onboardSendBody =>
      'సంతకం చేసిన PDFను ఈమెయిల్, మెసేజింగ్ లేదా ఏ యాప్ ద్వారానైనా షేర్ చేయండి. ఒకేసారి కొనుగోలు — ఎప్పటికీ అపరిమిత పత్రాలు.';

  @override
  String get onboardGetStarted => 'ప్రారంభించండి';

  @override
  String get librarySearchHint => 'పత్రాలను వెతకండి…';

  @override
  String get libraryTabAll => 'అన్నీ';

  @override
  String get libraryTabDraft => 'డ్రాఫ్ట్';

  @override
  String get libraryTabCompleted => 'పూర్తయింది';

  @override
  String get libraryTabTemplate => 'టెంప్లేట్';

  @override
  String get libraryImportTooltip => 'PDF / చిత్రాన్ని దిగుమతి చేయి';

  @override
  String get libraryNewScan => 'కొత్త స్కాన్';

  @override
  String get libraryRenameTooltip => 'పేరు మార్చు';

  @override
  String get libraryUseTemplate => 'టెంప్లేట్ వాడు';

  @override
  String get libraryDeleteTitle => 'పత్రాన్ని తొలగించాలా?';

  @override
  String libraryDeleteBody(String title) {
    return '“$title” తొలగించాలా? దీన్ని తిరిగి పొందలేరు.';
  }

  @override
  String get libraryRenameTitle => 'పత్రం పేరు మార్చు';

  @override
  String get libraryDocumentNameHint => 'పత్రం పేరు';

  @override
  String libraryUseTemplateFailed(String error) {
    return 'టెంప్లేట్ ఉపయోగించలేకపోయాం: $error';
  }

  @override
  String get statusCompleted => 'పూర్తయింది';

  @override
  String get statusEditable => 'సవరించదగినది';

  @override
  String get statusTemplate => 'టెంప్లేట్';

  @override
  String get statusDraft => 'డ్రాఫ్ట్';

  @override
  String get emptyDraftsTitle => 'డ్రాఫ్ట్‌లు లేవు';

  @override
  String get emptyDraftsBody =>
      'డ్రాఫ్ట్ సృష్టించడానికి కొత్త స్కాన్ ప్రారంభించండి.';

  @override
  String get emptyPressedTitle => 'పూర్తయిన పత్రాలు లేవు';

  @override
  String get emptyPressedBody =>
      'ఇక్కడ చూడటానికి ఒక డ్రాఫ్ట్‌ను పూర్తి చేయండి.';

  @override
  String get emptyTemplatesTitle => 'ఇంకా టెంప్లేట్‌లు లేవు';

  @override
  String get emptyTemplatesBody =>
      'పత్రాన్ని పూర్తి చేసిన తర్వాత, ఫారమ్‌ను మళ్లీ ఉపయోగించడానికి\n“టెంప్లేట్‌గా సేవ్ చేయి” నొక్కండి.';

  @override
  String get emptyAllTitle => 'ఇంకా పత్రాలు లేవు';

  @override
  String get emptyAllBody =>
      'ప్రారంభించడానికి “కొత్త స్కాన్” నొక్కండి.\nస్కాన్ → సంతకం → పంపు.';

  @override
  String searchNoResults(String query) {
    return '“$query” కోసం ఫలితాలు లేవు';
  }

  @override
  String get captureTitle => 'పత్రాన్ని స్కాన్ చేయి';

  @override
  String get captureLaunching => 'స్కానర్ తెరుచుకుంటోంది…';

  @override
  String get captureSavingPages => 'పేజీలు సేవ్ అవుతున్నాయి…';

  @override
  String get captureImporting => 'దిగుమతి అవుతోంది…';

  @override
  String captureScanFailed(String error) {
    return 'స్కాన్ విఫలమైంది: $error';
  }

  @override
  String captureImportFailed(String error) {
    return 'దిగుమతి విఫలమైంది: $error';
  }

  @override
  String get captureScanWithCamera => 'కెమెరాతో స్కాన్ చేయి';

  @override
  String get captureImportPdfImage => 'PDF / చిత్రాన్ని దిగుమతి చేయి';

  @override
  String get captureUpTo20Pages => 'ఒక్కో స్కాన్‌కు 20 పేజీల వరకు';

  @override
  String captureDefaultDocumentName(String date) {
    return 'పత్రం $date';
  }

  @override
  String get reviewTitle => 'పేజీలను సమీక్షించు';

  @override
  String get reviewSaveOrder => 'క్రమాన్ని సేవ్ చేయి';

  @override
  String get reviewNoPagesFound => 'పేజీలు ఏవీ దొరకలేదు.';

  @override
  String get reviewDetectFields => 'ఫీల్డ్‌లను గుర్తించు →';

  @override
  String reviewRotateFailed(String error) {
    return 'తిప్పడం విఫలమైంది: $error';
  }

  @override
  String get reviewDeletePageTitle => 'పేజీని తొలగించాలా?';

  @override
  String reviewDeletePageBody(int number) {
    return 'పేజీ $numberని తీసివేయాలా?';
  }

  @override
  String reviewPageOf(int current, int total) {
    return 'పేజీ $current / $total';
  }

  @override
  String get reviewRotateTooltip => '90° తిప్పు';

  @override
  String get reviewDeletePageTooltip => 'పేజీని తొలగించు';

  @override
  String get filterOriginal => 'అసలు';

  @override
  String get filterEnhanced => 'మెరుగైనది';

  @override
  String get filterBw => 'నలుపు-తెలుపు';

  @override
  String get detectTitle => 'ఫీల్డ్‌లను గుర్తించు';

  @override
  String get detectFormFieldsFoundTitle => 'ఫారమ్ ఫీల్డ్‌లు కనుగొనబడ్డాయి';

  @override
  String get detectFormFieldsFoundBody =>
      'ఈ PDFలో ఇప్పటికే ఫారమ్ ఫీల్డ్‌లు ఉన్నాయి.\nమీరు సొంత ఫీల్డ్‌లను జోడించవచ్చు లేదా నేరుగా పూరించడానికి కొనసాగవచ్చు.';

  @override
  String get detectContinueToFill => 'పూరించడానికి కొనసాగు';

  @override
  String get detectConfirmAll => 'అన్నీ నిర్ధారించు';

  @override
  String get detectStarting => 'ప్రారంభమవుతోంది…';

  @override
  String get detectReading => 'మీ పత్రం చదవబడుతోంది…';

  @override
  String detectAnalysingPage(int current, int total) {
    return 'పేజీ $current / $total విశ్లేషణ…';
  }

  @override
  String get detectUnknownError => 'తెలియని లోపం';

  @override
  String get detectOnDeviceNote =>
      'మొత్తం ప్రాసెసింగ్ మీ పరికరంలోనే జరుగుతుంది.';

  @override
  String get detectFailed => 'గుర్తింపు విఫలమైంది';

  @override
  String get detectNoPages => 'పేజీలు లేవు.';

  @override
  String get detectSkipToFill => 'నేరుగా పూరించడానికి →';

  @override
  String detectFillFieldsCount(int count) {
    return 'ఫీల్డ్‌లను పూరించు ($count) →';
  }

  @override
  String get detectBadgeText => 'టెక్స్ట్';

  @override
  String get detectBadgeDate => 'తేదీ';

  @override
  String get detectBadgeCheck => 'చెక్';

  @override
  String get detectBadgeSign => 'సంతకం';

  @override
  String get detectEditField => 'ఫీల్డ్‌ను సవరించు';

  @override
  String get detectFieldType => 'రకం';

  @override
  String get detectFieldLabelHint => 'లేబుల్ / ఫీల్డ్ పేరు';

  @override
  String get detectRequiredField => 'తప్పనిసరి ఫీల్డ్';

  @override
  String get detectAddField => 'ఫీల్డ్ జోడించు';

  @override
  String detectAddTypedField(String type) {
    return '$type ఫీల్డ్ జోడించు';
  }

  @override
  String get fieldTypeText => 'టెక్స్ట్';

  @override
  String get fieldTypeDate => 'తేదీ';

  @override
  String get fieldTypeCheckbox => 'చెక్‌బాక్స్';

  @override
  String get fieldTypeSignature => 'సంతకం';

  @override
  String get fieldTypeCheckShort => 'చెక్';

  @override
  String get fieldTypeSignShort => 'సంతకం';

  @override
  String get fillFallbackTitle => 'పత్రాన్ని పూరించు';

  @override
  String get fillEditFields => 'ఫీల్డ్‌లను సవరించండి';

  @override
  String get fillReviewAndFinish => 'సమీక్షించి పూర్తి చేయి';

  @override
  String get fillNoPages => 'ఈ పత్రంలో పేజీలు లేవు.';

  @override
  String get fillTextFieldFallback => 'టెక్స్ట్ ఫీల్డ్';

  @override
  String get fillEnterValueHint => 'విలువను నమోదు చేయండి…';

  @override
  String get fillChipName => 'పేరు';

  @override
  String get fillChipEmail => 'ఇ-మెయిల్';

  @override
  String get fillChipPhone => 'ఫోన్';

  @override
  String get fillChipAddress => 'చిరునామా';

  @override
  String get fillChipCompany => 'సంస్థ';

  @override
  String get fillChipToday => 'ఈ రోజు';

  @override
  String get fillTapToFill => 'పూరించడానికి నొక్కండి…';

  @override
  String get fillTapForDate => 'తేదీ కోసం నొక్కండి…';

  @override
  String get fillTapToCheck => 'చెక్ చేయడానికి నొక్కండి';

  @override
  String get fillTapToSign => 'సంతకం చేయడానికి నొక్కండి…';

  @override
  String get fillPdfNotFound => 'PDF దొరకలేదు';

  @override
  String get fillImageNotFound => 'చిత్రం దొరకలేదు';

  @override
  String get fillScanOrImport =>
      'కొత్త పత్రాన్ని స్కాన్ చేయండి లేదా దిగుమతి చేయండి';

  @override
  String get pressTitle => 'సమీక్షించి పూర్తి చేయి';

  @override
  String get pressFieldSummary => 'ఫీల్డ్ సారాంశం';

  @override
  String get pressFilled => 'పూరించబడింది';

  @override
  String get pressUnfilled => 'పూరించలేదు';

  @override
  String get pressSaveDraft => 'డ్రాఫ్ట్ సేవ్ చేయి';

  @override
  String get pressFlattenAndSign =>
      'ఫ్లాటెన్ చేసి సంతకం చేయి (పత్రం లాక్ అవుతుంది)';

  @override
  String pressExportFailed(String error) {
    return 'ఎగుమతి విఫలమైంది: $error';
  }

  @override
  String get pressConfirmTitle => 'ఈ పత్రాన్ని ఫ్లాటెన్ చేసి లాక్ చేయాలా?';

  @override
  String get pressConfirmBody =>
      'ఫ్లాటెన్ చేస్తే మీ నమోదులు కొత్త PDFలో శాశ్వతంగా కలిసిపోతాయి. ఆ తర్వాత మీతో సహా ఎవరూ దాన్ని సవరించలేరు.';

  @override
  String get pressConfirmLiveFields =>
      'ఈ పత్రంలో ఇంటరాక్టివ్ ఫారమ్ ఫీల్డ్‌లు ఉన్నాయి. ఫ్లాటెన్ చేస్తే అవి తొలగిపోతాయి — వాటిని సవరించదగినవిగా ఉంచాలంటే “డ్రాఫ్ట్ సేవ్ చేయి” ఎంచుకోండి.';

  @override
  String get pressConfirmNote =>
      'గమనిక: ఇక్కడ గీసిన సంతకం ఒక దృశ్య గుర్తు మాత్రమే, ధ్రువీకరించిన డిజిటల్ ఇ-సంతకం కాదు.';

  @override
  String get pressFlattenAndLock => 'ఫ్లాటెన్ చేసి లాక్ చేయి';

  @override
  String pressFailed(String error) {
    return 'పత్రాన్ని పూర్తి చేయలేకపోయాం: $error';
  }

  @override
  String get pressWorking => 'పని జరుగుతోంది…';

  @override
  String get pressNotFilled => 'పూరించలేదు';

  @override
  String get pressChecked => 'చెక్ చేయబడింది ✓';

  @override
  String get pressUnchecked => 'చెక్ చేయలేదు';

  @override
  String get pressSignatureCaptured => 'సంతకం నమోదైంది';

  @override
  String get signTitle => 'ఇక్కడ సంతకం చేయండి';

  @override
  String get signSwitchInk => 'సిరా రంగు మార్చు';

  @override
  String get signSaveAsMine => 'నా సంతకంగా సేవ్ చేయి';

  @override
  String get signReuseSubtitle => 'భవిష్యత్ పత్రాలలో మళ్లీ వాడు';

  @override
  String get signSaving => 'సేవ్ అవుతోంది…';

  @override
  String get signUseThis => 'ఈ సంతకాన్ని వాడు';

  @override
  String get signDrawFirst => 'ముందుగా మీ సంతకాన్ని గీయండి.';

  @override
  String get signDefaultLabel => 'నా సంతకం';

  @override
  String signSaveFailed(String error) {
    return 'సంతకాన్ని సేవ్ చేయలేకపోయాం: $error';
  }

  @override
  String get signaturesTitle => 'సేవ్ చేసిన సంతకాలు';

  @override
  String get signaturesEmpty => 'ఇంకా సంతకాలు సేవ్ చేయలేదు';

  @override
  String get signaturesAdd => 'సంతకం జోడించు';

  @override
  String get signaturesDefaultBadge => 'డిఫాల్ట్';

  @override
  String get signaturesSetDefault => 'డిఫాల్ట్‌గా సెట్ చేయి';

  @override
  String get signaturesDeleteTitle => 'సంతకాన్ని తొలగించాలా?';

  @override
  String signaturesDeleteBody(String label) {
    return '“$label” తొలగించాలా?';
  }

  @override
  String get sendTitle => 'పత్రాన్ని పంపు';

  @override
  String get sendBackToLibrary => 'లైబ్రరీకి తిరిగి వెళ్లు';

  @override
  String get sendDocumentSent => 'పత్రం పంపబడింది!';

  @override
  String get sendReadyToSend => 'పంపడానికి సిద్ధం';

  @override
  String get sendSharedBody => 'మీ PDF షేర్ చేయబడింది.';

  @override
  String get sendReadyBody =>
      'మీ PDFను ఈమెయిల్, మెసేజింగ్ లేదా ఏ యాప్ ద్వారానైనా షేర్ చేయండి.';

  @override
  String get sendOpeningShareSheet => 'షేర్ విండో తెరుచుకుంటోంది…';

  @override
  String get sendSharePressed => 'PDF షేర్ చేయండి';

  @override
  String get sendPreviewDocument => 'పత్రాన్ని ప్రివ్యూ చేయి';

  @override
  String get sendShareAgain => 'మళ్లీ షేర్ చేయి';

  @override
  String get sendNotYetPressed => 'ఈ పత్రం ఇంకా పూర్తి కాలేదు.';

  @override
  String get sendPressedPdfNotFound => 'పూర్తయిన PDF కనబడలేదు.';

  @override
  String get sendShareMessage => 'Scan Sign Send ద్వారా సంతకం చేయబడింది';

  @override
  String sendShareFailed(String error) {
    return 'షేర్ విఫలమైంది: $error';
  }

  @override
  String get viewerPdfNotFound => 'PDF ఫైల్ దొరకలేదు.';

  @override
  String get viewerSearchHint => 'పత్రంలో వెతుకు…';

  @override
  String get viewerSearchTooltip => 'వెతుకు';

  @override
  String get viewerNoExportedPdf => 'చూడటానికి ఇంకా ఎగుమతి చేసిన PDF లేదు';

  @override
  String get viewerNoExportedPdfBody =>
      'ఈ పత్రాన్ని పూరించి ఎగుమతి చేయండి (డ్రాఫ్ట్ లేదా ఫ్లాటెన్ చేసినది), అప్పుడు అది ఇక్కడ కనిపిస్తుంది.';

  @override
  String get settingsTitle => 'సెట్టింగ్‌లు';

  @override
  String get settingsSectionProfile => 'నా ప్రొఫైల్';

  @override
  String get settingsSectionSignatures => 'సంతకాలు';

  @override
  String get settingsSectionSecurity => 'భద్రత';

  @override
  String get settingsSectionAi => 'AI గుర్తింపు (v1.1)';

  @override
  String get settingsSectionPurchase => 'కొనుగోలు';

  @override
  String get settingsFullName => 'పూర్తి పేరు';

  @override
  String get settingsEmail => 'ఇ-మెయిల్';

  @override
  String get settingsPhone => 'ఫోన్';

  @override
  String get settingsAddress => 'చిరునామా';

  @override
  String get settingsCity => 'నగరం';

  @override
  String get settingsState => 'రాష్ట్రం';

  @override
  String get settingsZip => 'పిన్ కోడ్';

  @override
  String get settingsCompany => 'సంస్థ';

  @override
  String get settingsManageSignatures => 'సంతకాలను నిర్వహించు';

  @override
  String get settingsBiometricLock => 'బయోమెట్రిక్ యాప్ లాక్';

  @override
  String get settingsBiometricLockSubtitle =>
      'తెరిచినప్పుడు Face ID / వేలిముద్ర అడగాలి';

  @override
  String get settingsNoBiometrics =>
      'ఈ పరికరంలో బయోమెట్రిక్ నమోదు కాలేదు. ముందుగా Face ID / వేలిముద్రను సెట్ చేయండి.';

  @override
  String get settingsAiDetection => 'మెరుగైన AI గుర్తింపు';

  @override
  String get settingsAiDetectionSubtitle =>
      'ఫీల్డ్‌లను మెరుగ్గా గుర్తించడానికి పరికరంలోని మోడల్‌ను వాడుతుంది';

  @override
  String get settingsUnlockFullAccess => 'అన్‌లిమిటెడ్ అన్‌లాక్ చేయి';

  @override
  String get settingsUnlockSubtitle => 'ఒకసారి కొనుగోలు — ధర చూడండి';

  @override
  String get settingsRestorePurchase => 'కొనుగోలును పునరుద్ధరించు';

  @override
  String get settingsFullAccessUnlocked => 'అన్‌లిమిటెడ్ అన్‌లాక్ అయింది';

  @override
  String get settingsThankYou => 'మీ కొనుగోలుకు ధన్యవాదాలు!';

  @override
  String get settingsCheckingPurchases => 'గత కొనుగోళ్లను తనిఖీ చేస్తోంది…';

  @override
  String get settingsRestored => 'అన్‌లిమిటెడ్ పునరుద్ధరించబడింది. ధన్యవాదాలు!';

  @override
  String get settingsNoPreviousPurchase =>
      'ఈ ఖాతాలో గత కొనుగోలు ఏదీ కనిపించలేదు.';

  @override
  String settingsRestoreFailed(String error) {
    return 'పునరుద్ధరణ విఫలమైంది: $error';
  }

  @override
  String get settingsTapToSet => 'సెట్ చేయడానికి నొక్కండి';

  @override
  String settingsEditLabel(String label) {
    return '$label సవరించు';
  }

  @override
  String get paywallTitle => 'అన్‌లిమిటెడ్ అన్‌లాక్ చేయి';

  @override
  String get paywallHeadline => 'Scan Sign Send — అన్‌లిమిటెడ్';

  @override
  String get paywallSubhead =>
      'ఒకసారి కొనుగోలు. సబ్‌స్క్రిప్షన్ లేదు. ఖాతా లేదు.';

  @override
  String get paywallBenefitUnlimited => 'అపరిమిత పత్రాలు';

  @override
  String get paywallBenefitTemplates => 'మళ్లీ వాడగల టెంప్లేట్‌లు';

  @override
  String get paywallBenefitSignatures => 'అనేక సేవ్ చేసిన సంతకాలు';

  @override
  String get paywallBenefitAutofill => 'ప్రొఫైల్ నుండి ఆటోఫిల్';

  @override
  String get paywallBenefitLock => 'బయోమెట్రిక్ యాప్ లాక్';

  @override
  String get paywallBenefitOffline =>
      'ఎప్పుడూ ఆఫ్‌లైన్ — మీ డేటా పరికరంలోనే ఉంటుంది';

  @override
  String paywallUnlockForPrice(String price) {
    return 'అన్‌లాక్ చేయి — $price';
  }

  @override
  String get paywallRestore => 'కొనుగోలును పునరుద్ధరించు';

  @override
  String get paywallPaymentDisclosure =>
      'నిర్ధారించగానే మీ App Store / Play ఖాతా నుండి చెల్లింపు తీసుకోబడుతుంది.';

  @override
  String get paywallNoPreviousPurchase =>
      'ఈ ఖాతాలో గత కొనుగోలు ఏదీ కనిపించలేదు.';

  @override
  String get dateFormatShort => 'd MMM yyyy';

  @override
  String get dateFormatInput => 'dd/MM/yyyy';

  @override
  String get biometricReason => 'Scan Sign Sendని అన్‌లాక్ చేయండి';

  @override
  String get certTitle => 'సంతకం ధ్రువపత్రం';

  @override
  String get certDocument => 'పత్రం';

  @override
  String get certSignedOn => 'సంతకం చేసిన తేదీ';

  @override
  String get certMethod => 'పద్ధతి';

  @override
  String get certMethodValue => 'పరికరంలో (Scan Sign Send)';

  @override
  String get certNote => 'గమనిక';

  @override
  String get certNoteValue =>
      'సంతకాలు స్థానికంగా తీసుకోబడ్డాయి. క్లౌడ్ ప్రాసెసింగ్ లేదు.';

  @override
  String get certDateFormat => 'd MMMM yyyy — h:mm a';

  @override
  String get importErrorUnreadable =>
      'ఈ PDFని తెరవలేకపోయాం. ఇది పాస్‌వర్డ్‌తో రక్షితమై ఉండవచ్చు లేదా పాడైపోయి ఉండవచ్చు.';

  @override
  String get importErrorNoPages => 'ఈ PDFలో పేజీలు లేవు.';

  @override
  String get pressErrorNoPages => 'ఈ పత్రంలో ఖరారు చేయడానికి పేజీలు లేవు.';

  @override
  String get exportErrorNoPages => 'ఈ పత్రంలో ఎగుమతి చేయడానికి పేజీలు లేవు.';

  @override
  String get iapUnavailable =>
      'ఈ పరికరంలో ఇన్-యాప్ కొనుగోళ్లు అందుబాటులో లేవు.';

  @override
  String get iapProductNotFound => 'స్టోర్‌లో ఉత్పత్తి కనబడలేదు.';

  @override
  String detectFieldsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ఫీల్డ్‌లు కనబడ్డాయి',
      one: '1 ఫీల్డ్ కనబడింది',
      zero: 'ఫీల్డ్‌లు ఏవీ కనబడలేదు',
    );
    return '$_temp0';
  }

  @override
  String detectFillFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ఫీల్డ్‌లను నింపండి →',
      one: '1 ఫీల్డ్‌ను నింపండి →',
    );
    return '$_temp0';
  }

  @override
  String get detectPinchHint =>
      'ఫీల్డ్ జోడించడానికి క్రింద ఉన్న సాధనాన్ని నొక్కండి · ఎంచుకోవడానికి ఫీల్డ్‌ను నొక్కండి';

  @override
  String get importErrorUnreadableImage =>
      'ఈ చిత్రాన్ని తెరవడం సాధ్యం కాలేదు. JPEG, PNG లేదా HEIC ఫోటోను ప్రయత్నించండి.';

  @override
  String get iapErrorUnavailable =>
      'ఈ పరికరంలో ప్రస్తుతం కొనుగోళ్లు అందుబాటులో లేవు.';

  @override
  String get iapErrorProductNotFound =>
      'స్టోర్‌ను చేరుకోలేకపోయాము. దయచేసి తర్వాత మళ్లీ ప్రయత్నించండి.';

  @override
  String get iapErrorPurchaseFailed =>
      'కొనుగోలు పూర్తి కాలేదు. మీ నుండి ఎలాంటి రుసుము వసూలు చేయలేదు.';

  @override
  String get settingsBackupTitle => 'పరికర బ్యాకప్‌లో చేర్చండి';

  @override
  String get settingsBackupSubtitleIos =>
      'ఆఫ్: పత్రాలు, సంతకాలు ఈ iPhoneలో మాత్రమే ఉంటాయి. ఆన్: అవి మీ iCloud బ్యాకప్‌లో చేర్చబడతాయి.';

  @override
  String get settingsBackupSubtitleAndroid =>
      'ఆఫ్: పత్రాలు, సంతకాలు ఈ ఫోన్‌లో మాత్రమే ఉంటాయి. ఆన్: అవి మీ ఎన్‌క్రిప్ట్ చేసిన Google బ్యాకప్‌లో మరియు కొత్త ఫోన్‌కి మారేటప్పుడు చేర్చబడతాయి.';

  @override
  String get fieldTypeRadio => 'రేడియో బటన్';

  @override
  String get fieldTypeRadioShort => 'రేడియో';

  @override
  String get fieldTypeInitials => 'సంక్షిప్త సంతకం';

  @override
  String get fillTapToInitial => 'సంక్షిప్త సంతకం కోసం నొక్కండి';

  @override
  String get signInitialsTitle => 'మీ సంక్షిప్త సంతకాన్ని గీయండి';

  @override
  String get pressRadioSelected => 'ఎంచుకోబడింది';

  @override
  String get pressRadioNotSelected => 'ఎంచుకోబడలేదు';

  @override
  String get detectSelectedHint =>
      'జరపడానికి లాగండి · పరిమాణం మార్చడానికి పించ్ చేయండి లేదా మూలను లాగండి · సవరించడానికి మళ్లీ నొక్కండి';

  @override
  String get detectRadioAddChoiceHint =>
      'ఈ ప్రశ్నకు మరో ఎంపికను జోడించడానికి మళ్లీ రేడియోను నొక్కండి';

  @override
  String get detectFieldDeleted => 'ఫీల్డ్ తొలగించబడింది';

  @override
  String get detectRemoveDetected => 'గుర్తించిన ఫీల్డ్‌లను తొలగించు';

  @override
  String detectRemovedDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'గుర్తించిన $count ఫీల్డ్‌లు తొలగించబడ్డాయి',
      one: 'గుర్తించిన 1 ఫీల్డ్ తొలగించబడింది',
    );
    return '$_temp0';
  }

  @override
  String get actionUndo => 'రద్దు చేయి';

  @override
  String get detectFormFieldLocked =>
      'ఈ ఫీల్డ్ PDF యొక్క స్వంత ఫారమ్‌లో భాగం. తదుపరి దశలో దీన్ని నింపండి.';

  @override
  String get libraryImport => 'దిగుమతి';

  @override
  String get settingsForgetLearned => 'నేర్చుకున్న ఫీల్డ్ నమూనాలను మరచిపో';

  @override
  String get settingsForgetLearnedSubtitle =>
      'మీరు జోడించే, మార్చే, తొలగించే ఫీల్డ్‌ల నుండి గుర్తింపు నేర్చుకుంటుంది — ఈ పరికరంలో మాత్రమే.';

  @override
  String get settingsForgetLearnedDone =>
      'నేర్చుకున్న ఫీల్డ్ నమూనాలు తొలగించబడ్డాయి';

  @override
  String paywallReasonAllowance(int count) {
    return 'మీ $count ఉచిత పత్రాలను ఉపయోగించేశారు.';
  }

  @override
  String paywallReasonPages(int count) {
    return 'ఉచిత పత్రాలలో గరిష్ఠంగా $count పేజీలు ఉండవచ్చు.';
  }

  @override
  String get paywallBenefitAnyLength => 'ఏ పొడవు పత్రాలైనా';

  @override
  String pageLimitTitle(int count) {
    return 'ఉచిత పత్రాలు: గరిష్ఠంగా $count పేజీలు';
  }

  @override
  String pageLimitBody(int pages, int limit) {
    return 'ఈ పత్రంలో $pages పేజీలు ఉన్నాయి. ఏ పొడవు పత్రాలకైనా అన్‌లిమిటెడ్ అన్‌లాక్ చేయండి, లేదా మొదటి $limit పేజీలను ఉంచుకోండి.';
  }

  @override
  String pageLimitKeepFirst(int count) {
    return 'మొదటి $count పేజీలను ఉంచుకోండి';
  }

  @override
  String pressFreeRemaining(int left, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other:
          'పూర్తి చేయడం మీ $total ఉచిత పత్రాలలో 1ని ఉపయోగిస్తుంది ($left మిగిలి ఉన్నాయి)',
      one: 'పూర్తి చేయడం మీ చివరి ఉచిత పత్రాన్ని ఉపయోగిస్తుంది',
      zero: 'మీ $total ఉచిత పత్రాలను ఉపయోగించేశారు',
    );
    return '$_temp0';
  }

  @override
  String get sendSaveAsTemplate => 'టెంప్లేట్‌గా సేవ్ చేయి';

  @override
  String get sendTemplateSaved =>
      'టెంప్లేట్‌లలో సేవ్ అయింది — లైబ్రరీ నుండి కొత్త కాపీ ప్రారంభించండి.';

  @override
  String get sendTemplateSavedShort => 'టెంప్లేట్‌గా సేవ్ అయింది';
}
