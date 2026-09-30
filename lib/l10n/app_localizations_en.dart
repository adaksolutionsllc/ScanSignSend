// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Scan Sign Send';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionBack => 'Back';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionNext => 'Next';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionShare => 'Share';

  @override
  String get actionTryAgain => 'Try Again';

  @override
  String get actionClear => 'Clear';

  @override
  String get documentFallbackTitle => 'Document';

  @override
  String get errorGenericTitle => 'Something went wrong here.';

  @override
  String get errorGenericBody => 'Try going back and reopening this document.';

  @override
  String get lockTitle => 'Scan Sign Send is locked';

  @override
  String get lockBody => 'Unlock with Face ID or your fingerprint to continue.';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get onboardScanTitle => 'Scan';

  @override
  String get onboardScanBody =>
      'Use your camera to scan any paper document. Auto-detects edges and cleans up the image automatically.';

  @override
  String get onboardSignTitle => 'Sign';

  @override
  String get onboardSignBody =>
      'Tap fields to fill them in. Add your signature with your finger. Your data never leaves your device.';

  @override
  String get onboardSendTitle => 'Send';

  @override
  String get onboardSendBody =>
      'Share the signed PDF by email, messaging or any app. One-time purchase — unlimited documents forever.';

  @override
  String get onboardGetStarted => 'Get Started';

  @override
  String get librarySearchHint => 'Search documents…';

  @override
  String get libraryTabAll => 'All';

  @override
  String get libraryTabDraft => 'Draft';

  @override
  String get libraryTabCompleted => 'Completed';

  @override
  String get libraryTabTemplate => 'Template';

  @override
  String get libraryImportTooltip => 'Import PDF / Image';

  @override
  String get libraryNewScan => 'New Scan';

  @override
  String get libraryRenameTooltip => 'Rename';

  @override
  String get libraryUseTemplate => 'Use Template';

  @override
  String get libraryDeleteTitle => 'Delete Document?';

  @override
  String libraryDeleteBody(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get libraryRenameTitle => 'Rename Document';

  @override
  String get libraryDocumentNameHint => 'Document name';

  @override
  String libraryUseTemplateFailed(String error) {
    return 'Failed to use template: $error';
  }

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusEditable => 'Editable';

  @override
  String get statusTemplate => 'Template';

  @override
  String get statusDraft => 'Draft';

  @override
  String get emptyDraftsTitle => 'No drafts';

  @override
  String get emptyDraftsBody => 'Start a new scan to create a draft.';

  @override
  String get emptyPressedTitle => 'No completed documents';

  @override
  String get emptyPressedBody => 'Finish a draft to see it here.';

  @override
  String get emptyTemplatesTitle => 'No templates yet';

  @override
  String get emptyTemplatesBody =>
      'After finishing a document, tap\n\"Save as reusable template\" to reuse the form.';

  @override
  String get emptyAllTitle => 'No documents yet';

  @override
  String get emptyAllBody =>
      'Tap \"New Scan\" to get started.\nScan → Sign → Send.';

  @override
  String searchNoResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get captureTitle => 'Scan Document';

  @override
  String get captureLaunching => 'Launching scanner…';

  @override
  String get captureSavingPages => 'Saving pages…';

  @override
  String get captureImporting => 'Importing…';

  @override
  String captureScanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String captureImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get captureScanWithCamera => 'Scan with Camera';

  @override
  String get captureImportPdfImage => 'Import PDF / Image';

  @override
  String get captureUpTo20Pages => 'Up to 20 pages per scan';

  @override
  String captureDefaultDocumentName(String date) {
    return 'Document $date';
  }

  @override
  String get reviewTitle => 'Review Pages';

  @override
  String get reviewSaveOrder => 'Save Order';

  @override
  String get reviewNoPagesFound => 'No pages found.';

  @override
  String get reviewDetectFields => 'Detect Fields →';

  @override
  String reviewRotateFailed(String error) {
    return 'Rotate failed: $error';
  }

  @override
  String get reviewDeletePageTitle => 'Delete Page?';

  @override
  String reviewDeletePageBody(int number) {
    return 'Remove page $number?';
  }

  @override
  String reviewPageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get reviewRotateTooltip => 'Rotate 90°';

  @override
  String get reviewDeletePageTooltip => 'Delete page';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterEnhanced => 'Enhanced';

  @override
  String get filterBw => 'B&W';

  @override
  String get detectTitle => 'Detect Fields';

  @override
  String get detectFormFieldsFoundTitle => 'Form fields detected';

  @override
  String get detectFormFieldsFoundBody =>
      'This PDF already contains form fields.\nYou can add your own fields manually or continue directly to fill.';

  @override
  String get detectContinueToFill => 'Continue to Fill';

  @override
  String get detectConfirmAll => 'Confirm All';

  @override
  String get detectStarting => 'Starting…';

  @override
  String get detectReading => 'Reading your document…';

  @override
  String detectAnalysingPage(int current, int total) {
    return 'Analysing page $current of $total…';
  }

  @override
  String get detectUnknownError => 'Unknown error';

  @override
  String get detectOnDeviceNote => 'All processing happens on-device.';

  @override
  String get detectFailed => 'Detection failed';

  @override
  String get detectNoPages => 'No pages.';

  @override
  String get detectSkipToFill => 'Skip to Fill →';

  @override
  String detectFillFieldsCount(int count) {
    return 'Fill Fields ($count) →';
  }

  @override
  String get detectBadgeText => 'TEXT';

  @override
  String get detectBadgeDate => 'DATE';

  @override
  String get detectBadgeCheck => 'CHECK';

  @override
  String get detectBadgeSign => 'SIGN';

  @override
  String get detectEditField => 'Edit Field';

  @override
  String get detectFieldType => 'Type';

  @override
  String get detectFieldLabelHint => 'Label / field name';

  @override
  String get detectRequiredField => 'Required field';

  @override
  String get detectAddField => 'Add Field';

  @override
  String detectAddTypedField(String type) {
    return 'Add $type Field';
  }

  @override
  String get fieldTypeText => 'Text';

  @override
  String get fieldTypeDate => 'Date';

  @override
  String get fieldTypeCheckbox => 'Checkbox';

  @override
  String get fieldTypeSignature => 'Signature';

  @override
  String get fieldTypeCheckShort => 'Check';

  @override
  String get fieldTypeSignShort => 'Sign';

  @override
  String get fillFallbackTitle => 'Fill Document';

  @override
  String get fillEditFields => 'Edit Fields';

  @override
  String get fillReviewAndFinish => 'Review & Finish';

  @override
  String get fillNoPages => 'This document has no pages.';

  @override
  String get fillTextFieldFallback => 'Text Field';

  @override
  String get fillEnterValueHint => 'Enter value…';

  @override
  String get fillChipName => 'Name';

  @override
  String get fillChipEmail => 'Email';

  @override
  String get fillChipPhone => 'Phone';

  @override
  String get fillChipAddress => 'Address';

  @override
  String get fillChipCompany => 'Company';

  @override
  String get fillChipToday => 'Today';

  @override
  String get fillTapToFill => 'Tap to fill…';

  @override
  String get fillTapForDate => 'Tap for date…';

  @override
  String get fillTapToCheck => 'Tap to check';

  @override
  String get fillTapToSign => 'Tap to sign…';

  @override
  String get fillPdfNotFound => 'PDF not found';

  @override
  String get fillImageNotFound => 'Image not found';

  @override
  String get fillScanOrImport => 'Scan or import a new document';

  @override
  String get pressTitle => 'Review & Finish';

  @override
  String get pressFieldSummary => 'Field Summary';

  @override
  String get pressFilled => 'Filled';

  @override
  String get pressUnfilled => 'Unfilled';

  @override
  String get pressSaveDraft => 'Save Draft';

  @override
  String get pressFlattenAndSign => 'Flatten & Sign (locks the document)';

  @override
  String pressExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get pressConfirmTitle => 'Flatten & lock this document?';

  @override
  String get pressConfirmBody =>
      'Flattening bakes your entries into a new PDF. The result is permanent — no one can edit it afterward, including you.';

  @override
  String get pressConfirmLiveFields =>
      'This document has interactive form fields. Flattening removes them — to keep them editable, choose “Save Draft” instead.';

  @override
  String get pressConfirmNote =>
      'Note: a drawn signature here is a visual mark, not a certified digital e-signature.';

  @override
  String get pressFlattenAndLock => 'Flatten & Lock';

  @override
  String pressFailed(String error) {
    return 'Couldn\'t finish the document: $error';
  }

  @override
  String get pressWorking => 'Working…';

  @override
  String get pressNotFilled => 'Not filled';

  @override
  String get pressChecked => 'Checked ✓';

  @override
  String get pressUnchecked => 'Unchecked';

  @override
  String get pressSignatureCaptured => 'Signature captured';

  @override
  String get signTitle => 'Sign Here';

  @override
  String get signSwitchInk => 'Switch ink colour';

  @override
  String get signSaveAsMine => 'Save as my signature';

  @override
  String get signReuseSubtitle => 'Reuse across future documents';

  @override
  String get signSaving => 'Saving…';

  @override
  String get signUseThis => 'Use This Signature';

  @override
  String get signDrawFirst => 'Please draw your signature first.';

  @override
  String get signDefaultLabel => 'My Signature';

  @override
  String signSaveFailed(String error) {
    return 'Failed to save signature: $error';
  }

  @override
  String get signaturesTitle => 'Saved Signatures';

  @override
  String get signaturesEmpty => 'No saved signatures yet';

  @override
  String get signaturesAdd => 'Add Signature';

  @override
  String get signaturesDefaultBadge => 'Default';

  @override
  String get signaturesSetDefault => 'Set as Default';

  @override
  String get signaturesDeleteTitle => 'Delete Signature?';

  @override
  String signaturesDeleteBody(String label) {
    return 'Delete \"$label\"?';
  }

  @override
  String get sendTitle => 'Send Document';

  @override
  String get sendBackToLibrary => 'Back to Library';

  @override
  String get sendDocumentSent => 'Document sent!';

  @override
  String get sendReadyToSend => 'Ready to send';

  @override
  String get sendSharedBody => 'Your PDF has been shared.';

  @override
  String get sendReadyBody => 'Share your PDF by email, messaging or any app.';

  @override
  String get sendOpeningShareSheet => 'Opening share sheet…';

  @override
  String get sendSharePressed => 'Share PDF';

  @override
  String get sendPreviewDocument => 'Preview Document';

  @override
  String get sendShareAgain => 'Share Again';

  @override
  String get sendNotYetPressed => 'This document isn\'t finished yet.';

  @override
  String get sendPressedPdfNotFound => 'The finished PDF couldn\'t be found.';

  @override
  String get sendShareMessage => 'Signed with Scan Sign Send';

  @override
  String sendShareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String get viewerPdfNotFound => 'PDF file not found.';

  @override
  String get viewerSearchHint => 'Search in document…';

  @override
  String get viewerSearchTooltip => 'Search';

  @override
  String get viewerNoExportedPdf => 'No exported PDF to view yet';

  @override
  String get viewerNoExportedPdfBody =>
      'Fill and export this document (draft or flattened) to view it here.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionProfile => 'My Profile';

  @override
  String get settingsSectionSignatures => 'Signatures';

  @override
  String get settingsSectionSecurity => 'Security';

  @override
  String get settingsSectionAi => 'AI Detection (v1.1)';

  @override
  String get settingsSectionPurchase => 'Purchase';

  @override
  String get settingsFullName => 'Full Name';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsPhone => 'Phone';

  @override
  String get settingsAddress => 'Address';

  @override
  String get settingsCity => 'City';

  @override
  String get settingsState => 'State';

  @override
  String get settingsZip => 'ZIP';

  @override
  String get settingsCompany => 'Company';

  @override
  String get settingsManageSignatures => 'Manage Signatures';

  @override
  String get settingsBiometricLock => 'Biometric App Lock';

  @override
  String get settingsBiometricLockSubtitle =>
      'Require Face ID / fingerprint on launch';

  @override
  String get settingsNoBiometrics =>
      'No biometrics enrolled on this device. Set up Face ID / fingerprint first.';

  @override
  String get settingsAiDetection => 'Enhanced AI Detection';

  @override
  String get settingsAiDetectionSubtitle =>
      'Uses on-device model for smarter field recognition';

  @override
  String get settingsUnlockFullAccess => 'Unlock Full Access';

  @override
  String get settingsUnlockSubtitle => 'One-time purchase — see price';

  @override
  String get settingsRestorePurchase => 'Restore Purchase';

  @override
  String get settingsFullAccessUnlocked => 'Full Access Unlocked';

  @override
  String get settingsThankYou => 'Thank you for your purchase!';

  @override
  String get settingsCheckingPurchases => 'Checking for previous purchases…';

  @override
  String get settingsRestored => 'Full access restored. Thank you!';

  @override
  String get settingsNoPreviousPurchase =>
      'No previous purchase found on this account.';

  @override
  String settingsRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get settingsTapToSet => 'Tap to set';

  @override
  String settingsEditLabel(String label) {
    return 'Edit $label';
  }

  @override
  String get paywallTitle => 'Unlock Full Access';

  @override
  String get paywallHeadline => 'Scan Sign Send — Full Access';

  @override
  String get paywallSubhead =>
      'One-time purchase. No subscription. No account.';

  @override
  String get paywallBenefitUnlimited => 'Unlimited documents';

  @override
  String get paywallBenefitTemplates => 'Reusable templates';

  @override
  String get paywallBenefitSignatures => 'Multiple saved signatures';

  @override
  String get paywallBenefitAutofill => 'Profile autofill';

  @override
  String get paywallBenefitLock => 'Biometric app lock';

  @override
  String get paywallBenefitOffline =>
      'Always offline — your data stays on device';

  @override
  String paywallUnlockForPrice(String price) {
    return 'Unlock — $price';
  }

  @override
  String get paywallRestore => 'Restore Purchase';

  @override
  String get paywallPaymentDisclosure =>
      'Payment charged to your App Store / Play account at confirmation.';

  @override
  String get paywallNoPreviousPurchase =>
      'No previous purchase found on this account.';

  @override
  String get dateFormatShort => 'MMM d, yyyy';

  @override
  String get dateFormatInput => 'MM/dd/yyyy';

  @override
  String get biometricReason => 'Unlock Scan Sign Send';

  @override
  String get certTitle => 'Signing Certificate';

  @override
  String get certDocument => 'Document';

  @override
  String get certSignedOn => 'Signed on';

  @override
  String get certMethod => 'Method';

  @override
  String get certMethodValue => 'On-device (Scan Sign Send)';

  @override
  String get certNote => 'Note';

  @override
  String get certNoteValue =>
      'Signatures captured locally. No cloud processing.';

  @override
  String get certDateFormat => 'MMMM d, yyyy — h:mm a';

  @override
  String get importErrorUnreadable =>
      'This PDF couldn\'t be opened. It may be password-protected or damaged.';

  @override
  String get importErrorNoPages => 'This PDF has no pages.';

  @override
  String get pressErrorNoPages => 'This document has no pages to press.';

  @override
  String get exportErrorNoPages => 'This document has no pages to export.';

  @override
  String get iapUnavailable =>
      'In-app purchases are unavailable on this device.';

  @override
  String get iapProductNotFound => 'Product not found in store.';

  @override
  String detectFieldsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields found',
      one: '1 field found',
      zero: 'No fields found',
    );
    return '$_temp0';
  }

  @override
  String detectFillFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fill $count fields →',
      one: 'Fill 1 field →',
    );
    return '$_temp0';
  }

  @override
  String get detectPinchHint =>
      'Tap a tool below to add a field · tap a field to select it';

  @override
  String get importErrorUnreadableImage =>
      'This image couldn\'t be opened. Try a JPEG, PNG or HEIC photo.';

  @override
  String get iapErrorUnavailable =>
      'Purchases aren\'t available on this device right now.';

  @override
  String get iapErrorProductNotFound =>
      'Couldn\'t reach the store. Please try again later.';

  @override
  String get iapErrorPurchaseFailed =>
      'The purchase couldn\'t be completed. You haven\'t been charged.';

  @override
  String get settingsBackupTitle => 'Include in device backup';

  @override
  String get settingsBackupSubtitleIos =>
      'Off: documents and signatures stay only on this iPhone. On: they\'re included in your iCloud Backup.';

  @override
  String get settingsBackupSubtitleAndroid =>
      'Off: documents and signatures stay only on this phone. On: they\'re included in your encrypted Google backup and when moving to a new phone.';

  @override
  String get fieldTypeRadio => 'Radio button';

  @override
  String get fieldTypeRadioShort => 'Radio';

  @override
  String get fieldTypeInitials => 'Initials';

  @override
  String get fillTapToInitial => 'Tap to initial';

  @override
  String get signInitialsTitle => 'Draw your initials';

  @override
  String get pressRadioSelected => 'Selected';

  @override
  String get pressRadioNotSelected => 'Not selected';

  @override
  String get detectSelectedHint =>
      'Drag to move · pinch or drag the corner to resize · tap again to edit';

  @override
  String get detectRadioAddChoiceHint =>
      'Tap Radio again to add another choice to this question';

  @override
  String get detectFieldDeleted => 'Field deleted';

  @override
  String get detectRemoveDetected => 'Remove detected fields';

  @override
  String detectRemovedDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count detected fields',
      one: 'Removed 1 detected field',
    );
    return '$_temp0';
  }

  @override
  String get actionUndo => 'Undo';

  @override
  String get detectFormFieldLocked =>
      'This field is part of the PDF\'s own form. Fill it in on the next step.';

  @override
  String get libraryImport => 'Import';

  @override
  String get settingsForgetLearned => 'Forget learned field patterns';

  @override
  String get settingsForgetLearnedSubtitle =>
      'Field detection learns from the fields you add, retype and delete, on this device only.';

  @override
  String get settingsForgetLearnedDone => 'Learned field patterns cleared';

  @override
  String paywallReasonAllowance(int count) {
    return 'You\'ve used your $count free documents.';
  }

  @override
  String paywallReasonPages(int count) {
    return 'Free documents can have up to $count pages.';
  }

  @override
  String get paywallBenefitAnyLength => 'Documents of any length';

  @override
  String pageLimitTitle(int count) {
    return 'Free documents: up to $count pages';
  }

  @override
  String pageLimitBody(int pages, int limit) {
    return 'This document has $pages pages. Unlock Full Access for documents of any length, or keep the first $limit pages.';
  }

  @override
  String pageLimitKeepFirst(int count) {
    return 'Keep first $count pages';
  }

  @override
  String pressFreeRemaining(int left, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Finishing uses 1 of your $total free documents ($left left)',
      one: 'Finishing uses your last free document',
      zero: 'You\'ve used your $total free documents',
    );
    return '$_temp0';
  }

  @override
  String get sendSaveAsTemplate => 'Save as reusable template';

  @override
  String get sendTemplateSaved =>
      'Saved to Templates — start a new copy from the library.';

  @override
  String get sendTemplateSavedShort => 'Saved as template';
}
