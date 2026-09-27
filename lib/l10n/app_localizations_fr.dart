// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Scan Sign Send';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionRemove => 'Retirer';

  @override
  String get actionConfirm => 'Confirmer';

  @override
  String get actionBack => 'Retour';

  @override
  String get actionSkip => 'Passer';

  @override
  String get actionNext => 'Suivant';

  @override
  String get actionOpen => 'Ouvrir';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionShare => 'Partager';

  @override
  String get actionTryAgain => 'Réessayer';

  @override
  String get actionClear => 'Effacer';

  @override
  String get documentFallbackTitle => 'Document';

  @override
  String get errorGenericTitle => 'Une erreur s\'est produite ici.';

  @override
  String get errorGenericBody => 'Revenez en arrière et rouvrez ce document.';

  @override
  String get lockTitle => 'Scan Sign Send est verrouillé';

  @override
  String get lockBody =>
      'Déverrouillez avec Face ID ou votre empreinte digitale pour continuer.';

  @override
  String get lockUnlock => 'Déverrouiller';

  @override
  String get onboardScanTitle => 'Numériser';

  @override
  String get onboardScanBody =>
      'Utilisez votre appareil photo pour numériser n\'importe quel document papier. Les bords sont détectés et l\'image est nettoyée automatiquement.';

  @override
  String get onboardSignTitle => 'Signer';

  @override
  String get onboardSignBody =>
      'Touchez les champs pour les remplir. Ajoutez votre signature du bout du doigt. Vos données ne quittent jamais votre appareil.';

  @override
  String get onboardSendTitle => 'Envoyer';

  @override
  String get onboardSendBody =>
      'Partagez le PDF signé par Mail, Messages, AirDrop ou toute autre application. Achat unique — documents illimités à vie.';

  @override
  String get onboardGetStarted => 'Commencer';

  @override
  String get librarySearchHint => 'Rechercher des documents…';

  @override
  String get libraryTabAll => 'Tous';

  @override
  String get libraryTabDraft => 'Brouillon';

  @override
  String get libraryTabCompleted => 'Terminé';

  @override
  String get libraryTabTemplate => 'Modèle';

  @override
  String get libraryImportTooltip => 'Importer un PDF / une image';

  @override
  String get libraryNewScan => 'Nouvelle numérisation';

  @override
  String get libraryRenameTooltip => 'Renommer';

  @override
  String get libraryUseTemplate => 'Utiliser le modèle';

  @override
  String get libraryDeleteTitle => 'Supprimer le document ?';

  @override
  String libraryDeleteBody(String title) {
    return 'Supprimer « $title » ? Cette action est irréversible.';
  }

  @override
  String get libraryRenameTitle => 'Renommer le document';

  @override
  String get libraryDocumentNameHint => 'Nom du document';

  @override
  String libraryUseTemplateFailed(String error) {
    return 'Impossible d\'utiliser le modèle : $error';
  }

  @override
  String get statusCompleted => 'Terminé';

  @override
  String get statusEditable => 'Modifiable';

  @override
  String get statusTemplate => 'Modèle';

  @override
  String get statusDraft => 'Brouillon';

  @override
  String get emptyDraftsTitle => 'Aucun brouillon';

  @override
  String get emptyDraftsBody =>
      'Lancez une numérisation pour créer un brouillon.';

  @override
  String get emptyPressedTitle => 'Aucun document finalisé';

  @override
  String get emptyPressedBody =>
      'Remplissez et finalisez un brouillon pour le voir ici.';

  @override
  String get emptyTemplatesTitle => 'Aucun modèle pour l\'instant';

  @override
  String get emptyTemplatesBody =>
      'Lorsque vous finalisez un document, un modèle\nréutilisable est enregistré ici automatiquement.';

  @override
  String get emptyAllTitle => 'Aucun document pour l\'instant';

  @override
  String get emptyAllBody =>
      'Touchez « Nouvelle numérisation » pour commencer.\nNumériser → Signer → Envoyer.';

  @override
  String searchNoResults(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get captureTitle => 'Numériser un document';

  @override
  String get captureLaunching => 'Ouverture du scanner…';

  @override
  String get captureSavingPages => 'Enregistrement des pages…';

  @override
  String get captureImporting => 'Importation…';

  @override
  String captureScanFailed(String error) {
    return 'Échec de la numérisation : $error';
  }

  @override
  String captureImportFailed(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get captureScanWithCamera => 'Numériser avec l\'appareil photo';

  @override
  String get captureImportPdfImage => 'Importer un PDF / une image';

  @override
  String get captureUpTo20Pages => 'Jusqu\'à 20 pages par numérisation';

  @override
  String captureDefaultDocumentName(String date) {
    return 'Document $date';
  }

  @override
  String get reviewTitle => 'Vérifier les pages';

  @override
  String get reviewSaveOrder => 'Enregistrer l\'ordre';

  @override
  String get reviewNoPagesFound => 'Aucune page trouvée.';

  @override
  String get reviewDetectFields => 'Détecter les champs →';

  @override
  String reviewRotateFailed(String error) {
    return 'Échec de la rotation : $error';
  }

  @override
  String get reviewDeletePageTitle => 'Supprimer la page ?';

  @override
  String reviewDeletePageBody(int number) {
    return 'Retirer la page $number ?';
  }

  @override
  String reviewPageOf(int current, int total) {
    return 'Page $current sur $total';
  }

  @override
  String get reviewRotateTooltip => 'Pivoter de 90°';

  @override
  String get reviewDeletePageTooltip => 'Supprimer la page';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterEnhanced => 'Amélioré';

  @override
  String get filterBw => 'N&B';

  @override
  String get detectTitle => 'Détecter les champs';

  @override
  String get detectFormFieldsFoundTitle => 'Champs de formulaire détectés';

  @override
  String get detectFormFieldsFoundBody =>
      'Ce PDF contient déjà des champs de formulaire.\nVous pouvez ajouter vos propres champs manuellement ou passer directement au remplissage.';

  @override
  String get detectContinueToFill => 'Passer au remplissage';

  @override
  String get detectConfirmAll => 'Tout confirmer';

  @override
  String get detectStarting => 'Démarrage…';

  @override
  String get detectReading => 'Lecture de votre document…';

  @override
  String detectAnalysingPage(int current, int total) {
    return 'Analyse de la page $current sur $total…';
  }

  @override
  String get detectUnknownError => 'Erreur inconnue';

  @override
  String get detectOnDeviceNote =>
      'Tous les traitements ont lieu sur votre appareil.';

  @override
  String get detectFailed => 'Échec de la détection';

  @override
  String get detectNoPages => 'Aucune page.';

  @override
  String get detectSkipToFill => 'Passer au remplissage →';

  @override
  String detectFillFieldsCount(int count) {
    return 'Remplir les champs ($count) →';
  }

  @override
  String get detectBadgeText => 'TEXTE';

  @override
  String get detectBadgeDate => 'DATE';

  @override
  String get detectBadgeCheck => 'COCHE';

  @override
  String get detectBadgeSign => 'SIGN.';

  @override
  String get detectEditField => 'Modifier le champ';

  @override
  String get detectFieldType => 'Type';

  @override
  String get detectFieldLabelHint => 'Libellé / nom du champ';

  @override
  String get detectRequiredField => 'Champ obligatoire';

  @override
  String get detectAddField => 'Ajouter un champ';

  @override
  String detectAddTypedField(String type) {
    return 'Ajouter un champ $type';
  }

  @override
  String get fieldTypeText => 'Texte';

  @override
  String get fieldTypeDate => 'Date';

  @override
  String get fieldTypeCheckbox => 'Case à cocher';

  @override
  String get fieldTypeSignature => 'Signature';

  @override
  String get fieldTypeCheckShort => 'Coche';

  @override
  String get fieldTypeSignShort => 'Signer';

  @override
  String get fillFallbackTitle => 'Remplir le document';

  @override
  String get fillEditFields => 'Modifier les champs';

  @override
  String get fillReviewAndFinish => 'Vérifier et terminer';

  @override
  String get fillNoPages => 'Ce document ne contient aucune page.';

  @override
  String get fillTextFieldFallback => 'Champ de texte';

  @override
  String get fillEnterValueHint => 'Saisissez une valeur…';

  @override
  String get fillChipName => 'Nom';

  @override
  String get fillChipEmail => 'E-mail';

  @override
  String get fillChipPhone => 'Téléphone';

  @override
  String get fillChipAddress => 'Adresse';

  @override
  String get fillChipCompany => 'Entreprise';

  @override
  String get fillChipToday => 'Aujourd\'hui';

  @override
  String get fillTapToFill => 'Touchez pour remplir…';

  @override
  String get fillTapForDate => 'Touchez pour la date…';

  @override
  String get fillTapToCheck => 'Touchez pour cocher';

  @override
  String get fillTapToSign => 'Touchez pour signer…';

  @override
  String get fillPdfNotFound => 'PDF introuvable';

  @override
  String get fillImageNotFound => 'Image introuvable';

  @override
  String get fillScanOrImport => 'Numérisez ou importez un nouveau document';

  @override
  String get pressTitle => 'Vérifier et terminer';

  @override
  String get pressFieldSummary => 'Récapitulatif des champs';

  @override
  String get pressFilled => 'Rempli';

  @override
  String get pressUnfilled => 'Non rempli';

  @override
  String get pressSaveDraft => 'Enregistrer le brouillon';

  @override
  String get pressFlattenAndSign =>
      'Aplatir et signer (verrouille le document)';

  @override
  String pressExportFailed(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String get pressConfirmTitle => 'Aplatir et verrouiller ce document ?';

  @override
  String get pressConfirmBody =>
      'L\'aplatissement intègre vos saisies dans un nouveau PDF. Le résultat est définitif — plus personne ne pourra le modifier, vous y compris.';

  @override
  String get pressConfirmLiveFields =>
      'Ce document comporte des champs de formulaire interactifs. L\'aplatissement les supprime — pour les garder modifiables, choisissez plutôt « Enregistrer le brouillon ».';

  @override
  String get pressConfirmNote =>
      'Remarque : une signature tracée ici est une marque visuelle, et non une signature électronique certifiée.';

  @override
  String get pressFlattenAndLock => 'Aplatir et verrouiller';

  @override
  String pressFailed(String error) {
    return 'Échec de la finalisation : $error';
  }

  @override
  String get pressWorking => 'Traitement…';

  @override
  String get pressNotFilled => 'Non rempli';

  @override
  String get pressChecked => 'Coché ✓';

  @override
  String get pressUnchecked => 'Non coché';

  @override
  String get pressSignatureCaptured => 'Signature enregistrée';

  @override
  String get signTitle => 'Signez ici';

  @override
  String get signSwitchInk => 'Changer la couleur d\'encre';

  @override
  String get signSaveAsMine => 'Enregistrer comme ma signature';

  @override
  String get signReuseSubtitle => 'Réutiliser pour les prochains documents';

  @override
  String get signSaving => 'Enregistrement…';

  @override
  String get signUseThis => 'Utiliser cette signature';

  @override
  String get signDrawFirst => 'Veuillez d\'abord tracer votre signature.';

  @override
  String get signDefaultLabel => 'Ma signature';

  @override
  String signSaveFailed(String error) {
    return 'Échec de l\'enregistrement de la signature : $error';
  }

  @override
  String get signaturesTitle => 'Signatures enregistrées';

  @override
  String get signaturesEmpty => 'Aucune signature enregistrée';

  @override
  String get signaturesAdd => 'Ajouter une signature';

  @override
  String get signaturesDefaultBadge => 'Par défaut';

  @override
  String get signaturesSetDefault => 'Définir par défaut';

  @override
  String get signaturesDeleteTitle => 'Supprimer la signature ?';

  @override
  String signaturesDeleteBody(String label) {
    return 'Supprimer « $label » ?';
  }

  @override
  String get sendTitle => 'Envoyer le document';

  @override
  String get sendBackToLibrary => 'Retour à la bibliothèque';

  @override
  String get sendDocumentSent => 'Document envoyé !';

  @override
  String get sendReadyToSend => 'Prêt à envoyer';

  @override
  String get sendSharedBody => 'Le PDF finalisé a été partagé.';

  @override
  String get sendReadyBody =>
      'Partagez votre PDF finalisé par Mail, Messages, AirDrop ou toute autre application.';

  @override
  String get sendOpeningShareSheet => 'Ouverture du partage…';

  @override
  String get sendSharePressed => 'Partager le document finalisé';

  @override
  String get sendPreviewDocument => 'Aperçu du document';

  @override
  String get sendShareAgain => 'Partager à nouveau';

  @override
  String get sendNotYetPressed => 'Document pas encore finalisé.';

  @override
  String get sendPressedPdfNotFound => 'Fichier PDF finalisé introuvable.';

  @override
  String get sendShareMessage => 'Signé avec Scan Sign Send';

  @override
  String sendShareFailed(String error) {
    return 'Échec du partage : $error';
  }

  @override
  String get viewerPdfNotFound => 'Fichier PDF introuvable.';

  @override
  String get viewerSearchHint => 'Rechercher dans le document…';

  @override
  String get viewerSearchTooltip => 'Rechercher';

  @override
  String get viewerNoExportedPdf => 'Aucun PDF exporté à afficher';

  @override
  String get viewerNoExportedPdfBody =>
      'Remplissez et exportez ce document (brouillon ou aplati) pour l\'afficher ici.';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsSectionProfile => 'Mon profil';

  @override
  String get settingsSectionSignatures => 'Signatures';

  @override
  String get settingsSectionSecurity => 'Sécurité';

  @override
  String get settingsSectionAi => 'Détection IA (v1.1)';

  @override
  String get settingsSectionPurchase => 'Achat';

  @override
  String get settingsFullName => 'Nom complet';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsPhone => 'Téléphone';

  @override
  String get settingsAddress => 'Adresse';

  @override
  String get settingsCity => 'Ville';

  @override
  String get settingsState => 'Région';

  @override
  String get settingsZip => 'Code postal';

  @override
  String get settingsCompany => 'Entreprise';

  @override
  String get settingsManageSignatures => 'Gérer les signatures';

  @override
  String get settingsBiometricLock => 'Verrouillage biométrique';

  @override
  String get settingsBiometricLockSubtitle =>
      'Exiger Face ID / empreinte au lancement';

  @override
  String get settingsNoBiometrics =>
      'Aucune donnée biométrique enregistrée sur cet appareil. Configurez d\'abord Face ID / l\'empreinte digitale.';

  @override
  String get settingsAiDetection => 'Détection IA améliorée';

  @override
  String get settingsAiDetectionSubtitle =>
      'Utilise un modèle embarqué pour mieux reconnaître les champs';

  @override
  String get settingsUnlockFullAccess => 'Débloquer l\'accès complet';

  @override
  String get settingsUnlockSubtitle => 'Achat unique — voir le prix';

  @override
  String get settingsRestorePurchase => 'Restaurer l\'achat';

  @override
  String get settingsFullAccessUnlocked => 'Accès complet débloqué';

  @override
  String get settingsThankYou => 'Merci pour votre achat !';

  @override
  String get settingsCheckingPurchases => 'Recherche d\'achats antérieurs…';

  @override
  String get settingsRestored => 'Accès complet restauré. Merci !';

  @override
  String get settingsNoPreviousPurchase =>
      'Aucun achat antérieur trouvé sur ce compte.';

  @override
  String settingsRestoreFailed(String error) {
    return 'Échec de la restauration : $error';
  }

  @override
  String get settingsTapToSet => 'Touchez pour définir';

  @override
  String settingsEditLabel(String label) {
    return 'Modifier : $label';
  }

  @override
  String get paywallTitle => 'Débloquer l\'accès complet';

  @override
  String get paywallHeadline => 'Scan Sign Send — Accès complet';

  @override
  String get paywallSubhead => 'Achat unique. Sans abonnement. Sans compte.';

  @override
  String get paywallBenefitUnlimited => 'Documents illimités';

  @override
  String get paywallBenefitTemplates => 'Modèles réutilisables';

  @override
  String get paywallBenefitSignatures => 'Plusieurs signatures enregistrées';

  @override
  String get paywallBenefitAutofill => 'Remplissage automatique du profil';

  @override
  String get paywallBenefitLock => 'Verrouillage biométrique';

  @override
  String get paywallBenefitOffline =>
      'Toujours hors ligne — vos données restent sur l\'appareil';

  @override
  String paywallUnlockForPrice(String price) {
    return 'Débloquer — $price';
  }

  @override
  String get paywallRestore => 'Restaurer l\'achat';

  @override
  String get paywallPaymentDisclosure =>
      'Paiement débité de votre compte App Store / Play à la confirmation.';

  @override
  String get paywallNoPreviousPurchase =>
      'Aucun achat antérieur trouvé sur ce compte.';

  @override
  String get dateFormatShort => 'd MMM yyyy';

  @override
  String get dateFormatInput => 'dd/MM/yyyy';

  @override
  String get biometricReason => 'Déverrouiller Scan Sign Send';

  @override
  String get certTitle => 'Certificat de signature';

  @override
  String get certDocument => 'Document';

  @override
  String get certSignedOn => 'Signé le';

  @override
  String get certMethod => 'Méthode';

  @override
  String get certMethodValue => 'Sur l\'appareil (Scan Sign Send)';

  @override
  String get certNote => 'Remarque';

  @override
  String get certNoteValue =>
      'Signatures capturées localement. Aucun traitement dans le cloud.';

  @override
  String get certDateFormat => 'd MMMM yyyy — HH:mm';

  @override
  String get importErrorUnreadable =>
      'Ce PDF n\'a pas pu être ouvert. Il est peut-être protégé par mot de passe ou endommagé.';

  @override
  String get importErrorNoPages => 'Ce PDF ne contient aucune page.';

  @override
  String get pressErrorNoPages => 'Ce document n\'a aucune page à finaliser.';

  @override
  String get exportErrorNoPages => 'Ce document n\'a aucune page à exporter.';

  @override
  String get iapUnavailable =>
      'Les achats intégrés sont indisponibles sur cet appareil.';

  @override
  String get iapProductNotFound => 'Produit introuvable dans la boutique.';

  @override
  String detectFieldsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count champs trouvés',
      one: '1 champ trouvé',
      zero: 'Aucun champ trouvé',
    );
    return '$_temp0';
  }

  @override
  String detectFillFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remplir $count champs →',
      one: 'Remplir 1 champ →',
    );
    return '$_temp0';
  }

  @override
  String get detectPinchHint =>
      'Touchez un outil ci-dessous pour ajouter un champ · touchez un champ pour le sélectionner';

  @override
  String get importErrorUnreadableImage =>
      'Impossible d’ouvrir cette image. Essayez une photo JPEG, PNG ou HEIC.';

  @override
  String get iapErrorUnavailable =>
      'Les achats ne sont pas disponibles sur cet appareil pour le moment.';

  @override
  String get iapErrorProductNotFound =>
      'Impossible de joindre la boutique. Veuillez réessayer plus tard.';

  @override
  String get iapErrorPurchaseFailed =>
      'L’achat n’a pas pu aboutir. Aucun montant ne vous a été débité.';

  @override
  String get settingsBackupTitle => 'Inclure dans la sauvegarde de l’appareil';

  @override
  String get settingsBackupSubtitleIos =>
      'Désactivé : documents et signatures restent uniquement sur cet iPhone. Activé : ils sont inclus dans votre sauvegarde iCloud.';

  @override
  String get settingsBackupSubtitleAndroid =>
      'Désactivé : documents et signatures restent uniquement sur ce téléphone. Activé : ils sont inclus dans votre sauvegarde Google chiffrée et lors du passage à un nouveau téléphone.';

  @override
  String get fieldTypeRadio => 'Bouton radio';

  @override
  String get fieldTypeRadioShort => 'Radio';

  @override
  String get fieldTypeInitials => 'Initiales';

  @override
  String get fillTapToInitial => 'Touchez pour parapher';

  @override
  String get signInitialsTitle => 'Dessinez vos initiales';

  @override
  String get pressRadioSelected => 'Sélectionné';

  @override
  String get pressRadioNotSelected => 'Non sélectionné';

  @override
  String get detectSelectedHint =>
      'Glissez pour déplacer · pincez ou tirez le coin pour redimensionner · touchez à nouveau pour modifier';

  @override
  String get detectRadioAddChoiceHint =>
      'Touchez à nouveau Radio pour ajouter un autre choix à cette question';

  @override
  String get detectFieldDeleted => 'Champ supprimé';

  @override
  String get actionUndo => 'Annuler';

  @override
  String get detectFormFieldLocked =>
      'Ce champ fait partie du formulaire du PDF. Remplissez-le à l’étape suivante.';

  @override
  String get libraryImport => 'Importer';

  @override
  String get settingsForgetLearned => 'Oublier les champs appris';

  @override
  String get settingsForgetLearnedSubtitle =>
      'La détection apprend des champs que vous ajoutez, modifiez et supprimez, uniquement sur cet appareil.';

  @override
  String get settingsForgetLearnedDone => 'Champs appris effacés';

  @override
  String paywallReasonAllowance(int count) {
    return 'Vous avez utilisé vos $count documents gratuits.';
  }

  @override
  String paywallReasonPages(int count) {
    return 'Les documents gratuits peuvent contenir jusqu’à $count pages.';
  }

  @override
  String get paywallBenefitAnyLength => 'Documents de toute longueur';

  @override
  String pageLimitTitle(int count) {
    return 'Documents gratuits : jusqu’à $count pages';
  }

  @override
  String pageLimitBody(int pages, int limit) {
    return 'Ce document contient $pages pages. Débloquez l’accès complet pour des documents de toute longueur, ou gardez les $limit premières pages.';
  }

  @override
  String pageLimitKeepFirst(int count) {
    return 'Garder les $count premières pages';
  }

  @override
  String pressFreeRemaining(int left, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other:
          'Terminer utilise 1 de vos $total documents gratuits ($left restants)',
      one: 'Terminer utilise votre dernier document gratuit',
      zero: 'Vous avez utilisé vos $total documents gratuits',
    );
    return '$_temp0';
  }
}
