// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Scan Sign Send';

  @override
  String get actionCancel => 'रद्द करें';

  @override
  String get actionSave => 'सहेजें';

  @override
  String get actionDelete => 'हटाएँ';

  @override
  String get actionRemove => 'निकालें';

  @override
  String get actionConfirm => 'पुष्टि करें';

  @override
  String get actionBack => 'पीछे';

  @override
  String get actionSkip => 'छोड़ें';

  @override
  String get actionNext => 'आगे';

  @override
  String get actionOpen => 'खोलें';

  @override
  String get actionEdit => 'संपादित करें';

  @override
  String get actionShare => 'साझा करें';

  @override
  String get actionTryAgain => 'पुनः प्रयास करें';

  @override
  String get actionClear => 'मिटाएँ';

  @override
  String get documentFallbackTitle => 'दस्तावेज़';

  @override
  String get errorGenericTitle => 'यहाँ कुछ गड़बड़ हो गई।';

  @override
  String get errorGenericBody => 'पीछे जाकर इस दस्तावेज़ को दोबारा खोलें।';

  @override
  String get lockTitle => 'Scan Sign Send लॉक है';

  @override
  String get lockBody =>
      'जारी रखने के लिए Face ID या अपनी फ़िंगरप्रिंट से अनलॉक करें।';

  @override
  String get lockUnlock => 'अनलॉक करें';

  @override
  String get onboardScanTitle => 'स्कैन करें';

  @override
  String get onboardScanBody =>
      'किसी भी कागज़ी दस्तावेज़ को स्कैन करने के लिए अपने कैमरे का उपयोग करें। किनारे अपने आप पहचाने जाते हैं और छवि साफ़ हो जाती है।';

  @override
  String get onboardSignTitle => 'हस्ताक्षर करें';

  @override
  String get onboardSignBody =>
      'फ़ील्ड भरने के लिए उन पर टैप करें। अपनी उँगली से हस्ताक्षर जोड़ें। आपका डेटा कभी भी आपके डिवाइस से बाहर नहीं जाता।';

  @override
  String get onboardSendTitle => 'भेजें';

  @override
  String get onboardSendBody =>
      'हस्ताक्षरित PDF को Mail, Messages, AirDrop या किसी भी ऐप से साझा करें। एक बार की ख़रीद — हमेशा के लिए असीमित दस्तावेज़।';

  @override
  String get onboardGetStarted => 'शुरू करें';

  @override
  String get librarySearchHint => 'दस्तावेज़ खोजें…';

  @override
  String get libraryTabAll => 'सभी';

  @override
  String get libraryTabDraft => 'ड्राफ़्ट';

  @override
  String get libraryTabCompleted => 'पूर्ण';

  @override
  String get libraryTabTemplate => 'टेम्पलेट';

  @override
  String get libraryImportTooltip => 'PDF / छवि आयात करें';

  @override
  String get libraryNewScan => 'नया स्कैन';

  @override
  String get libraryRenameTooltip => 'नाम बदलें';

  @override
  String get libraryUseTemplate => 'टेम्पलेट उपयोग करें';

  @override
  String get libraryDeleteTitle => 'दस्तावेज़ हटाएँ?';

  @override
  String libraryDeleteBody(String title) {
    return '“$title” हटाएँ? इसे पूर्ववत नहीं किया जा सकता।';
  }

  @override
  String get libraryRenameTitle => 'दस्तावेज़ का नाम बदलें';

  @override
  String get libraryDocumentNameHint => 'दस्तावेज़ का नाम';

  @override
  String libraryUseTemplateFailed(String error) {
    return 'टेम्पलेट उपयोग नहीं हो सका: $error';
  }

  @override
  String get statusCompleted => 'पूर्ण';

  @override
  String get statusEditable => 'संपादन योग्य';

  @override
  String get statusTemplate => 'टेम्पलेट';

  @override
  String get statusDraft => 'ड्राफ़्ट';

  @override
  String get emptyDraftsTitle => 'कोई ड्राफ़्ट नहीं';

  @override
  String get emptyDraftsBody => 'ड्राफ़्ट बनाने के लिए नया स्कैन शुरू करें।';

  @override
  String get emptyPressedTitle => 'कोई पूर्ण दस्तावेज़ नहीं';

  @override
  String get emptyPressedBody =>
      'किसी ड्राफ़्ट को भरकर अंतिम रूप दें, वह यहाँ दिखेगा।';

  @override
  String get emptyTemplatesTitle => 'अभी कोई टेम्पलेट नहीं';

  @override
  String get emptyTemplatesBody =>
      'जब आप किसी दस्तावेज़ को अंतिम रूप देते हैं, तो एक\nपुन: उपयोग योग्य टेम्पलेट यहाँ अपने आप सहेजा जाता है।';

  @override
  String get emptyAllTitle => 'अभी कोई दस्तावेज़ नहीं';

  @override
  String get emptyAllBody =>
      'शुरू करने के लिए “नया स्कैन” पर टैप करें।\nस्कैन → हस्ताक्षर → भेजें।';

  @override
  String searchNoResults(String query) {
    return '“$query” के लिए कोई परिणाम नहीं';
  }

  @override
  String get captureTitle => 'दस्तावेज़ स्कैन करें';

  @override
  String get captureLaunching => 'स्कैनर खुल रहा है…';

  @override
  String get captureSavingPages => 'पृष्ठ सहेजे जा रहे हैं…';

  @override
  String get captureImporting => 'आयात हो रहा है…';

  @override
  String captureScanFailed(String error) {
    return 'स्कैन विफल: $error';
  }

  @override
  String captureImportFailed(String error) {
    return 'आयात विफल: $error';
  }

  @override
  String get captureScanWithCamera => 'कैमरे से स्कैन करें';

  @override
  String get captureImportPdfImage => 'PDF / छवि आयात करें';

  @override
  String get captureUpTo20Pages => 'प्रति स्कैन 20 पृष्ठ तक';

  @override
  String captureDefaultDocumentName(String date) {
    return 'दस्तावेज़ $date';
  }

  @override
  String get reviewTitle => 'पृष्ठ जाँचें';

  @override
  String get reviewSaveOrder => 'क्रम सहेजें';

  @override
  String get reviewNoPagesFound => 'कोई पृष्ठ नहीं मिला।';

  @override
  String get reviewDetectFields => 'फ़ील्ड पहचानें →';

  @override
  String reviewRotateFailed(String error) {
    return 'घुमाना विफल: $error';
  }

  @override
  String get reviewDeletePageTitle => 'पृष्ठ हटाएँ?';

  @override
  String reviewDeletePageBody(int number) {
    return 'पृष्ठ $number हटाएँ?';
  }

  @override
  String reviewPageOf(int current, int total) {
    return 'पृष्ठ $current / $total';
  }

  @override
  String get reviewRotateTooltip => '90° घुमाएँ';

  @override
  String get reviewDeletePageTooltip => 'पृष्ठ हटाएँ';

  @override
  String get filterOriginal => 'मूल';

  @override
  String get filterEnhanced => 'बेहतर';

  @override
  String get filterBw => 'श्वेत-श्याम';

  @override
  String get detectTitle => 'फ़ील्ड पहचानें';

  @override
  String get detectFormFieldsFoundTitle => 'फ़ॉर्म फ़ील्ड मिले';

  @override
  String get detectFormFieldsFoundBody =>
      'इस PDF में पहले से फ़ॉर्म फ़ील्ड मौजूद हैं।\nआप स्वयं फ़ील्ड जोड़ सकते हैं या सीधे भरने के लिए आगे बढ़ सकते हैं।';

  @override
  String get detectContinueToFill => 'भरने के लिए आगे बढ़ें';

  @override
  String get detectConfirmAll => 'सभी की पुष्टि करें';

  @override
  String get detectStarting => 'शुरू हो रहा है…';

  @override
  String get detectReading => 'आपका दस्तावेज़ पढ़ा जा रहा है…';

  @override
  String detectAnalysingPage(int current, int total) {
    return 'पृष्ठ $current / $total का विश्लेषण…';
  }

  @override
  String get detectUnknownError => 'अज्ञात त्रुटि';

  @override
  String get detectOnDeviceNote => 'सारी प्रोसेसिंग आपके डिवाइस पर ही होती है।';

  @override
  String get detectFailed => 'पहचान विफल';

  @override
  String get detectNoPages => 'कोई पृष्ठ नहीं।';

  @override
  String get detectSkipToFill => 'सीधे भरने चलें →';

  @override
  String detectFillFieldsCount(int count) {
    return 'फ़ील्ड भरें ($count) →';
  }

  @override
  String get detectBadgeText => 'टेक्स्ट';

  @override
  String get detectBadgeDate => 'तिथि';

  @override
  String get detectBadgeCheck => 'चेक';

  @override
  String get detectBadgeSign => 'हस्ता.';

  @override
  String get detectEditField => 'फ़ील्ड संपादित करें';

  @override
  String get detectFieldType => 'प्रकार';

  @override
  String get detectFieldLabelHint => 'लेबल / फ़ील्ड का नाम';

  @override
  String get detectRequiredField => 'अनिवार्य फ़ील्ड';

  @override
  String get detectAddField => 'फ़ील्ड जोड़ें';

  @override
  String detectAddTypedField(String type) {
    return '$type फ़ील्ड जोड़ें';
  }

  @override
  String get fieldTypeText => 'टेक्स्ट';

  @override
  String get fieldTypeDate => 'तिथि';

  @override
  String get fieldTypeCheckbox => 'चेकबॉक्स';

  @override
  String get fieldTypeSignature => 'हस्ताक्षर';

  @override
  String get fieldTypeCheckShort => 'चेक';

  @override
  String get fieldTypeSignShort => 'हस्ताक्षर';

  @override
  String get fillFallbackTitle => 'दस्तावेज़ भरें';

  @override
  String get fillReviewAndFinish => 'जाँचें और पूरा करें';

  @override
  String get fillNoPages => 'इस दस्तावेज़ में कोई पृष्ठ नहीं है।';

  @override
  String get fillTextFieldFallback => 'टेक्स्ट फ़ील्ड';

  @override
  String get fillEnterValueHint => 'मान दर्ज करें…';

  @override
  String get fillChipName => 'नाम';

  @override
  String get fillChipEmail => 'ई-मेल';

  @override
  String get fillChipPhone => 'फ़ोन';

  @override
  String get fillChipAddress => 'पता';

  @override
  String get fillChipCompany => 'कंपनी';

  @override
  String get fillChipToday => 'आज';

  @override
  String get fillTapToFill => 'भरने के लिए टैप करें…';

  @override
  String get fillTapForDate => 'तिथि के लिए टैप करें…';

  @override
  String get fillTapToCheck => 'चेक करने के लिए टैप करें';

  @override
  String get fillTapToSign => 'हस्ताक्षर के लिए टैप करें…';

  @override
  String get fillPdfNotFound => 'PDF नहीं मिला';

  @override
  String get fillImageNotFound => 'छवि नहीं मिली';

  @override
  String get fillScanOrImport => 'नया दस्तावेज़ स्कैन या आयात करें';

  @override
  String get pressTitle => 'जाँचें और पूरा करें';

  @override
  String get pressFieldSummary => 'फ़ील्ड सारांश';

  @override
  String get pressFilled => 'भरा हुआ';

  @override
  String get pressUnfilled => 'ख़ाली';

  @override
  String get pressSaveDraft => 'ड्राफ़्ट सहेजें';

  @override
  String get pressFlattenAndSign =>
      'फ़्लैटन करें और हस्ताक्षर करें (दस्तावेज़ लॉक हो जाएगा)';

  @override
  String pressExportFailed(String error) {
    return 'निर्यात विफल: $error';
  }

  @override
  String get pressConfirmTitle => 'इस दस्तावेज़ को फ़्लैटन करके लॉक करें?';

  @override
  String get pressConfirmBody =>
      'फ़्लैटन करने पर आपकी प्रविष्टियाँ एक नए PDF में स्थायी रूप से जुड़ जाती हैं। इसके बाद इसे कोई नहीं बदल सकता — आप भी नहीं।';

  @override
  String get pressConfirmLiveFields =>
      'इस दस्तावेज़ में इंटरैक्टिव फ़ॉर्म फ़ील्ड हैं। फ़्लैटन करने पर वे हट जाएँगे — उन्हें संपादन योग्य रखने के लिए “ड्राफ़्ट सहेजें” चुनें।';

  @override
  String get pressConfirmNote =>
      'ध्यान दें: यहाँ बनाया गया हस्ताक्षर एक दृश्य चिह्न है, प्रमाणित डिजिटल ई-हस्ताक्षर नहीं।';

  @override
  String get pressFlattenAndLock => 'फ़्लैटन करें और लॉक करें';

  @override
  String pressFailed(String error) {
    return 'प्रक्रिया विफल: $error';
  }

  @override
  String get pressWorking => 'कार्य जारी…';

  @override
  String get pressNotFilled => 'नहीं भरा गया';

  @override
  String get pressChecked => 'चेक किया ✓';

  @override
  String get pressUnchecked => 'चेक नहीं किया';

  @override
  String get pressSignatureCaptured => 'हस्ताक्षर सहेजा गया';

  @override
  String get signTitle => 'यहाँ हस्ताक्षर करें';

  @override
  String get signSwitchInk => 'स्याही का रंग बदलें';

  @override
  String get signSaveAsMine => 'मेरे हस्ताक्षर के रूप में सहेजें';

  @override
  String get signReuseSubtitle => 'भविष्य के दस्तावेज़ों में पुन: उपयोग करें';

  @override
  String get signSaving => 'सहेजा जा रहा है…';

  @override
  String get signUseThis => 'यही हस्ताक्षर उपयोग करें';

  @override
  String get signDrawFirst => 'कृपया पहले अपना हस्ताक्षर बनाएँ।';

  @override
  String get signDefaultLabel => 'मेरा हस्ताक्षर';

  @override
  String signSaveFailed(String error) {
    return 'हस्ताक्षर सहेजा नहीं जा सका: $error';
  }

  @override
  String get signaturesTitle => 'सहेजे गए हस्ताक्षर';

  @override
  String get signaturesEmpty => 'अभी कोई हस्ताक्षर सहेजा नहीं गया';

  @override
  String get signaturesAdd => 'हस्ताक्षर जोड़ें';

  @override
  String get signaturesDefaultBadge => 'डिफ़ॉल्ट';

  @override
  String get signaturesSetDefault => 'डिफ़ॉल्ट बनाएँ';

  @override
  String get signaturesDeleteTitle => 'हस्ताक्षर हटाएँ?';

  @override
  String signaturesDeleteBody(String label) {
    return '“$label” हटाएँ?';
  }

  @override
  String get sendTitle => 'दस्तावेज़ भेजें';

  @override
  String get sendBackToLibrary => 'लाइब्रेरी पर लौटें';

  @override
  String get sendDocumentSent => 'दस्तावेज़ भेज दिया गया!';

  @override
  String get sendReadyToSend => 'भेजने के लिए तैयार';

  @override
  String get sendSharedBody => 'अंतिम PDF साझा कर दिया गया।';

  @override
  String get sendReadyBody =>
      'अपना अंतिम PDF Mail, Messages, AirDrop या किसी भी ऐप से साझा करें।';

  @override
  String get sendOpeningShareSheet => 'साझा करने का विकल्प खुल रहा है…';

  @override
  String get sendSharePressed => 'अंतिम दस्तावेज़ साझा करें';

  @override
  String get sendPreviewDocument => 'दस्तावेज़ का पूर्वावलोकन';

  @override
  String get sendShareAgain => 'फिर से साझा करें';

  @override
  String get sendNotYetPressed =>
      'दस्तावेज़ को अभी अंतिम रूप नहीं दिया गया है।';

  @override
  String get sendPressedPdfNotFound => 'अंतिम PDF फ़ाइल नहीं मिली।';

  @override
  String get sendShareMessage => 'Scan Sign Send से हस्ताक्षरित';

  @override
  String sendShareFailed(String error) {
    return 'साझा करना विफल: $error';
  }

  @override
  String get viewerPdfNotFound => 'PDF फ़ाइल नहीं मिली।';

  @override
  String get viewerSearchHint => 'दस्तावेज़ में खोजें…';

  @override
  String get viewerSearchTooltip => 'खोजें';

  @override
  String get viewerNoExportedPdf =>
      'अभी देखने के लिए कोई निर्यातित PDF नहीं है';

  @override
  String get viewerNoExportedPdfBody =>
      'इस दस्तावेज़ को भरकर निर्यात करें (ड्राफ़्ट या फ़्लैटन किया हुआ), तब वह यहाँ दिखेगा।';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsSectionProfile => 'मेरी प्रोफ़ाइल';

  @override
  String get settingsSectionSignatures => 'हस्ताक्षर';

  @override
  String get settingsSectionSecurity => 'सुरक्षा';

  @override
  String get settingsSectionAi => 'AI पहचान (v1.1)';

  @override
  String get settingsSectionPurchase => 'ख़रीद';

  @override
  String get settingsFullName => 'पूरा नाम';

  @override
  String get settingsEmail => 'ई-मेल';

  @override
  String get settingsPhone => 'फ़ोन';

  @override
  String get settingsAddress => 'पता';

  @override
  String get settingsCity => 'शहर';

  @override
  String get settingsState => 'राज्य';

  @override
  String get settingsZip => 'पिन कोड';

  @override
  String get settingsCompany => 'कंपनी';

  @override
  String get settingsManageSignatures => 'हस्ताक्षर प्रबंधित करें';

  @override
  String get settingsBiometricLock => 'बायोमेट्रिक ऐप लॉक';

  @override
  String get settingsBiometricLockSubtitle =>
      'खोलते समय Face ID / फ़िंगरप्रिंट माँगें';

  @override
  String get settingsNoBiometrics =>
      'इस डिवाइस पर कोई बायोमेट्रिक पंजीकृत नहीं है। पहले Face ID / फ़िंगरप्रिंट सेट करें।';

  @override
  String get settingsAiDetection => 'उन्नत AI पहचान';

  @override
  String get settingsAiDetectionSubtitle =>
      'फ़ील्ड बेहतर पहचानने के लिए डिवाइस पर ही मॉडल चलाता है';

  @override
  String get settingsUnlockFullAccess => 'पूर्ण एक्सेस अनलॉक करें';

  @override
  String get settingsUnlockSubtitle => 'एक बार की ख़रीद — क़ीमत देखें';

  @override
  String get settingsRestorePurchase => 'ख़रीद पुनर्स्थापित करें';

  @override
  String get settingsFullAccessUnlocked => 'पूर्ण एक्सेस अनलॉक हो गया';

  @override
  String get settingsThankYou => 'आपकी ख़रीद के लिए धन्यवाद!';

  @override
  String get settingsCheckingPurchases => 'पिछली ख़रीद खोजी जा रही है…';

  @override
  String get settingsRestored => 'पूर्ण एक्सेस पुनर्स्थापित हो गया। धन्यवाद!';

  @override
  String get settingsNoPreviousPurchase =>
      'इस खाते पर कोई पिछली ख़रीद नहीं मिली।';

  @override
  String settingsRestoreFailed(String error) {
    return 'पुनर्स्थापना विफल: $error';
  }

  @override
  String get settingsTapToSet => 'सेट करने के लिए टैप करें';

  @override
  String settingsEditLabel(String label) {
    return '$label संपादित करें';
  }

  @override
  String get paywallTitle => 'पूर्ण एक्सेस अनलॉक करें';

  @override
  String get paywallHeadline => 'Scan Sign Send — पूर्ण एक्सेस';

  @override
  String get paywallSubhead =>
      'एक बार की ख़रीद। कोई सदस्यता नहीं। कोई खाता नहीं।';

  @override
  String get paywallBenefitUnlimited => 'असीमित दस्तावेज़';

  @override
  String get paywallBenefitTemplates => 'पुन: उपयोग योग्य टेम्पलेट';

  @override
  String get paywallBenefitSignatures => 'कई सहेजे गए हस्ताक्षर';

  @override
  String get paywallBenefitAutofill => 'प्रोफ़ाइल से स्वत: भरण';

  @override
  String get paywallBenefitLock => 'बायोमेट्रिक ऐप लॉक';

  @override
  String get paywallBenefitOffline =>
      'हमेशा ऑफ़लाइन — आपका डेटा डिवाइस पर ही रहता है';

  @override
  String paywallUnlockForPrice(String price) {
    return 'अनलॉक करें — $price';
  }

  @override
  String get paywallRestore => 'ख़रीद पुनर्स्थापित करें';

  @override
  String get paywallPaymentDisclosure =>
      'पुष्टि करते ही भुगतान आपके App Store / Play खाते से लिया जाएगा।';

  @override
  String get paywallNoPreviousPurchase =>
      'इस खाते पर कोई पिछली ख़रीद नहीं मिली।';

  @override
  String get dateFormatShort => 'd MMM yyyy';

  @override
  String get dateFormatInput => 'dd/MM/yyyy';

  @override
  String get biometricReason => 'Scan Sign Send अनलॉक करें';

  @override
  String get certTitle => 'हस्ताक्षर प्रमाणपत्र';

  @override
  String get certDocument => 'दस्तावेज़';

  @override
  String get certSignedOn => 'हस्ताक्षर तिथि';

  @override
  String get certMethod => 'विधि';

  @override
  String get certMethodValue => 'डिवाइस पर (Scan Sign Send)';

  @override
  String get certNote => 'नोट';

  @override
  String get certNoteValue =>
      'हस्ताक्षर स्थानीय रूप से लिए गए। कोई क्लाउड प्रोसेसिंग नहीं।';

  @override
  String get certDateFormat => 'd MMMM yyyy — h:mm a';

  @override
  String get importErrorUnreadable =>
      'यह PDF नहीं खुल सका। हो सकता है यह पासवर्ड से सुरक्षित या क्षतिग्रस्त हो।';

  @override
  String get importErrorNoPages => 'इस PDF में कोई पृष्ठ नहीं है।';

  @override
  String get pressErrorNoPages =>
      'इस दस्तावेज़ में अंतिम रूप देने के लिए कोई पृष्ठ नहीं है।';

  @override
  String get exportErrorNoPages =>
      'इस दस्तावेज़ में निर्यात करने के लिए कोई पृष्ठ नहीं है।';

  @override
  String get iapUnavailable => 'इस डिवाइस पर इन-ऐप ख़रीद उपलब्ध नहीं है।';

  @override
  String get iapProductNotFound => 'स्टोर में उत्पाद नहीं मिला।';

  @override
  String detectFieldsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ील्ड मिले',
      one: '1 फ़ील्ड मिला',
      zero: 'कोई फ़ील्ड नहीं मिला',
    );
    return '$_temp0';
  }
}
