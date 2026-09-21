import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('pt'),
    Locale('ta'),
    Locale('te'),
  ];

  /// Product name. Kept untranslated in every locale.
  ///
  /// In en, this message translates to:
  /// **'Scan Sign Send'**
  String get appTitle;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get actionTryAgain;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// Placeholder name for a document with no title.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get documentFallbackTitle;

  /// No description provided for @errorGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong here.'**
  String get errorGenericTitle;

  /// No description provided for @errorGenericBody.
  ///
  /// In en, this message translates to:
  /// **'Try going back and reopening this document.'**
  String get errorGenericBody;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Sign Send is locked'**
  String get lockTitle;

  /// No description provided for @lockBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Face ID or your fingerprint to continue.'**
  String get lockBody;

  /// No description provided for @lockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlock;

  /// No description provided for @onboardScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get onboardScanTitle;

  /// No description provided for @onboardScanBody.
  ///
  /// In en, this message translates to:
  /// **'Use your camera to scan any paper document. Auto-detects edges and cleans up the image automatically.'**
  String get onboardScanBody;

  /// No description provided for @onboardSignTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get onboardSignTitle;

  /// No description provided for @onboardSignBody.
  ///
  /// In en, this message translates to:
  /// **'Tap fields to fill them in. Add your signature with your finger. Your data never leaves your device.'**
  String get onboardSignBody;

  /// No description provided for @onboardSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get onboardSendTitle;

  /// No description provided for @onboardSendBody.
  ///
  /// In en, this message translates to:
  /// **'Share the signed PDF via Mail, Messages, AirDrop, or any app. One-time purchase — unlimited documents forever.'**
  String get onboardSendBody;

  /// No description provided for @onboardGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardGetStarted;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search documents…'**
  String get librarySearchHint;

  /// No description provided for @libraryTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryTabAll;

  /// No description provided for @libraryTabDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get libraryTabDraft;

  /// No description provided for @libraryTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get libraryTabCompleted;

  /// No description provided for @libraryTabTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get libraryTabTemplate;

  /// No description provided for @libraryImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import PDF / Image'**
  String get libraryImportTooltip;

  /// No description provided for @libraryNewScan.
  ///
  /// In en, this message translates to:
  /// **'New Scan'**
  String get libraryNewScan;

  /// No description provided for @libraryRenameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get libraryRenameTooltip;

  /// No description provided for @libraryUseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use Template'**
  String get libraryUseTemplate;

  /// No description provided for @libraryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Document?'**
  String get libraryDeleteTitle;

  /// No description provided for @libraryDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String libraryDeleteBody(String title);

  /// No description provided for @libraryRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Document'**
  String get libraryRenameTitle;

  /// No description provided for @libraryDocumentNameHint.
  ///
  /// In en, this message translates to:
  /// **'Document name'**
  String get libraryDocumentNameHint;

  /// No description provided for @libraryUseTemplateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to use template: {error}'**
  String libraryUseTemplateFailed(String error);

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusEditable.
  ///
  /// In en, this message translates to:
  /// **'Editable'**
  String get statusEditable;

  /// No description provided for @statusTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get statusTemplate;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @emptyDraftsTitle.
  ///
  /// In en, this message translates to:
  /// **'No drafts'**
  String get emptyDraftsTitle;

  /// No description provided for @emptyDraftsBody.
  ///
  /// In en, this message translates to:
  /// **'Start a new scan to create a draft.'**
  String get emptyDraftsBody;

  /// No description provided for @emptyPressedTitle.
  ///
  /// In en, this message translates to:
  /// **'No pressed documents'**
  String get emptyPressedTitle;

  /// No description provided for @emptyPressedBody.
  ///
  /// In en, this message translates to:
  /// **'Fill and press a draft to see it here.'**
  String get emptyPressedBody;

  /// No description provided for @emptyTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get emptyTemplatesTitle;

  /// No description provided for @emptyTemplatesBody.
  ///
  /// In en, this message translates to:
  /// **'When you press a document, a reusable\ntemplate is saved here automatically.'**
  String get emptyTemplatesBody;

  /// No description provided for @emptyAllTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get emptyAllTitle;

  /// No description provided for @emptyAllBody.
  ///
  /// In en, this message translates to:
  /// **'Tap \"New Scan\" to get started.\nScan → Sign → Send.'**
  String get emptyAllBody;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String searchNoResults(String query);

  /// No description provided for @captureTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Document'**
  String get captureTitle;

  /// No description provided for @captureLaunching.
  ///
  /// In en, this message translates to:
  /// **'Launching scanner…'**
  String get captureLaunching;

  /// No description provided for @captureSavingPages.
  ///
  /// In en, this message translates to:
  /// **'Saving pages…'**
  String get captureSavingPages;

  /// No description provided for @captureImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get captureImporting;

  /// No description provided for @captureScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String captureScanFailed(String error);

  /// No description provided for @captureImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String captureImportFailed(String error);

  /// No description provided for @captureScanWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Scan with Camera'**
  String get captureScanWithCamera;

  /// No description provided for @captureImportPdfImage.
  ///
  /// In en, this message translates to:
  /// **'Import PDF / Image'**
  String get captureImportPdfImage;

  /// No description provided for @captureUpTo20Pages.
  ///
  /// In en, this message translates to:
  /// **'Up to 20 pages per scan'**
  String get captureUpTo20Pages;

  /// No description provided for @captureDefaultDocumentName.
  ///
  /// In en, this message translates to:
  /// **'Document {date}'**
  String captureDefaultDocumentName(String date);

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Pages'**
  String get reviewTitle;

  /// No description provided for @reviewSaveOrder.
  ///
  /// In en, this message translates to:
  /// **'Save Order'**
  String get reviewSaveOrder;

  /// No description provided for @reviewNoPagesFound.
  ///
  /// In en, this message translates to:
  /// **'No pages found.'**
  String get reviewNoPagesFound;

  /// No description provided for @reviewDetectFields.
  ///
  /// In en, this message translates to:
  /// **'Detect Fields →'**
  String get reviewDetectFields;

  /// No description provided for @reviewRotateFailed.
  ///
  /// In en, this message translates to:
  /// **'Rotate failed: {error}'**
  String reviewRotateFailed(String error);

  /// No description provided for @reviewDeletePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Page?'**
  String get reviewDeletePageTitle;

  /// No description provided for @reviewDeletePageBody.
  ///
  /// In en, this message translates to:
  /// **'Remove page {number}?'**
  String reviewDeletePageBody(int number);

  /// No description provided for @reviewPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String reviewPageOf(int current, int total);

  /// No description provided for @reviewRotateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90°'**
  String get reviewRotateTooltip;

  /// No description provided for @reviewDeletePageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete page'**
  String get reviewDeletePageTooltip;

  /// No description provided for @filterOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get filterOriginal;

  /// No description provided for @filterEnhanced.
  ///
  /// In en, this message translates to:
  /// **'Enhanced'**
  String get filterEnhanced;

  /// Black and white image filter. Abbreviate if the locale has a common short form.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get filterBw;

  /// No description provided for @detectTitle.
  ///
  /// In en, this message translates to:
  /// **'Detect Fields'**
  String get detectTitle;

  /// No description provided for @detectFormFieldsFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Form fields detected'**
  String get detectFormFieldsFoundTitle;

  /// No description provided for @detectFormFieldsFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This PDF already contains form fields.\nYou can add your own fields manually or continue directly to fill.'**
  String get detectFormFieldsFoundBody;

  /// No description provided for @detectContinueToFill.
  ///
  /// In en, this message translates to:
  /// **'Continue to Fill'**
  String get detectContinueToFill;

  /// No description provided for @detectConfirmAll.
  ///
  /// In en, this message translates to:
  /// **'Confirm All'**
  String get detectConfirmAll;

  /// No description provided for @detectStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get detectStarting;

  /// No description provided for @detectReading.
  ///
  /// In en, this message translates to:
  /// **'Reading your document…'**
  String get detectReading;

  /// No description provided for @detectAnalysingPage.
  ///
  /// In en, this message translates to:
  /// **'Analysing page {current} of {total}…'**
  String detectAnalysingPage(int current, int total);

  /// No description provided for @detectUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get detectUnknownError;

  /// No description provided for @detectOnDeviceNote.
  ///
  /// In en, this message translates to:
  /// **'All processing happens on-device.'**
  String get detectOnDeviceNote;

  /// No description provided for @detectFailed.
  ///
  /// In en, this message translates to:
  /// **'Detection failed'**
  String get detectFailed;

  /// No description provided for @detectNoPages.
  ///
  /// In en, this message translates to:
  /// **'No pages.'**
  String get detectNoPages;

  /// No description provided for @detectSkipToFill.
  ///
  /// In en, this message translates to:
  /// **'Skip to Fill →'**
  String get detectSkipToFill;

  /// No description provided for @detectFillFieldsCount.
  ///
  /// In en, this message translates to:
  /// **'Fill Fields ({count}) →'**
  String detectFillFieldsCount(int count);

  /// No description provided for @detectBadgeText.
  ///
  /// In en, this message translates to:
  /// **'TEXT'**
  String get detectBadgeText;

  /// No description provided for @detectBadgeDate.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get detectBadgeDate;

  /// No description provided for @detectBadgeCheck.
  ///
  /// In en, this message translates to:
  /// **'CHECK'**
  String get detectBadgeCheck;

  /// Short uppercase badge on a signature field overlay. Keep very short.
  ///
  /// In en, this message translates to:
  /// **'SIGN'**
  String get detectBadgeSign;

  /// No description provided for @detectEditField.
  ///
  /// In en, this message translates to:
  /// **'Edit Field'**
  String get detectEditField;

  /// No description provided for @detectFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get detectFieldType;

  /// No description provided for @detectFieldLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Label / field name'**
  String get detectFieldLabelHint;

  /// No description provided for @detectRequiredField.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get detectRequiredField;

  /// No description provided for @detectAddField.
  ///
  /// In en, this message translates to:
  /// **'Add Field'**
  String get detectAddField;

  /// No description provided for @detectAddTypedField.
  ///
  /// In en, this message translates to:
  /// **'Add {type} Field'**
  String detectAddTypedField(String type);

  /// No description provided for @fieldTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get fieldTypeText;

  /// No description provided for @fieldTypeDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldTypeDate;

  /// No description provided for @fieldTypeCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get fieldTypeCheckbox;

  /// No description provided for @fieldTypeSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get fieldTypeSignature;

  /// No description provided for @fieldTypeCheckShort.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get fieldTypeCheckShort;

  /// No description provided for @fieldTypeSignShort.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get fieldTypeSignShort;

  /// No description provided for @fillFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill Document'**
  String get fillFallbackTitle;

  /// No description provided for @fillReviewAndFinish.
  ///
  /// In en, this message translates to:
  /// **'Review & Finish'**
  String get fillReviewAndFinish;

  /// No description provided for @fillNoPages.
  ///
  /// In en, this message translates to:
  /// **'This document has no pages.'**
  String get fillNoPages;

  /// No description provided for @fillTextFieldFallback.
  ///
  /// In en, this message translates to:
  /// **'Text Field'**
  String get fillTextFieldFallback;

  /// No description provided for @fillEnterValueHint.
  ///
  /// In en, this message translates to:
  /// **'Enter value…'**
  String get fillEnterValueHint;

  /// No description provided for @fillChipName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fillChipName;

  /// No description provided for @fillChipEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fillChipEmail;

  /// No description provided for @fillChipPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fillChipPhone;

  /// No description provided for @fillChipAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fillChipAddress;

  /// No description provided for @fillChipCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get fillChipCompany;

  /// No description provided for @fillChipToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get fillChipToday;

  /// No description provided for @fillTapToFill.
  ///
  /// In en, this message translates to:
  /// **'Tap to fill…'**
  String get fillTapToFill;

  /// No description provided for @fillTapForDate.
  ///
  /// In en, this message translates to:
  /// **'Tap for date…'**
  String get fillTapForDate;

  /// No description provided for @fillTapToCheck.
  ///
  /// In en, this message translates to:
  /// **'Tap to check'**
  String get fillTapToCheck;

  /// No description provided for @fillTapToSign.
  ///
  /// In en, this message translates to:
  /// **'Tap to sign…'**
  String get fillTapToSign;

  /// No description provided for @fillPdfNotFound.
  ///
  /// In en, this message translates to:
  /// **'PDF not found'**
  String get fillPdfNotFound;

  /// No description provided for @fillImageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Image not found'**
  String get fillImageNotFound;

  /// No description provided for @fillScanOrImport.
  ///
  /// In en, this message translates to:
  /// **'Scan or import a new document'**
  String get fillScanOrImport;

  /// No description provided for @pressTitle.
  ///
  /// In en, this message translates to:
  /// **'Review & Finish'**
  String get pressTitle;

  /// No description provided for @pressFieldSummary.
  ///
  /// In en, this message translates to:
  /// **'Field Summary'**
  String get pressFieldSummary;

  /// No description provided for @pressFilled.
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get pressFilled;

  /// No description provided for @pressUnfilled.
  ///
  /// In en, this message translates to:
  /// **'Unfilled'**
  String get pressUnfilled;

  /// No description provided for @pressSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save Draft'**
  String get pressSaveDraft;

  /// No description provided for @pressFlattenAndSign.
  ///
  /// In en, this message translates to:
  /// **'Flatten & Sign (locks the document)'**
  String get pressFlattenAndSign;

  /// No description provided for @pressExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String pressExportFailed(String error);

  /// No description provided for @pressConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Flatten & lock this document?'**
  String get pressConfirmTitle;

  /// No description provided for @pressConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Flattening bakes your entries into a new PDF. The result is permanent — no one can edit it afterward, including you.'**
  String get pressConfirmBody;

  /// No description provided for @pressConfirmLiveFields.
  ///
  /// In en, this message translates to:
  /// **'This document has interactive form fields. Flattening removes them — to keep them editable, choose “Save Draft” instead.'**
  String get pressConfirmLiveFields;

  /// No description provided for @pressConfirmNote.
  ///
  /// In en, this message translates to:
  /// **'Note: a drawn signature here is a visual mark, not a certified digital e-signature.'**
  String get pressConfirmNote;

  /// No description provided for @pressFlattenAndLock.
  ///
  /// In en, this message translates to:
  /// **'Flatten & Lock'**
  String get pressFlattenAndLock;

  /// No description provided for @pressFailed.
  ///
  /// In en, this message translates to:
  /// **'Press failed: {error}'**
  String pressFailed(String error);

  /// No description provided for @pressWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get pressWorking;

  /// No description provided for @pressNotFilled.
  ///
  /// In en, this message translates to:
  /// **'Not filled'**
  String get pressNotFilled;

  /// No description provided for @pressChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked ✓'**
  String get pressChecked;

  /// No description provided for @pressUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Unchecked'**
  String get pressUnchecked;

  /// No description provided for @pressSignatureCaptured.
  ///
  /// In en, this message translates to:
  /// **'Signature captured'**
  String get pressSignatureCaptured;

  /// No description provided for @signTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Here'**
  String get signTitle;

  /// No description provided for @signSwitchInk.
  ///
  /// In en, this message translates to:
  /// **'Switch ink colour'**
  String get signSwitchInk;

  /// No description provided for @signSaveAsMine.
  ///
  /// In en, this message translates to:
  /// **'Save as my signature'**
  String get signSaveAsMine;

  /// No description provided for @signReuseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse across future documents'**
  String get signReuseSubtitle;

  /// No description provided for @signSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get signSaving;

  /// No description provided for @signUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use This Signature'**
  String get signUseThis;

  /// No description provided for @signDrawFirst.
  ///
  /// In en, this message translates to:
  /// **'Please draw your signature first.'**
  String get signDrawFirst;

  /// No description provided for @signDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'My Signature'**
  String get signDefaultLabel;

  /// No description provided for @signSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save signature: {error}'**
  String signSaveFailed(String error);

  /// No description provided for @signaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Signatures'**
  String get signaturesTitle;

  /// No description provided for @signaturesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved signatures yet'**
  String get signaturesEmpty;

  /// No description provided for @signaturesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Signature'**
  String get signaturesAdd;

  /// No description provided for @signaturesDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get signaturesDefaultBadge;

  /// No description provided for @signaturesSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get signaturesSetDefault;

  /// No description provided for @signaturesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Signature?'**
  String get signaturesDeleteTitle;

  /// No description provided for @signaturesDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{label}\"?'**
  String signaturesDeleteBody(String label);

  /// No description provided for @sendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Document'**
  String get sendTitle;

  /// No description provided for @sendBackToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to Library'**
  String get sendBackToLibrary;

  /// No description provided for @sendDocumentSent.
  ///
  /// In en, this message translates to:
  /// **'Document sent!'**
  String get sendDocumentSent;

  /// No description provided for @sendReadyToSend.
  ///
  /// In en, this message translates to:
  /// **'Ready to send'**
  String get sendReadyToSend;

  /// No description provided for @sendSharedBody.
  ///
  /// In en, this message translates to:
  /// **'The pressed PDF has been shared.'**
  String get sendSharedBody;

  /// No description provided for @sendReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Share your pressed PDF via Mail, Messages, AirDrop, or any app.'**
  String get sendReadyBody;

  /// No description provided for @sendOpeningShareSheet.
  ///
  /// In en, this message translates to:
  /// **'Opening share sheet…'**
  String get sendOpeningShareSheet;

  /// No description provided for @sendSharePressed.
  ///
  /// In en, this message translates to:
  /// **'Share Pressed Document'**
  String get sendSharePressed;

  /// No description provided for @sendPreviewDocument.
  ///
  /// In en, this message translates to:
  /// **'Preview Document'**
  String get sendPreviewDocument;

  /// No description provided for @sendShareAgain.
  ///
  /// In en, this message translates to:
  /// **'Share Again'**
  String get sendShareAgain;

  /// No description provided for @sendNotYetPressed.
  ///
  /// In en, this message translates to:
  /// **'Document not yet pressed.'**
  String get sendNotYetPressed;

  /// No description provided for @sendPressedPdfNotFound.
  ///
  /// In en, this message translates to:
  /// **'Pressed PDF file not found.'**
  String get sendPressedPdfNotFound;

  /// Body text attached to the outgoing share. Keep the product name untranslated.
  ///
  /// In en, this message translates to:
  /// **'Signed with Scan Sign Send'**
  String get sendShareMessage;

  /// No description provided for @sendShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String sendShareFailed(String error);

  /// No description provided for @viewerPdfNotFound.
  ///
  /// In en, this message translates to:
  /// **'PDF file not found.'**
  String get viewerPdfNotFound;

  /// No description provided for @viewerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search in document…'**
  String get viewerSearchHint;

  /// No description provided for @viewerSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get viewerSearchTooltip;

  /// No description provided for @viewerNoExportedPdf.
  ///
  /// In en, this message translates to:
  /// **'No exported PDF to view yet'**
  String get viewerNoExportedPdf;

  /// No description provided for @viewerNoExportedPdfBody.
  ///
  /// In en, this message translates to:
  /// **'Fill and export this document (draft or flattened) to view it here.'**
  String get viewerNoExportedPdfBody;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get settingsSectionProfile;

  /// No description provided for @settingsSectionSignatures.
  ///
  /// In en, this message translates to:
  /// **'Signatures'**
  String get settingsSectionSignatures;

  /// No description provided for @settingsSectionSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSectionSecurity;

  /// No description provided for @settingsSectionAi.
  ///
  /// In en, this message translates to:
  /// **'AI Detection (v1.1)'**
  String get settingsSectionAi;

  /// No description provided for @settingsSectionPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get settingsSectionPurchase;

  /// No description provided for @settingsFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get settingsFullName;

  /// No description provided for @settingsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// No description provided for @settingsPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get settingsPhone;

  /// No description provided for @settingsAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get settingsAddress;

  /// No description provided for @settingsCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get settingsCity;

  /// No description provided for @settingsState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get settingsState;

  /// Postal code label. Use the local term (e.g. Code postal, CP, PIN).
  ///
  /// In en, this message translates to:
  /// **'ZIP'**
  String get settingsZip;

  /// No description provided for @settingsCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get settingsCompany;

  /// No description provided for @settingsManageSignatures.
  ///
  /// In en, this message translates to:
  /// **'Manage Signatures'**
  String get settingsManageSignatures;

  /// No description provided for @settingsBiometricLock.
  ///
  /// In en, this message translates to:
  /// **'Biometric App Lock'**
  String get settingsBiometricLock;

  /// No description provided for @settingsBiometricLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require Face ID / fingerprint on launch'**
  String get settingsBiometricLockSubtitle;

  /// No description provided for @settingsNoBiometrics.
  ///
  /// In en, this message translates to:
  /// **'No biometrics enrolled on this device. Set up Face ID / fingerprint first.'**
  String get settingsNoBiometrics;

  /// No description provided for @settingsAiDetection.
  ///
  /// In en, this message translates to:
  /// **'Enhanced AI Detection'**
  String get settingsAiDetection;

  /// No description provided for @settingsAiDetectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses on-device model for smarter field recognition'**
  String get settingsAiDetectionSubtitle;

  /// No description provided for @settingsUnlockFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Unlock Full Access'**
  String get settingsUnlockFullAccess;

  /// No description provided for @settingsUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase — see price'**
  String get settingsUnlockSubtitle;

  /// No description provided for @settingsRestorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get settingsRestorePurchase;

  /// No description provided for @settingsFullAccessUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Full Access Unlocked'**
  String get settingsFullAccessUnlocked;

  /// No description provided for @settingsThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your purchase!'**
  String get settingsThankYou;

  /// No description provided for @settingsCheckingPurchases.
  ///
  /// In en, this message translates to:
  /// **'Checking for previous purchases…'**
  String get settingsCheckingPurchases;

  /// No description provided for @settingsRestored.
  ///
  /// In en, this message translates to:
  /// **'Full access restored. Thank you!'**
  String get settingsRestored;

  /// No description provided for @settingsNoPreviousPurchase.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase found on this account.'**
  String get settingsNoPreviousPurchase;

  /// No description provided for @settingsRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String settingsRestoreFailed(String error);

  /// No description provided for @settingsTapToSet.
  ///
  /// In en, this message translates to:
  /// **'Tap to set'**
  String get settingsTapToSet;

  /// No description provided for @settingsEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit {label}'**
  String settingsEditLabel(String label);

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Full Access'**
  String get paywallTitle;

  /// No description provided for @paywallHeadline.
  ///
  /// In en, this message translates to:
  /// **'Scan Sign Send — Full Access'**
  String get paywallHeadline;

  /// No description provided for @paywallSubhead.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase. No subscription. No account.'**
  String get paywallSubhead;

  /// No description provided for @paywallBenefitUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited documents'**
  String get paywallBenefitUnlimited;

  /// No description provided for @paywallBenefitTemplates.
  ///
  /// In en, this message translates to:
  /// **'Reusable templates'**
  String get paywallBenefitTemplates;

  /// No description provided for @paywallBenefitSignatures.
  ///
  /// In en, this message translates to:
  /// **'Multiple saved signatures'**
  String get paywallBenefitSignatures;

  /// No description provided for @paywallBenefitAutofill.
  ///
  /// In en, this message translates to:
  /// **'Profile autofill'**
  String get paywallBenefitAutofill;

  /// No description provided for @paywallBenefitLock.
  ///
  /// In en, this message translates to:
  /// **'Biometric app lock'**
  String get paywallBenefitLock;

  /// No description provided for @paywallBenefitOffline.
  ///
  /// In en, this message translates to:
  /// **'Always offline — your data stays on device'**
  String get paywallBenefitOffline;

  /// Price comes pre-formatted from the store; never reformat it.
  ///
  /// In en, this message translates to:
  /// **'Unlock — {price}'**
  String paywallUnlockForPrice(String price);

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get paywallRestore;

  /// No description provided for @paywallPaymentDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Payment charged to your App Store / Play account at confirmation.'**
  String get paywallPaymentDisclosure;

  /// No description provided for @paywallNoPreviousPurchase.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase found on this account.'**
  String get paywallNoPreviousPurchase;

  /// intl skeleton for the Library card date. Reorder tokens for the locale; do not translate the letters.
  ///
  /// In en, this message translates to:
  /// **'MMM d, yyyy'**
  String get dateFormatShort;

  /// intl pattern used when writing a date into a form field. Use the locale's conventional order, e.g. dd/MM/yyyy.
  ///
  /// In en, this message translates to:
  /// **'MM/dd/yyyy'**
  String get dateFormatInput;

  /// No description provided for @biometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Scan Sign Send'**
  String get biometricReason;

  /// No description provided for @certTitle.
  ///
  /// In en, this message translates to:
  /// **'Signing Certificate'**
  String get certTitle;

  /// No description provided for @certDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get certDocument;

  /// No description provided for @certSignedOn.
  ///
  /// In en, this message translates to:
  /// **'Signed on'**
  String get certSignedOn;

  /// No description provided for @certMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get certMethod;

  /// No description provided for @certMethodValue.
  ///
  /// In en, this message translates to:
  /// **'On-device (Scan Sign Send)'**
  String get certMethodValue;

  /// No description provided for @certNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get certNote;

  /// No description provided for @certNoteValue.
  ///
  /// In en, this message translates to:
  /// **'Signatures captured locally. No cloud processing.'**
  String get certNoteValue;

  /// intl pattern for the signing-certificate timestamp. Reorder tokens for the locale; use HH:mm where 24-hour time is conventional.
  ///
  /// In en, this message translates to:
  /// **'MMMM d, yyyy — h:mm a'**
  String get certDateFormat;

  /// No description provided for @importErrorUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This PDF couldn\'t be opened. It may be password-protected or damaged.'**
  String get importErrorUnreadable;

  /// No description provided for @importErrorNoPages.
  ///
  /// In en, this message translates to:
  /// **'This PDF has no pages.'**
  String get importErrorNoPages;

  /// No description provided for @pressErrorNoPages.
  ///
  /// In en, this message translates to:
  /// **'This document has no pages to press.'**
  String get pressErrorNoPages;

  /// No description provided for @exportErrorNoPages.
  ///
  /// In en, this message translates to:
  /// **'This document has no pages to export.'**
  String get exportErrorNoPages;

  /// No description provided for @iapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'In-app purchases are unavailable on this device.'**
  String get iapUnavailable;

  /// No description provided for @iapProductNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found in store.'**
  String get iapProductNotFound;

  /// No description provided for @detectFieldsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No fields found} =1{1 field found} other{{count} fields found}}'**
  String detectFieldsFound(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'en',
    'es',
    'fr',
    'hi',
    'pt',
    'ta',
    'te',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'pt':
      return AppLocalizationsPt();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
