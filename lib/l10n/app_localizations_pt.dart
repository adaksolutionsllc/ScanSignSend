// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Scan Sign Send';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionRemove => 'Remover';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get actionBack => 'Voltar';

  @override
  String get actionSkip => 'Ignorar';

  @override
  String get actionNext => 'Seguinte';

  @override
  String get actionOpen => 'Abrir';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionShare => 'Partilhar';

  @override
  String get actionTryAgain => 'Tentar novamente';

  @override
  String get actionClear => 'Limpar';

  @override
  String get documentFallbackTitle => 'Documento';

  @override
  String get errorGenericTitle => 'Ocorreu um problema aqui.';

  @override
  String get errorGenericBody => 'Volte atrás e abra novamente este documento.';

  @override
  String get lockTitle => 'O Scan Sign Send está bloqueado';

  @override
  String get lockBody =>
      'Desbloqueie com o Face ID ou a sua impressão digital para continuar.';

  @override
  String get lockUnlock => 'Desbloquear';

  @override
  String get onboardScanTitle => 'Digitalizar';

  @override
  String get onboardScanBody =>
      'Use a câmara para digitalizar qualquer documento em papel. Deteta os limites e limpa a imagem automaticamente.';

  @override
  String get onboardSignTitle => 'Assinar';

  @override
  String get onboardSignBody =>
      'Toque nos campos para os preencher. Adicione a sua assinatura com o dedo. Os seus dados nunca saem do dispositivo.';

  @override
  String get onboardSendTitle => 'Enviar';

  @override
  String get onboardSendBody =>
      'Partilhe o PDF assinado por Mail, Mensagens, AirDrop ou qualquer aplicação. Compra única — documentos ilimitados para sempre.';

  @override
  String get onboardGetStarted => 'Começar';

  @override
  String get librarySearchHint => 'Procurar documentos…';

  @override
  String get libraryTabAll => 'Todos';

  @override
  String get libraryTabDraft => 'Rascunho';

  @override
  String get libraryTabCompleted => 'Concluído';

  @override
  String get libraryTabTemplate => 'Modelo';

  @override
  String get libraryImportTooltip => 'Importar PDF / imagem';

  @override
  String get libraryNewScan => 'Nova digitalização';

  @override
  String get libraryRenameTooltip => 'Mudar o nome';

  @override
  String get libraryUseTemplate => 'Usar modelo';

  @override
  String get libraryDeleteTitle => 'Eliminar o documento?';

  @override
  String libraryDeleteBody(String title) {
    return 'Eliminar «$title»? Esta ação não pode ser anulada.';
  }

  @override
  String get libraryRenameTitle => 'Mudar o nome do documento';

  @override
  String get libraryDocumentNameHint => 'Nome do documento';

  @override
  String libraryUseTemplateFailed(String error) {
    return 'Não foi possível usar o modelo: $error';
  }

  @override
  String get statusCompleted => 'Concluído';

  @override
  String get statusEditable => 'Editável';

  @override
  String get statusTemplate => 'Modelo';

  @override
  String get statusDraft => 'Rascunho';

  @override
  String get emptyDraftsTitle => 'Sem rascunhos';

  @override
  String get emptyDraftsBody =>
      'Inicie uma digitalização para criar um rascunho.';

  @override
  String get emptyPressedTitle => 'Sem documentos finalizados';

  @override
  String get emptyPressedBody =>
      'Preencha e finalize um rascunho para o ver aqui.';

  @override
  String get emptyTemplatesTitle => 'Ainda sem modelos';

  @override
  String get emptyTemplatesBody =>
      'Ao finalizar um documento, é guardado aqui\nautomaticamente um modelo reutilizável.';

  @override
  String get emptyAllTitle => 'Ainda sem documentos';

  @override
  String get emptyAllBody =>
      'Toque em «Nova digitalização» para começar.\nDigitalizar → Assinar → Enviar.';

  @override
  String searchNoResults(String query) {
    return 'Sem resultados para «$query»';
  }

  @override
  String get captureTitle => 'Digitalizar documento';

  @override
  String get captureLaunching => 'A abrir o scanner…';

  @override
  String get captureSavingPages => 'A guardar as páginas…';

  @override
  String get captureImporting => 'A importar…';

  @override
  String captureScanFailed(String error) {
    return 'Falha na digitalização: $error';
  }

  @override
  String captureImportFailed(String error) {
    return 'Falha na importação: $error';
  }

  @override
  String get captureScanWithCamera => 'Digitalizar com a câmara';

  @override
  String get captureImportPdfImage => 'Importar PDF / imagem';

  @override
  String get captureUpTo20Pages => 'Até 20 páginas por digitalização';

  @override
  String captureDefaultDocumentName(String date) {
    return 'Documento $date';
  }

  @override
  String get reviewTitle => 'Rever páginas';

  @override
  String get reviewSaveOrder => 'Guardar ordem';

  @override
  String get reviewNoPagesFound => 'Nenhuma página encontrada.';

  @override
  String get reviewDetectFields => 'Detetar campos →';

  @override
  String reviewRotateFailed(String error) {
    return 'Falha ao rodar: $error';
  }

  @override
  String get reviewDeletePageTitle => 'Eliminar a página?';

  @override
  String reviewDeletePageBody(int number) {
    return 'Remover a página $number?';
  }

  @override
  String reviewPageOf(int current, int total) {
    return 'Página $current de $total';
  }

  @override
  String get reviewRotateTooltip => 'Rodar 90°';

  @override
  String get reviewDeletePageTooltip => 'Eliminar página';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterEnhanced => 'Melhorado';

  @override
  String get filterBw => 'P&B';

  @override
  String get detectTitle => 'Detetar campos';

  @override
  String get detectFormFieldsFoundTitle => 'Campos de formulário detetados';

  @override
  String get detectFormFieldsFoundBody =>
      'Este PDF já contém campos de formulário.\nPode adicionar os seus próprios campos manualmente ou avançar diretamente para o preenchimento.';

  @override
  String get detectContinueToFill => 'Continuar para preencher';

  @override
  String get detectConfirmAll => 'Confirmar tudo';

  @override
  String get detectStarting => 'A iniciar…';

  @override
  String get detectReading => 'A ler o seu documento…';

  @override
  String detectAnalysingPage(int current, int total) {
    return 'A analisar a página $current de $total…';
  }

  @override
  String get detectUnknownError => 'Erro desconhecido';

  @override
  String get detectOnDeviceNote =>
      'Todo o processamento acontece no dispositivo.';

  @override
  String get detectFailed => 'Falha na deteção';

  @override
  String get detectNoPages => 'Sem páginas.';

  @override
  String get detectSkipToFill => 'Avançar para preencher →';

  @override
  String detectFillFieldsCount(int count) {
    return 'Preencher campos ($count) →';
  }

  @override
  String get detectBadgeText => 'TEXTO';

  @override
  String get detectBadgeDate => 'DATA';

  @override
  String get detectBadgeCheck => 'CAIXA';

  @override
  String get detectBadgeSign => 'ASSIN.';

  @override
  String get detectEditField => 'Editar campo';

  @override
  String get detectFieldType => 'Tipo';

  @override
  String get detectFieldLabelHint => 'Etiqueta / nome do campo';

  @override
  String get detectRequiredField => 'Campo obrigatório';

  @override
  String get detectAddField => 'Adicionar campo';

  @override
  String detectAddTypedField(String type) {
    return 'Adicionar campo de $type';
  }

  @override
  String get fieldTypeText => 'Texto';

  @override
  String get fieldTypeDate => 'Data';

  @override
  String get fieldTypeCheckbox => 'Caixa de verificação';

  @override
  String get fieldTypeSignature => 'Assinatura';

  @override
  String get fieldTypeCheckShort => 'Caixa';

  @override
  String get fieldTypeSignShort => 'Assinar';

  @override
  String get fillFallbackTitle => 'Preencher documento';

  @override
  String get fillEditFields => 'Editar campos';

  @override
  String get fillReviewAndFinish => 'Rever e concluir';

  @override
  String get fillNoPages => 'Este documento não tem páginas.';

  @override
  String get fillTextFieldFallback => 'Campo de texto';

  @override
  String get fillEnterValueHint => 'Introduza um valor…';

  @override
  String get fillChipName => 'Nome';

  @override
  String get fillChipEmail => 'E-mail';

  @override
  String get fillChipPhone => 'Telefone';

  @override
  String get fillChipAddress => 'Morada';

  @override
  String get fillChipCompany => 'Empresa';

  @override
  String get fillChipToday => 'Hoje';

  @override
  String get fillTapToFill => 'Toque para preencher…';

  @override
  String get fillTapForDate => 'Toque para a data…';

  @override
  String get fillTapToCheck => 'Toque para marcar';

  @override
  String get fillTapToSign => 'Toque para assinar…';

  @override
  String get fillPdfNotFound => 'PDF não encontrado';

  @override
  String get fillImageNotFound => 'Imagem não encontrada';

  @override
  String get fillScanOrImport => 'Digitalize ou importe um novo documento';

  @override
  String get pressTitle => 'Rever e concluir';

  @override
  String get pressFieldSummary => 'Resumo dos campos';

  @override
  String get pressFilled => 'Preenchido';

  @override
  String get pressUnfilled => 'Por preencher';

  @override
  String get pressSaveDraft => 'Guardar rascunho';

  @override
  String get pressFlattenAndSign => 'Achatar e assinar (bloqueia o documento)';

  @override
  String pressExportFailed(String error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get pressConfirmTitle => 'Achatar e bloquear este documento?';

  @override
  String get pressConfirmBody =>
      'Ao achatar, os seus dados são integrados num novo PDF. O resultado é permanente — ninguém o poderá editar depois, nem o próprio utilizador.';

  @override
  String get pressConfirmLiveFields =>
      'Este documento tem campos de formulário interativos. Achatar remove-os — para os manter editáveis, escolha «Guardar rascunho».';

  @override
  String get pressConfirmNote =>
      'Nota: uma assinatura desenhada aqui é uma marca visual, não uma assinatura eletrónica certificada.';

  @override
  String get pressFlattenAndLock => 'Achatar e bloquear';

  @override
  String pressFailed(String error) {
    return 'Falha ao finalizar: $error';
  }

  @override
  String get pressWorking => 'A processar…';

  @override
  String get pressNotFilled => 'Por preencher';

  @override
  String get pressChecked => 'Marcado ✓';

  @override
  String get pressUnchecked => 'Não marcado';

  @override
  String get pressSignatureCaptured => 'Assinatura captada';

  @override
  String get signTitle => 'Assine aqui';

  @override
  String get signSwitchInk => 'Mudar a cor da tinta';

  @override
  String get signSaveAsMine => 'Guardar como a minha assinatura';

  @override
  String get signReuseSubtitle => 'Reutilizar em documentos futuros';

  @override
  String get signSaving => 'A guardar…';

  @override
  String get signUseThis => 'Usar esta assinatura';

  @override
  String get signDrawFirst => 'Desenhe primeiro a sua assinatura.';

  @override
  String get signDefaultLabel => 'A minha assinatura';

  @override
  String signSaveFailed(String error) {
    return 'Não foi possível guardar a assinatura: $error';
  }

  @override
  String get signaturesTitle => 'Assinaturas guardadas';

  @override
  String get signaturesEmpty => 'Ainda sem assinaturas guardadas';

  @override
  String get signaturesAdd => 'Adicionar assinatura';

  @override
  String get signaturesDefaultBadge => 'Predefinida';

  @override
  String get signaturesSetDefault => 'Definir como predefinida';

  @override
  String get signaturesDeleteTitle => 'Eliminar a assinatura?';

  @override
  String signaturesDeleteBody(String label) {
    return 'Eliminar «$label»?';
  }

  @override
  String get sendTitle => 'Enviar documento';

  @override
  String get sendBackToLibrary => 'Voltar à biblioteca';

  @override
  String get sendDocumentSent => 'Documento enviado!';

  @override
  String get sendReadyToSend => 'Pronto a enviar';

  @override
  String get sendSharedBody => 'O PDF finalizado foi partilhado.';

  @override
  String get sendReadyBody =>
      'Partilhe o seu PDF finalizado por Mail, Mensagens, AirDrop ou qualquer aplicação.';

  @override
  String get sendOpeningShareSheet => 'A abrir a partilha…';

  @override
  String get sendSharePressed => 'Partilhar documento finalizado';

  @override
  String get sendPreviewDocument => 'Pré-visualizar documento';

  @override
  String get sendShareAgain => 'Partilhar novamente';

  @override
  String get sendNotYetPressed => 'O documento ainda não foi finalizado.';

  @override
  String get sendPressedPdfNotFound =>
      'Ficheiro PDF finalizado não encontrado.';

  @override
  String get sendShareMessage => 'Assinado com o Scan Sign Send';

  @override
  String sendShareFailed(String error) {
    return 'Falha na partilha: $error';
  }

  @override
  String get viewerPdfNotFound => 'Ficheiro PDF não encontrado.';

  @override
  String get viewerSearchHint => 'Procurar no documento…';

  @override
  String get viewerSearchTooltip => 'Procurar';

  @override
  String get viewerNoExportedPdf => 'Ainda não há nenhum PDF exportado';

  @override
  String get viewerNoExportedPdfBody =>
      'Preencha e exporte este documento (rascunho ou achatado) para o ver aqui.';

  @override
  String get settingsTitle => 'Definições';

  @override
  String get settingsSectionProfile => 'O meu perfil';

  @override
  String get settingsSectionSignatures => 'Assinaturas';

  @override
  String get settingsSectionSecurity => 'Segurança';

  @override
  String get settingsSectionAi => 'Deteção com IA (v1.1)';

  @override
  String get settingsSectionPurchase => 'Compra';

  @override
  String get settingsFullName => 'Nome completo';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsPhone => 'Telefone';

  @override
  String get settingsAddress => 'Morada';

  @override
  String get settingsCity => 'Cidade';

  @override
  String get settingsState => 'Distrito';

  @override
  String get settingsZip => 'Código postal';

  @override
  String get settingsCompany => 'Empresa';

  @override
  String get settingsManageSignatures => 'Gerir assinaturas';

  @override
  String get settingsBiometricLock => 'Bloqueio biométrico';

  @override
  String get settingsBiometricLockSubtitle =>
      'Pedir Face ID / impressão digital ao abrir';

  @override
  String get settingsNoBiometrics =>
      'Não há dados biométricos registados neste dispositivo. Configure primeiro o Face ID ou a impressão digital.';

  @override
  String get settingsAiDetection => 'Deteção com IA melhorada';

  @override
  String get settingsAiDetectionSubtitle =>
      'Usa um modelo no dispositivo para reconhecer melhor os campos';

  @override
  String get settingsUnlockFullAccess => 'Desbloquear acesso total';

  @override
  String get settingsUnlockSubtitle => 'Compra única — ver preço';

  @override
  String get settingsRestorePurchase => 'Restaurar compra';

  @override
  String get settingsFullAccessUnlocked => 'Acesso total desbloqueado';

  @override
  String get settingsThankYou => 'Obrigado pela sua compra!';

  @override
  String get settingsCheckingPurchases => 'A procurar compras anteriores…';

  @override
  String get settingsRestored => 'Acesso total restaurado. Obrigado!';

  @override
  String get settingsNoPreviousPurchase =>
      'Não foi encontrada nenhuma compra anterior nesta conta.';

  @override
  String settingsRestoreFailed(String error) {
    return 'Falha ao restaurar: $error';
  }

  @override
  String get settingsTapToSet => 'Toque para definir';

  @override
  String settingsEditLabel(String label) {
    return 'Editar $label';
  }

  @override
  String get paywallTitle => 'Desbloquear acesso total';

  @override
  String get paywallHeadline => 'Scan Sign Send — Acesso total';

  @override
  String get paywallSubhead => 'Compra única. Sem subscrição. Sem conta.';

  @override
  String get paywallBenefitUnlimited => 'Documentos ilimitados';

  @override
  String get paywallBenefitTemplates => 'Modelos reutilizáveis';

  @override
  String get paywallBenefitSignatures => 'Várias assinaturas guardadas';

  @override
  String get paywallBenefitAutofill => 'Preenchimento automático do perfil';

  @override
  String get paywallBenefitLock => 'Bloqueio biométrico';

  @override
  String get paywallBenefitOffline =>
      'Sempre offline — os seus dados ficam no dispositivo';

  @override
  String paywallUnlockForPrice(String price) {
    return 'Desbloquear — $price';
  }

  @override
  String get paywallRestore => 'Restaurar compra';

  @override
  String get paywallPaymentDisclosure =>
      'O pagamento será cobrado na sua conta App Store / Play ao confirmar.';

  @override
  String get paywallNoPreviousPurchase =>
      'Não foi encontrada nenhuma compra anterior nesta conta.';

  @override
  String get dateFormatShort => 'd \'de\' MMM \'de\' yyyy';

  @override
  String get dateFormatInput => 'dd/MM/yyyy';

  @override
  String get biometricReason => 'Desbloquear o Scan Sign Send';

  @override
  String get certTitle => 'Certificado de assinatura';

  @override
  String get certDocument => 'Documento';

  @override
  String get certSignedOn => 'Assinado a';

  @override
  String get certMethod => 'Método';

  @override
  String get certMethodValue => 'No dispositivo (Scan Sign Send)';

  @override
  String get certNote => 'Nota';

  @override
  String get certNoteValue =>
      'Assinaturas captadas localmente. Sem processamento na nuvem.';

  @override
  String get certDateFormat => 'd \'de\' MMMM \'de\' yyyy — HH:mm';

  @override
  String get importErrorUnreadable =>
      'Não foi possível abrir este PDF. Pode estar protegido por palavra-passe ou danificado.';

  @override
  String get importErrorNoPages => 'Este PDF não tem páginas.';

  @override
  String get pressErrorNoPages =>
      'Este documento não tem páginas para finalizar.';

  @override
  String get exportErrorNoPages =>
      'Este documento não tem páginas para exportar.';

  @override
  String get iapUnavailable =>
      'As compras na aplicação não estão disponíveis neste dispositivo.';

  @override
  String get iapProductNotFound => 'Produto não encontrado na loja.';

  @override
  String detectFieldsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos encontrados',
      one: '1 campo encontrado',
      zero: 'Nenhum campo encontrado',
    );
    return '$_temp0';
  }

  @override
  String detectFillFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Preencher $count campos →',
      one: 'Preencher 1 campo →',
    );
    return '$_temp0';
  }

  @override
  String get detectPinchHint =>
      'Toque numa ferramenta abaixo para adicionar um campo · toque num campo para selecioná-lo';

  @override
  String get importErrorUnreadableImage =>
      'Não foi possível abrir esta imagem. Tente uma foto JPEG, PNG ou HEIC.';

  @override
  String get iapErrorUnavailable =>
      'As compras não estão disponíveis neste dispositivo no momento.';

  @override
  String get iapErrorProductNotFound =>
      'Não foi possível acessar a loja. Tente novamente mais tarde.';

  @override
  String get iapErrorPurchaseFailed =>
      'Não foi possível concluir a compra. Nenhum valor foi cobrado.';

  @override
  String get settingsBackupTitle => 'Incluir no backup do dispositivo';

  @override
  String get settingsBackupSubtitleIos =>
      'Desativado: documentos e assinaturas ficam apenas neste iPhone. Ativado: eles entram no seu backup do iCloud.';

  @override
  String get settingsBackupSubtitleAndroid =>
      'Desativado: documentos e assinaturas ficam apenas neste telefone. Ativado: eles entram no seu backup criptografado do Google e na transferência para um novo telefone.';

  @override
  String get fieldTypeRadio => 'Botão de opção';

  @override
  String get fieldTypeRadioShort => 'Opção';

  @override
  String get fieldTypeInitials => 'Rubrica';

  @override
  String get fillTapToInitial => 'Toque para rubricar';

  @override
  String get signInitialsTitle => 'Desenhe sua rubrica';

  @override
  String get pressRadioSelected => 'Selecionado';

  @override
  String get pressRadioNotSelected => 'Não selecionado';

  @override
  String get detectSelectedHint =>
      'Arraste para mover · faça pinça ou arraste o canto para redimensionar · toque de novo para editar';

  @override
  String get detectRadioAddChoiceHint =>
      'Toque em Opção de novo para adicionar outra resposta a esta pergunta';

  @override
  String get detectFieldDeleted => 'Campo excluído';

  @override
  String get actionUndo => 'Desfazer';

  @override
  String get detectFormFieldLocked =>
      'Este campo faz parte do formulário do PDF. Preencha-o na próxima etapa.';

  @override
  String get libraryImport => 'Importar';

  @override
  String get settingsForgetLearned => 'Esquecer campos aprendidos';

  @override
  String get settingsForgetLearnedSubtitle =>
      'A detecção aprende com os campos que você adiciona, altera e exclui, somente neste dispositivo.';

  @override
  String get settingsForgetLearnedDone => 'Campos aprendidos apagados';

  @override
  String paywallReasonAllowance(int count) {
    return 'Você usou seus $count documentos gratuitos.';
  }

  @override
  String paywallReasonPages(int count) {
    return 'Documentos gratuitos podem ter até $count páginas.';
  }

  @override
  String get paywallBenefitAnyLength => 'Documentos de qualquer tamanho';

  @override
  String pageLimitTitle(int count) {
    return 'Documentos gratuitos: até $count páginas';
  }

  @override
  String pageLimitBody(int pages, int limit) {
    return 'Este documento tem $pages páginas. Desbloqueie o acesso completo para documentos de qualquer tamanho, ou mantenha as primeiras $limit páginas.';
  }

  @override
  String pageLimitKeepFirst(int count) {
    return 'Manter as primeiras $count páginas';
  }

  @override
  String pressFreeRemaining(int left, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other:
          'Concluir usa 1 dos seus $total documentos gratuitos ($left restantes)',
      one: 'Concluir usa seu último documento gratuito',
      zero: 'Você usou seus $total documentos gratuitos',
    );
    return '$_temp0';
  }
}
