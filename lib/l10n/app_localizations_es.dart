// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Scan Sign Send';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionRemove => 'Quitar';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get actionBack => 'Atrás';

  @override
  String get actionSkip => 'Omitir';

  @override
  String get actionNext => 'Siguiente';

  @override
  String get actionOpen => 'Abrir';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionShare => 'Compartir';

  @override
  String get actionTryAgain => 'Reintentar';

  @override
  String get actionClear => 'Borrar';

  @override
  String get documentFallbackTitle => 'Documento';

  @override
  String get errorGenericTitle => 'Algo ha salido mal aquí.';

  @override
  String get errorGenericBody => 'Vuelve atrás y abre este documento de nuevo.';

  @override
  String get lockTitle => 'Scan Sign Send está bloqueado';

  @override
  String get lockBody =>
      'Desbloquea con Face ID o tu huella digital para continuar.';

  @override
  String get lockUnlock => 'Desbloquear';

  @override
  String get onboardScanTitle => 'Escanear';

  @override
  String get onboardScanBody =>
      'Usa la cámara para escanear cualquier documento en papel. Detecta los bordes y limpia la imagen automáticamente.';

  @override
  String get onboardSignTitle => 'Firmar';

  @override
  String get onboardSignBody =>
      'Toca los campos para rellenarlos. Añade tu firma con el dedo. Tus datos nunca salen de tu dispositivo.';

  @override
  String get onboardSendTitle => 'Enviar';

  @override
  String get onboardSendBody =>
      'Comparte el PDF firmado por correo, mensajería o cualquier app. Pago único: documentos ilimitados para siempre.';

  @override
  String get onboardGetStarted => 'Empezar';

  @override
  String get librarySearchHint => 'Buscar documentos…';

  @override
  String get libraryTabAll => 'Todos';

  @override
  String get libraryTabDraft => 'Borrador';

  @override
  String get libraryTabCompleted => 'Completado';

  @override
  String get libraryTabTemplate => 'Plantilla';

  @override
  String get libraryImportTooltip => 'Importar PDF / imagen';

  @override
  String get libraryNewScan => 'Nuevo escaneo';

  @override
  String get libraryRenameTooltip => 'Renombrar';

  @override
  String get libraryUseTemplate => 'Usar plantilla';

  @override
  String get libraryDeleteTitle => '¿Eliminar el documento?';

  @override
  String libraryDeleteBody(String title) {
    return '¿Eliminar «$title»? Esta acción no se puede deshacer.';
  }

  @override
  String get libraryRenameTitle => 'Renombrar documento';

  @override
  String get libraryDocumentNameHint => 'Nombre del documento';

  @override
  String libraryUseTemplateFailed(String error) {
    return 'No se pudo usar la plantilla: $error';
  }

  @override
  String get statusCompleted => 'Completado';

  @override
  String get statusEditable => 'Editable';

  @override
  String get statusTemplate => 'Plantilla';

  @override
  String get statusDraft => 'Borrador';

  @override
  String get emptyDraftsTitle => 'Sin borradores';

  @override
  String get emptyDraftsBody => 'Inicia un escaneo para crear un borrador.';

  @override
  String get emptyPressedTitle => 'No hay documentos completados';

  @override
  String get emptyPressedBody => 'Completa un borrador para verlo aquí.';

  @override
  String get emptyTemplatesTitle => 'Aún no hay plantillas';

  @override
  String get emptyTemplatesBody =>
      'Al terminar un documento, toca\n«Guardar como plantilla» para reutilizar el formulario.';

  @override
  String get emptyAllTitle => 'Aún no hay documentos';

  @override
  String get emptyAllBody =>
      'Toca «Nuevo escaneo» para empezar.\nEscanear → Firmar → Enviar.';

  @override
  String searchNoResults(String query) {
    return 'Sin resultados para «$query»';
  }

  @override
  String get captureTitle => 'Escanear documento';

  @override
  String get captureLaunching => 'Abriendo el escáner…';

  @override
  String get captureSavingPages => 'Guardando páginas…';

  @override
  String get captureImporting => 'Importando…';

  @override
  String captureScanFailed(String error) {
    return 'Error al escanear: $error';
  }

  @override
  String captureImportFailed(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get captureScanWithCamera => 'Escanear con la cámara';

  @override
  String get captureImportPdfImage => 'Importar PDF / imagen';

  @override
  String get captureUpTo20Pages => 'Hasta 20 páginas por escaneo';

  @override
  String captureDefaultDocumentName(String date) {
    return 'Documento $date';
  }

  @override
  String get reviewTitle => 'Revisar páginas';

  @override
  String get reviewSaveOrder => 'Guardar orden';

  @override
  String get reviewNoPagesFound => 'No se han encontrado páginas.';

  @override
  String get reviewDetectFields => 'Detectar campos →';

  @override
  String reviewRotateFailed(String error) {
    return 'Error al girar: $error';
  }

  @override
  String get reviewDeletePageTitle => '¿Eliminar la página?';

  @override
  String reviewDeletePageBody(int number) {
    return '¿Quitar la página $number?';
  }

  @override
  String reviewPageOf(int current, int total) {
    return 'Página $current de $total';
  }

  @override
  String get reviewRotateTooltip => 'Girar 90°';

  @override
  String get reviewDeletePageTooltip => 'Eliminar página';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterEnhanced => 'Mejorado';

  @override
  String get filterBw => 'B/N';

  @override
  String get detectTitle => 'Detectar campos';

  @override
  String get detectFormFieldsFoundTitle => 'Campos de formulario detectados';

  @override
  String get detectFormFieldsFoundBody =>
      'Este PDF ya contiene campos de formulario.\nPuedes añadir tus propios campos manualmente o pasar directamente a rellenarlo.';

  @override
  String get detectContinueToFill => 'Continuar y rellenar';

  @override
  String get detectConfirmAll => 'Confirmar todo';

  @override
  String get detectStarting => 'Iniciando…';

  @override
  String get detectReading => 'Leyendo tu documento…';

  @override
  String detectAnalysingPage(int current, int total) {
    return 'Analizando la página $current de $total…';
  }

  @override
  String get detectUnknownError => 'Error desconocido';

  @override
  String get detectOnDeviceNote =>
      'Todo el procesamiento ocurre en el dispositivo.';

  @override
  String get detectFailed => 'Error de detección';

  @override
  String get detectNoPages => 'Sin páginas.';

  @override
  String get detectSkipToFill => 'Ir a rellenar →';

  @override
  String detectFillFieldsCount(int count) {
    return 'Rellenar campos ($count) →';
  }

  @override
  String get detectBadgeText => 'TEXTO';

  @override
  String get detectBadgeDate => 'FECHA';

  @override
  String get detectBadgeCheck => 'CASILLA';

  @override
  String get detectBadgeSign => 'FIRMA';

  @override
  String get detectEditField => 'Editar campo';

  @override
  String get detectFieldType => 'Tipo';

  @override
  String get detectFieldLabelHint => 'Etiqueta / nombre del campo';

  @override
  String get detectRequiredField => 'Campo obligatorio';

  @override
  String get detectAddField => 'Añadir campo';

  @override
  String detectAddTypedField(String type) {
    return 'Añadir campo de $type';
  }

  @override
  String get fieldTypeText => 'Texto';

  @override
  String get fieldTypeDate => 'Fecha';

  @override
  String get fieldTypeCheckbox => 'Casilla';

  @override
  String get fieldTypeSignature => 'Firma';

  @override
  String get fieldTypeCheckShort => 'Casilla';

  @override
  String get fieldTypeSignShort => 'Firma';

  @override
  String get fillFallbackTitle => 'Rellenar documento';

  @override
  String get fillEditFields => 'Editar campos';

  @override
  String get fillReviewAndFinish => 'Revisar y finalizar';

  @override
  String get fillNoPages => 'Este documento no tiene páginas.';

  @override
  String get fillTextFieldFallback => 'Campo de texto';

  @override
  String get fillEnterValueHint => 'Introduce un valor…';

  @override
  String get fillChipName => 'Nombre';

  @override
  String get fillChipEmail => 'Correo';

  @override
  String get fillChipPhone => 'Teléfono';

  @override
  String get fillChipAddress => 'Dirección';

  @override
  String get fillChipCompany => 'Empresa';

  @override
  String get fillChipToday => 'Hoy';

  @override
  String get fillTapToFill => 'Toca para rellenar…';

  @override
  String get fillTapForDate => 'Toca para la fecha…';

  @override
  String get fillTapToCheck => 'Toca para marcar';

  @override
  String get fillTapToSign => 'Toca para firmar…';

  @override
  String get fillPdfNotFound => 'PDF no encontrado';

  @override
  String get fillImageNotFound => 'Imagen no encontrada';

  @override
  String get fillScanOrImport => 'Escanea o importa un documento nuevo';

  @override
  String get pressTitle => 'Revisar y finalizar';

  @override
  String get pressFieldSummary => 'Resumen de campos';

  @override
  String get pressFilled => 'Rellenado';

  @override
  String get pressUnfilled => 'Sin rellenar';

  @override
  String get pressSaveDraft => 'Guardar borrador';

  @override
  String get pressFlattenAndSign => 'Aplanar y firmar (bloquea el documento)';

  @override
  String pressExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get pressConfirmTitle => '¿Aplanar y bloquear este documento?';

  @override
  String get pressConfirmBody =>
      'Al aplanar, tus datos se integran en un PDF nuevo. El resultado es permanente: nadie podrá editarlo después, ni siquiera tú.';

  @override
  String get pressConfirmLiveFields =>
      'Este documento tiene campos de formulario interactivos. Al aplanarlo se eliminan; para mantenerlos editables, elige «Guardar borrador».';

  @override
  String get pressConfirmNote =>
      'Nota: una firma trazada aquí es una marca visual, no una firma electrónica certificada.';

  @override
  String get pressFlattenAndLock => 'Aplanar y bloquear';

  @override
  String get pressNoFieldsTitle => 'Aún no hay campos';

  @override
  String get pressNoFieldsBody =>
      'Añade al menos un campo para rellenar o firmar antes de terminar.';

  @override
  String get pressAddFields => 'Añadir campos';

  @override
  String pressFailed(String error) {
    return 'No se pudo completar el documento: $error';
  }

  @override
  String get pressWorking => 'Procesando…';

  @override
  String get pressNotFilled => 'Sin rellenar';

  @override
  String get pressChecked => 'Marcado ✓';

  @override
  String get pressUnchecked => 'Sin marcar';

  @override
  String get pressSignatureCaptured => 'Firma capturada';

  @override
  String get signTitle => 'Firma aquí';

  @override
  String get signSwitchInk => 'Cambiar color de tinta';

  @override
  String get signSaveAsMine => 'Guardar como mi firma';

  @override
  String get signReuseSubtitle => 'Reutilizar en futuros documentos';

  @override
  String get signSaving => 'Guardando…';

  @override
  String get signUseThis => 'Usar esta firma';

  @override
  String get signDrawFirst => 'Primero traza tu firma.';

  @override
  String get signDefaultLabel => 'Mi firma';

  @override
  String signSaveFailed(String error) {
    return 'No se pudo guardar la firma: $error';
  }

  @override
  String get signaturesTitle => 'Firmas guardadas';

  @override
  String get signaturesEmpty => 'Aún no hay firmas guardadas';

  @override
  String get signaturesAdd => 'Añadir firma';

  @override
  String get signaturesDefaultBadge => 'Predeterminada';

  @override
  String get signaturesSetDefault => 'Establecer como predeterminada';

  @override
  String get signaturesDeleteTitle => '¿Eliminar la firma?';

  @override
  String signaturesDeleteBody(String label) {
    return '¿Eliminar «$label»?';
  }

  @override
  String get sendTitle => 'Enviar documento';

  @override
  String get sendBackToLibrary => 'Volver a la biblioteca';

  @override
  String get sendDocumentSent => '¡Documento enviado!';

  @override
  String get sendReadyToSend => 'Listo para enviar';

  @override
  String get sendSharedBody => 'Tu PDF se ha compartido.';

  @override
  String get sendReadyBody =>
      'Comparte tu PDF por correo, mensajería o cualquier app.';

  @override
  String get sendOpeningShareSheet => 'Abriendo el menú de compartir…';

  @override
  String get sendSharePressed => 'Compartir PDF';

  @override
  String get sendPreviewDocument => 'Previsualizar documento';

  @override
  String get sendShareAgain => 'Compartir de nuevo';

  @override
  String get sendNotYetPressed => 'Este documento aún no está completado.';

  @override
  String get sendPressedPdfNotFound => 'No se encuentra el PDF completado.';

  @override
  String get sendShareMessage => 'Firmado con Scan Sign Send';

  @override
  String sendShareFailed(String error) {
    return 'Error al compartir: $error';
  }

  @override
  String get viewerPdfNotFound => 'No se encuentra el archivo PDF.';

  @override
  String get viewerSearchHint => 'Buscar en el documento…';

  @override
  String get viewerSearchTooltip => 'Buscar';

  @override
  String get viewerNoExportedPdf => 'Todavía no hay ningún PDF exportado';

  @override
  String get viewerNoExportedPdfBody =>
      'Rellena y exporta este documento (borrador o aplanado) para verlo aquí.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionProfile => 'Mi perfil';

  @override
  String get settingsSectionSignatures => 'Firmas';

  @override
  String get settingsSectionSecurity => 'Seguridad';

  @override
  String get settingsSectionAi => 'Detección con IA (v1.1)';

  @override
  String get settingsSectionPurchase => 'Compra';

  @override
  String get settingsFullName => 'Nombre completo';

  @override
  String get settingsEmail => 'Correo electrónico';

  @override
  String get settingsPhone => 'Teléfono';

  @override
  String get settingsAddress => 'Dirección';

  @override
  String get settingsCity => 'Ciudad';

  @override
  String get settingsState => 'Provincia';

  @override
  String get settingsZip => 'Código postal';

  @override
  String get settingsCompany => 'Empresa';

  @override
  String get settingsManageSignatures => 'Gestionar firmas';

  @override
  String get settingsBiometricLock => 'Bloqueo biométrico';

  @override
  String get settingsBiometricLockSubtitle => 'Pedir Face ID / huella al abrir';

  @override
  String get settingsNoBiometrics =>
      'No hay datos biométricos registrados en este dispositivo. Configura primero Face ID o la huella digital.';

  @override
  String get settingsAiDetection => 'Detección con IA mejorada';

  @override
  String get settingsAiDetectionSubtitle =>
      'Usa un modelo en el dispositivo para reconocer mejor los campos';

  @override
  String get settingsUnlockFullAccess => 'Desbloquear Ilimitado';

  @override
  String get settingsUnlockSubtitle => 'Pago único — ver precio';

  @override
  String get settingsRestorePurchase => 'Restaurar compra';

  @override
  String get settingsSectionSupport => 'Soporte';

  @override
  String get settingsRateApp => 'Valorar Scan Sign Send';

  @override
  String get settingsRateAppSubtitle => 'Deja una valoración o una reseña';

  @override
  String get settingsRateAppFailed =>
      'No se pudo abrir la tienda. Inténtalo más tarde.';

  @override
  String get settingsFullAccessUnlocked => 'Ilimitado desbloqueado';

  @override
  String get settingsThankYou => '¡Gracias por tu compra!';

  @override
  String get settingsCheckingPurchases => 'Buscando compras anteriores…';

  @override
  String get settingsRestored => 'Ilimitado restaurado. ¡Gracias!';

  @override
  String get settingsNoPreviousPurchase =>
      'No se ha encontrado ninguna compra anterior en esta cuenta.';

  @override
  String settingsRestoreFailed(String error) {
    return 'Error al restaurar: $error';
  }

  @override
  String get settingsTapToSet => 'Toca para definir';

  @override
  String settingsEditLabel(String label) {
    return 'Editar $label';
  }

  @override
  String get paywallTitle => 'Desbloquear Ilimitado';

  @override
  String get paywallHeadline => 'Scan Sign Send — Ilimitado';

  @override
  String get paywallSubhead => 'Pago único. Sin suscripción. Sin cuenta.';

  @override
  String get paywallBenefitUnlimited => 'Documentos ilimitados';

  @override
  String get paywallBenefitTemplates => 'Plantillas reutilizables';

  @override
  String get paywallBenefitSignatures => 'Varias firmas guardadas';

  @override
  String get paywallBenefitAutofill => 'Autorrelleno del perfil';

  @override
  String get paywallBenefitLock => 'Bloqueo biométrico';

  @override
  String get paywallBenefitOffline =>
      'Siempre sin conexión: tus datos se quedan en el dispositivo';

  @override
  String paywallUnlockForPrice(String price) {
    return 'Desbloquear — $price';
  }

  @override
  String get paywallRestore => 'Restaurar compra';

  @override
  String get paywallPaymentDisclosure =>
      'El pago se cargará en tu cuenta de App Store / Play al confirmar.';

  @override
  String get paywallNoPreviousPurchase =>
      'No se ha encontrado ninguna compra anterior en esta cuenta.';

  @override
  String get dateFormatShort => 'd MMM yyyy';

  @override
  String get dateFormatInput => 'dd/MM/yyyy';

  @override
  String get biometricReason => 'Desbloquear Scan Sign Send';

  @override
  String get certTitle => 'Certificado de firma';

  @override
  String get certDocument => 'Documento';

  @override
  String get certSignedOn => 'Firmado el';

  @override
  String get certMethod => 'Método';

  @override
  String get certMethodValue => 'En el dispositivo (Scan Sign Send)';

  @override
  String get certNote => 'Nota';

  @override
  String get certNoteValue =>
      'Firmas capturadas localmente. Sin procesamiento en la nube.';

  @override
  String get certDateFormat => 'd \'de\' MMMM \'de\' yyyy — HH:mm';

  @override
  String get importErrorUnreadable =>
      'No se ha podido abrir este PDF. Puede estar protegido con contraseña o dañado.';

  @override
  String get importErrorNoPages => 'Este PDF no tiene páginas.';

  @override
  String get pressErrorNoPages =>
      'Este documento no tiene páginas que finalizar.';

  @override
  String get exportErrorNoPages =>
      'Este documento no tiene páginas que exportar.';

  @override
  String get iapUnavailable =>
      'Las compras dentro de la app no están disponibles en este dispositivo.';

  @override
  String get iapProductNotFound => 'Producto no encontrado en la tienda.';

  @override
  String detectFieldsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos encontrados',
      one: '1 campo encontrado',
      zero: 'Ningún campo encontrado',
    );
    return '$_temp0';
  }

  @override
  String detectFillFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rellenar $count campos →',
      one: 'Rellenar 1 campo →',
    );
    return '$_temp0';
  }

  @override
  String get detectPinchHint =>
      'Toca una herramienta de abajo para añadir un campo · toca un campo para seleccionarlo';

  @override
  String get importErrorUnreadableImage =>
      'No se pudo abrir esta imagen. Prueba con una foto JPEG, PNG o HEIC.';

  @override
  String get iapErrorUnavailable =>
      'Las compras no están disponibles en este dispositivo en este momento.';

  @override
  String get iapErrorProductNotFound =>
      'No se pudo conectar con la tienda. Inténtalo de nuevo más tarde.';

  @override
  String get iapErrorPurchaseFailed =>
      'No se pudo completar la compra. No se te ha cobrado nada.';

  @override
  String get settingsBackupTitle =>
      'Incluir en la copia de seguridad del dispositivo';

  @override
  String get settingsBackupSubtitleIos =>
      'Desactivado: los documentos y las firmas se quedan solo en este iPhone. Activado: se incluyen en tu copia de iCloud.';

  @override
  String get settingsBackupSubtitleAndroid =>
      'Desactivado: los documentos y las firmas se quedan solo en este teléfono. Activado: se incluyen en tu copia cifrada de Google y al pasar a un teléfono nuevo.';

  @override
  String get fieldTypeRadio => 'Botón de opción';

  @override
  String get fieldTypeRadioShort => 'Opción';

  @override
  String get fieldTypeInitials => 'Iniciales';

  @override
  String get fillTapToInitial => 'Toca para poner iniciales';

  @override
  String get signInitialsTitle => 'Dibuja tus iniciales';

  @override
  String get pressRadioSelected => 'Seleccionado';

  @override
  String get pressRadioNotSelected => 'No seleccionado';

  @override
  String get detectSelectedHint =>
      'Arrastra para mover · pellizca o arrastra la esquina para cambiar el tamaño · toca de nuevo para editar';

  @override
  String get detectRadioAddChoiceHint =>
      'Toca Opción otra vez para añadir otra respuesta a esta pregunta';

  @override
  String get detectFieldDeleted => 'Campo eliminado';

  @override
  String get detectRemoveDetected => 'Quitar campos detectados';

  @override
  String detectRemovedDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se quitaron $count campos detectados',
      one: 'Se quitó 1 campo detectado',
    );
    return '$_temp0';
  }

  @override
  String get actionUndo => 'Deshacer';

  @override
  String get detectFormFieldLocked =>
      'Este campo forma parte del formulario del PDF. Rellénalo en el siguiente paso.';

  @override
  String get libraryImport => 'Importar';

  @override
  String get settingsForgetLearned => 'Olvidar los campos aprendidos';

  @override
  String get settingsForgetLearnedSubtitle =>
      'La detección aprende de los campos que añades, cambias y eliminas, solo en este dispositivo.';

  @override
  String get settingsForgetLearnedDone => 'Campos aprendidos borrados';

  @override
  String paywallReasonAllowance(int count) {
    return 'Has usado tus $count documentos gratuitos.';
  }

  @override
  String paywallReasonPages(int count) {
    return 'Los documentos gratuitos pueden tener hasta $count páginas.';
  }

  @override
  String get paywallBenefitAnyLength => 'Documentos de cualquier extensión';

  @override
  String pageLimitTitle(int count) {
    return 'Documentos gratuitos: hasta $count páginas';
  }

  @override
  String pageLimitBody(int pages, int limit) {
    return 'Este documento tiene $pages páginas. Desbloquea Ilimitado para documentos de cualquier extensión, o conserva las primeras $limit páginas.';
  }

  @override
  String pageLimitKeepFirst(int count) {
    return 'Conservar las primeras $count páginas';
  }

  @override
  String pressFreeRemaining(int left, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other:
          'Finalizar usa 1 de tus $total documentos gratuitos (quedan $left)',
      one: 'Finalizar usa tu último documento gratuito',
      zero: 'Has usado tus $total documentos gratuitos',
    );
    return '$_temp0';
  }

  @override
  String get sendSaveAsTemplate => 'Guardar como plantilla';

  @override
  String get sendTemplateSaved =>
      'Guardado en Plantillas: crea una copia nueva desde la biblioteca.';

  @override
  String get sendTemplateSavedShort => 'Guardado como plantilla';

  @override
  String libraryFreeLeft(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Te quedan $left documentos gratis',
      one: 'Te queda 1 documento gratis',
      zero: 'Documentos gratis agotados',
    );
    return '$_temp0';
  }

  @override
  String libraryUnlimitedPrice(String price) {
    return 'Ilimitado, pago único $price';
  }

  @override
  String get onboardFreeTitle => 'Pruébalo gratis';

  @override
  String onboardFreeBody(int count, int pages) {
    return 'Completa $count documentos gratis, de hasta $pages páginas cada uno. Después, desbloquea Ilimitado con una sola compra, sin suscripción.';
  }
}
