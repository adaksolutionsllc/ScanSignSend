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
  String get actionSave => 'Salvar';

  @override
  String get actionDelete => 'Excluir';

  @override
  String get actionRemove => 'Remover';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get actionBack => 'Voltar';

  @override
  String get actionSkip => 'Pular';

  @override
  String get actionNext => 'Próximo';

  @override
  String get actionOpen => 'Abrir';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionShare => 'Compartilhar';

  @override
  String get actionTryAgain => 'Tentar novamente';

  @override
  String get actionClear => 'Limpar';

  @override
  String get documentFallbackTitle => 'Documento';

  @override
  String get errorGenericTitle => 'Algo deu errado aqui.';

  @override
  String get errorGenericBody => 'Volte e abra este documento novamente.';

  @override
  String get lockTitle => 'O Scan Sign Send está bloqueado';

  @override
  String get lockBody =>
      'Desbloqueie com o Face ID ou sua impressão digital para continuar.';

  @override
  String get lockUnlock => 'Desbloquear';

  @override
  String get onboardScanTitle => 'Digitalizar';

  @override
  String get onboardScanBody =>
      'Use a câmera para digitalizar qualquer documento em papel. O app detecta as bordas e limpa a imagem automaticamente.';

  @override
  String get onboardSignTitle => 'Assinar';

  @override
  String get onboardSignBody =>
      'Toque nos campos para preenchê-los. Adicione sua assinatura com o dedo. Seus documentos ficam salvos apenas neste dispositivo.';

  @override
  String get onboardSendTitle => 'Enviar';

  @override
  String get onboardSendBody =>
      'Compartilhe o PDF assinado por e-mail, mensagem ou qualquer app. Compra única — documentos ilimitados para sempre.';

  @override
  String get onboardGetStarted => 'Começar';

  @override
  String get librarySearchHint => 'Buscar documentos…';

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
  String get libraryRenameTooltip => 'Renomear';

  @override
  String get libraryUseTemplate => 'Usar modelo';

  @override
  String get libraryDeleteTitle => 'Excluir o documento?';

  @override
  String libraryDeleteBody(String title) {
    return 'Excluir “$title”? Esta ação não pode ser desfeita.';
  }

  @override
  String get libraryRenameTitle => 'Renomear documento';

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
  String get emptyPressedTitle => 'Nenhum documento concluído';

  @override
  String get emptyPressedBody => 'Conclua um rascunho para vê-lo aqui.';

  @override
  String get emptyTemplatesTitle => 'Ainda sem modelos';

  @override
  String get emptyTemplatesBody =>
      'Depois de concluir um documento, toque em\n“Salvar como modelo” para reutilizar o formulário.';

  @override
  String get emptyAllTitle => 'Ainda sem documentos';

  @override
  String get emptyAllBody =>
      'Toque em “Nova digitalização” para começar.\nDigitalizar → Assinar → Enviar.';

  @override
  String searchNoResults(String query) {
    return 'Nenhum resultado para “$query”';
  }

  @override
  String get captureTitle => 'Digitalizar documento';

  @override
  String get captureLaunching => 'Abrindo o scanner…';

  @override
  String get captureSavingPages => 'Salvando as páginas…';

  @override
  String get captureImporting => 'Importando…';

  @override
  String captureScanFailed(String error) {
    return 'Falha na digitalização: $error';
  }

  @override
  String captureImportFailed(String error) {
    return 'Falha na importação: $error';
  }

  @override
  String get captureScanWithCamera => 'Digitalizar com a câmera';

  @override
  String get captureImportPdfImage => 'Importar PDF / imagem';

  @override
  String get captureUpTo20Pages => 'Até 20 páginas por digitalização';

  @override
  String captureDefaultDocumentName(String date) {
    return 'Documento $date';
  }

  @override
  String autoDocumentTitle(String title, String date) {
    return '$title – $date';
  }

  @override
  String get reviewTitle => 'Revisar páginas';

  @override
  String get reviewSaveOrder => 'Salvar ordem';

  @override
  String get reviewNoPagesFound => 'Nenhuma página encontrada.';

  @override
  String get reviewDetectFields => 'Detectar campos →';

  @override
  String reviewRotateFailed(String error) {
    return 'Falha ao girar: $error';
  }

  @override
  String get reviewDeletePageTitle => 'Excluir a página?';

  @override
  String reviewDeletePageBody(int number) {
    return 'Remover a página $number?';
  }

  @override
  String reviewPageOf(int current, int total) {
    return 'Página $current de $total';
  }

  @override
  String get reviewRotateTooltip => 'Girar 90°';

  @override
  String get reviewDeletePageTooltip => 'Excluir página';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterEnhanced => 'Melhorado';

  @override
  String get filterBw => 'P&B';

  @override
  String get detectTitle => 'Detectar campos';

  @override
  String get detectFormFieldsFoundTitle => 'Campos de formulário detectados';

  @override
  String get detectFormFieldsFoundBody =>
      'Este PDF já contém campos de formulário.\nVocê pode adicionar seus próprios campos manualmente ou ir direto para o preenchimento.';

  @override
  String get detectContinueToFill => 'Continuar para preencher';

  @override
  String get detectConfirmAll => 'Confirmar tudo';

  @override
  String get detectStarting => 'Iniciando…';

  @override
  String get detectReading => 'Lendo seu documento…';

  @override
  String detectAnalysingPage(int current, int total) {
    return 'Analisando a página $current de $total…';
  }

  @override
  String get detectUnknownError => 'Erro desconhecido';

  @override
  String get detectOnDeviceNote =>
      'Todo o processamento acontece no dispositivo.';

  @override
  String get detectFailed => 'Falha na detecção';

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
  String get detectFieldLabelHint => 'Rótulo / nome do campo';

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
  String get fieldTypeCheckbox => 'Caixa de seleção';

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
  String get fillReviewAndFinish => 'Revisar e concluir';

  @override
  String get fillNoPages => 'Este documento não tem páginas.';

  @override
  String get fillTextFieldFallback => 'Campo de texto';

  @override
  String get fillEnterValueHint => 'Digite um valor…';

  @override
  String get fillTapToFill => 'Toque para preencher…';

  @override
  String get fillTapForDate => 'Toque para inserir a data…';

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
  String get pressTitle => 'Revisar e concluir';

  @override
  String get pressFieldSummary => 'Resumo dos campos';

  @override
  String pressFilledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos preenchidos',
      one: '1 campo preenchido',
    );
    return '$_temp0';
  }

  @override
  String pressUnfilledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos a preencher',
      one: '1 campo a preencher',
    );
    return '$_temp0';
  }

  @override
  String get pressSaveDraft => 'Salvar rascunho';

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
      'Ao achatar, seus dados são integrados a um novo PDF. O resultado é permanente — ninguém poderá editá-lo depois, nem você.';

  @override
  String get pressConfirmLiveFields =>
      'Este documento tem campos de formulário interativos. Achatar remove esses campos — para mantê-los editáveis, escolha “Salvar rascunho”.';

  @override
  String get pressConfirmNote =>
      'Observação: uma assinatura desenhada aqui é uma marca visual, não uma assinatura eletrônica certificada.';

  @override
  String get pressFlattenAndLock => 'Achatar e bloquear';

  @override
  String get pressNoFieldsTitle => 'Ainda não há campos';

  @override
  String get pressNoFieldsBody =>
      'Não há nada para preencher ou assinar aqui. Você pode salvá-lo como PDF para guardar e compartilhar, ou adicionar campos primeiro.';

  @override
  String get pressAddFields => 'Adicionar campos';

  @override
  String get pressSavePdf => 'Salvar PDF';

  @override
  String get saveNoFieldsTitle => 'Salvar sem campos?';

  @override
  String get saveNoFieldsBody =>
      'Este documento não tem campos para preencher ou assinar. Ele será salvo como PDF concluído, que você pode guardar e compartilhar.';

  @override
  String pressFailed(String error) {
    return 'Não foi possível concluir o documento: $error';
  }

  @override
  String get pressWorking => 'Processando…';

  @override
  String get pressNotFilled => 'Não preenchido';

  @override
  String get pressChecked => 'Marcado ✓';

  @override
  String get pressUnchecked => 'Não marcado';

  @override
  String get pressSignatureCaptured => 'Assinatura capturada';

  @override
  String get signTitle => 'Assine aqui';

  @override
  String get signSwitchInk => 'Mudar a cor da tinta';

  @override
  String get signSaveAsMine => 'Salvar como minha assinatura';

  @override
  String get signReuseSubtitle => 'Reutilizar em documentos futuros';

  @override
  String get signSaving => 'Salvando…';

  @override
  String get signUseThis => 'Usar esta assinatura';

  @override
  String get signDrawFirst => 'Desenhe sua assinatura primeiro.';

  @override
  String get signDefaultLabel => 'Minha assinatura';

  @override
  String signSaveFailed(String error) {
    return 'Não foi possível salvar a assinatura: $error';
  }

  @override
  String get signaturesTitle => 'Assinaturas salvas';

  @override
  String get signaturesEmpty => 'Nenhuma assinatura salva ainda';

  @override
  String get signaturesAdd => 'Adicionar assinatura';

  @override
  String get signaturesDefaultBadge => 'Padrão';

  @override
  String get signaturesSetDefault => 'Definir como padrão';

  @override
  String get signaturesDeleteTitle => 'Excluir a assinatura?';

  @override
  String signaturesDeleteBody(String label) {
    return 'Excluir “$label”?';
  }

  @override
  String get sendTitle => 'Enviar documento';

  @override
  String get sendBackToLibrary => 'Voltar à biblioteca';

  @override
  String get sendDocumentSent => 'Documento enviado!';

  @override
  String get sendReadyToSend => 'Pronto para enviar';

  @override
  String get sendSharedBody => 'Seu PDF foi compartilhado.';

  @override
  String get sendReadyBody =>
      'Compartilhe seu PDF por e-mail, mensagem ou qualquer app.';

  @override
  String get sendOpeningShareSheet => 'Abrindo o compartilhamento…';

  @override
  String get sendSharePressed => 'Compartilhar PDF';

  @override
  String get sendPreviewDocument => 'Visualizar documento';

  @override
  String get sendShareAgain => 'Compartilhar novamente';

  @override
  String get sendNotYetPressed => 'Este documento ainda não foi concluído.';

  @override
  String get sendPressedPdfNotFound => 'O PDF concluído não foi encontrado.';

  @override
  String get sendShareMessage => 'Assinado com o Scan Sign Send';

  @override
  String sendShareFailed(String error) {
    return 'Falha ao compartilhar: $error';
  }

  @override
  String get viewerPdfNotFound => 'Arquivo PDF não encontrado.';

  @override
  String get viewerSearchHint => 'Buscar no documento…';

  @override
  String get viewerSearchTooltip => 'Buscar';

  @override
  String get viewerNoExportedPdf => 'Ainda não há nenhum PDF exportado';

  @override
  String get viewerNoExportedPdfBody =>
      'Preencha e exporte este documento (rascunho ou achatado) para vê-lo aqui.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSectionProfile => 'Meus dados';

  @override
  String get settingsSectionSignatures => 'Assinaturas';

  @override
  String get settingsSectionSecurity => 'Segurança';

  @override
  String get settingsSectionDetection => 'Detecção de campos';

  @override
  String get settingsSectionPurchase => 'Compra';

  @override
  String get settingsFullName => 'Nome completo';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsPhone => 'Telefone';

  @override
  String get settingsAddress => 'Endereço';

  @override
  String get settingsCity => 'Cidade';

  @override
  String get settingsState => 'Estado';

  @override
  String get settingsZip => 'CEP';

  @override
  String get settingsCompany => 'Empresa';

  @override
  String get settingsManageSignatures => 'Gerenciar assinaturas';

  @override
  String get settingsBiometricLock => 'Bloqueio biométrico';

  @override
  String get settingsBiometricLockSubtitle =>
      'Pedir Face ID / impressão digital ao abrir';

  @override
  String get settingsNoBiometrics =>
      'Não há biometria cadastrada neste dispositivo. Configure primeiro o Face ID ou a impressão digital.';

  @override
  String get settingsUnlockFullAccess => 'Desbloquear Ilimitado';

  @override
  String get settingsUnlockSubtitle => 'Compra única — ver preço';

  @override
  String get settingsRestorePurchase => 'Restaurar compra';

  @override
  String get settingsSectionSupport => 'Suporte';

  @override
  String get settingsRateApp => 'Avaliar o Scan Sign Send';

  @override
  String get settingsRateAppSubtitle => 'Deixe uma avaliação ou um comentário';

  @override
  String get settingsRateAppFailed =>
      'Não foi possível abrir a loja. Tente novamente mais tarde.';

  @override
  String get settingsFullAccessUnlocked => 'Ilimitado desbloqueado';

  @override
  String get settingsThankYou => 'Obrigado pela sua compra!';

  @override
  String get settingsCheckingPurchases => 'Procurando compras anteriores…';

  @override
  String get settingsRestored => 'Ilimitado restaurado. Obrigado!';

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
  String get paywallTitle => 'Desbloquear Ilimitado';

  @override
  String get paywallHeadline => 'Scan Sign Send — Ilimitado';

  @override
  String get paywallSubhead => 'Compra única. Sem assinatura. Sem conta.';

  @override
  String get paywallBenefitUnlimited => 'Documentos ilimitados';

  @override
  String get paywallBenefitTemplates => 'Modelos reutilizáveis';

  @override
  String get paywallBenefitSignatures => 'Várias assinaturas salvas';

  @override
  String get paywallBenefitAutofill => 'Preenchimento automático do perfil';

  @override
  String get paywallBenefitLock => 'Bloqueio biométrico';

  @override
  String get paywallBenefitOffline =>
      'Sempre offline — seus dados ficam no dispositivo';

  @override
  String paywallUnlockForPrice(String price) {
    return 'Desbloquear — $price';
  }

  @override
  String get paywallRestore => 'Restaurar compra';

  @override
  String get paywallPaymentDisclosure =>
      'O pagamento será cobrado na sua conta da App Store / Play ao confirmar.';

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
  String get certSignedOn => 'Assinado em';

  @override
  String get certMethod => 'Método';

  @override
  String get certMethodValue => 'No dispositivo (Scan Sign Send)';

  @override
  String get certNote => 'Observação';

  @override
  String get certNoteValue =>
      'Assinaturas capturadas localmente. Sem processamento na nuvem.';

  @override
  String get certDateFormat => 'd \'de\' MMMM \'de\' yyyy — HH:mm';

  @override
  String get importErrorUnreadable =>
      'Não foi possível abrir este PDF. Ele pode estar protegido por senha ou danificado.';

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
      'As compras no app não estão disponíveis neste dispositivo.';

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
      'Toque em uma ferramenta abaixo para adicionar um campo · toque em um campo para selecioná-lo';

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
  String get detectRemoveAll => 'Remover todos';

  @override
  String detectRemovedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos removidos',
      one: '1 campo removido',
    );
    return '$_temp0';
  }

  @override
  String get actionUndo => 'Desfazer';

  @override
  String get detectFormFieldLocked =>
      'Este campo faz parte do formulário do PDF. Preencha-o na próxima etapa.';

  @override
  String get libraryImport => 'Importar';

  @override
  String get settingsForgetLearned => 'Esquecer o que o app aprendeu';

  @override
  String get settingsForgetLearnedSubtitle =>
      'A detecção de campos, o PreFill e a organização aprendem com suas alterações, apenas neste dispositivo.';

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
    return 'Este documento tem $pages páginas. Desbloqueie o Ilimitado para documentos de qualquer tamanho, ou mantenha as primeiras $limit páginas.';
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

  @override
  String get sendSaveAsTemplate => 'Salvar como modelo';

  @override
  String get sendTemplateSaved =>
      'Salvo em Modelos — crie uma nova cópia pela biblioteca.';

  @override
  String get sendTemplateSavedShort => 'Salvo como modelo';

  @override
  String libraryFreeLeft(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Restam $left documentos grátis',
      one: 'Resta 1 documento grátis',
      zero: 'Documentos grátis esgotados',
    );
    return '$_temp0';
  }

  @override
  String libraryUnlimitedPrice(String price) {
    return 'Ilimitado, compra única $price';
  }

  @override
  String get onboardFreeTitle => 'Experimente grátis';

  @override
  String onboardFreeBody(int count, int pages) {
    return 'Conclua $count documentos grátis, de até $pages páginas cada. Depois, desbloqueie o Ilimitado com uma única compra — sem assinatura.';
  }

  @override
  String get settingsMyDetailsSubtitle =>
      'Salvos uma vez e usados pelo PreFill para preencher formulários';

  @override
  String get myDetailsNote =>
      'Salvos apenas neste dispositivo. Incluídos no backup do dispositivo só se você ativá-lo. O PreFill os usa para preencher os campos correspondentes nos seus formulários; nada é preenchido até você tocar em Preencher.';

  @override
  String get prefillFill => 'Preencher';

  @override
  String get myDetailsGroupName => 'Nome';

  @override
  String get myDetailsGroupContact => 'Contato';

  @override
  String get myDetailsGroupAddress => 'Endereço';

  @override
  String get myDetailsGroupWork => 'Trabalho';

  @override
  String get myDetailsGroupPersonal => 'Pessoal';

  @override
  String get detailFirstName => 'Nome';

  @override
  String get detailMiddleName => 'Nome do meio';

  @override
  String get detailLastName => 'Sobrenome';

  @override
  String get detailAddress1 => 'Endereço';

  @override
  String get detailAddress2 => 'Complemento';

  @override
  String get detailState => 'Estado';

  @override
  String get detailZip => 'CEP';

  @override
  String get detailCountry => 'País';

  @override
  String get detailJobTitle => 'Cargo';

  @override
  String get detailDateOfBirth => 'Data de nascimento';

  @override
  String get myDetailsDelete => 'Excluir meus dados';

  @override
  String get myDetailsDeleteBody =>
      'Isso apaga todos os dados desta página. Os documentos que você já preencheu não mudam.';

  @override
  String prefillOffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Preencher $count campos com Meus dados',
      one: 'Preencher 1 campo com Meus dados',
    );
    return '$_temp0';
  }

  @override
  String prefillFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos preenchidos',
      one: '1 campo preenchido',
    );
    return '$_temp0';
  }

  @override
  String get prefillSetup =>
      'Salve seus dados uma vez para preencher formulários mais rápido';

  @override
  String get prefillSetupAction => 'Adicionar';

  @override
  String get prefillSuggestions => 'De Meus dados';

  @override
  String get onboardPrefillTitle => 'Preencha formulários com um toque';

  @override
  String get onboardPrefillBody =>
      'Os campos são detectados e identificados automaticamente. Salve seus dados uma vez em Meus dados e o PreFill preenche os campos correspondentes. Salvos apenas neste dispositivo.';

  @override
  String get tourWhatsNew => 'Novidades';

  @override
  String get tourGotIt => 'Entendi';

  @override
  String get settingsTour => 'Tour guiado';

  @override
  String get settingsTourSubtitle => 'Veja o que o Scan Sign Send faz';

  @override
  String get categoryTax => 'Impostos';

  @override
  String get categoryMoney => 'Banco e dinheiro';

  @override
  String get categoryInsurance => 'Seguros';

  @override
  String get categoryMedical => 'Saúde';

  @override
  String get categoryHome => 'Casa e aluguel';

  @override
  String get categoryWork => 'Trabalho';

  @override
  String get categorySchool => 'Escola';

  @override
  String get categoryIdTravel => 'Identificação e viagens';

  @override
  String get categoryLegal => 'Contratos e jurídico';

  @override
  String get categoryBills => 'Contas e recibos';

  @override
  String get categoryNone => 'Sem categoria';

  @override
  String get categoryNew => 'Nova categoria';

  @override
  String get categoryNameHint => 'Nome da categoria';

  @override
  String get categoryChange => 'Mudar de categoria';

  @override
  String get categorySortedAutomatically => 'Organizado automaticamente';

  @override
  String get categoryRename => 'Renomear categoria';

  @override
  String get categoryDelete => 'Excluir categoria';

  @override
  String categoryDeleteBody(String name) {
    return '“$name” será excluída. Os documentos continuam na sua biblioteca, sem categoria.';
  }

  @override
  String get librarySelect => 'Selecionar';

  @override
  String librarySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '1 selecionado',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteManyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Excluir $count documentos?',
      one: 'Excluir 1 documento?',
    );
    return '$_temp0';
  }

  @override
  String get libraryDeleteManyBody => 'Esta ação não pode ser desfeita.';

  @override
  String get libraryMoreTooltip => 'Mais';

  @override
  String get settingsSectionLibrary => 'Biblioteca';

  @override
  String get settingsAutoSortTitle => 'Organizar documentos automaticamente';

  @override
  String get aiSortAvailable => 'Organizados pela IA do dispositivo.';

  @override
  String get aiSortDeviceNotEligible =>
      'Organizados por palavras-chave. A organização com a IA do dispositivo requer um iPhone 15 Pro ou posterior.';

  @override
  String get aiSortOsTooOld =>
      'Organizados por palavras-chave. Atualize para o iOS 26 ou posterior para organizar com a IA do dispositivo.';

  @override
  String get aiSortNotEnabled =>
      'Organizados por palavras-chave. Ative a Apple Intelligence nos Ajustes para organizar com a IA do dispositivo.';

  @override
  String get aiSortNotReady =>
      'Organizados por palavras-chave, por enquanto. A IA do dispositivo ainda está sendo configurada neste celular.';

  @override
  String get aiSortLanguage =>
      'Organizados por palavras-chave. A organização com a IA do dispositivo ainda não está disponível no idioma do seu celular.';

  @override
  String get aiSortUnsupported =>
      'Organizados por palavras-chave. Este celular não oferece suporte à organização com a IA do dispositivo.';

  @override
  String get aiSortOff =>
      'Os documentos não são organizados. Escolha a categoria de cada um.';

  @override
  String get actionGotIt => 'Entendi';

  @override
  String get reviewSkipFieldsSave => 'Pular campos · Salvar e compartilhar';

  @override
  String get saveAndShare => 'Salvar e compartilhar';

  @override
  String reviewSortedInto(String category) {
    return 'Arquivado em $category';
  }

  @override
  String get actionChange => 'Alterar';

  @override
  String get cropTitle => 'Verificar as bordas';

  @override
  String get cropHint => 'Arraste os cantos até as bordas do documento.';

  @override
  String get cropUseWhole => 'Usar a imagem inteira';

  @override
  String get cropApply => 'Recortar';

  @override
  String get cropChecking => 'Verificando as bordas…';

  @override
  String get cropFailed =>
      'Não foi possível recortar esta página. A imagem inteira foi mantida.';

  @override
  String get straightenAskTitle => 'Endireitar as páginas?';

  @override
  String straightenAskBodyMinutes(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other:
          'O app encontra as bordas de cada página para você recortar. Para estas $count páginas, leva cerca de $minutes minutos.',
      one:
          'O app encontra as bordas de cada página para você recortar. Para estas $count páginas, leva cerca de 1 minuto.',
    );
    return '$_temp0';
  }

  @override
  String straightenAskBodyQuick(int count) {
    return 'O app encontra as bordas de cada página para você recortar. Para estas $count páginas, leva menos de um minuto.';
  }

  @override
  String progressMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Faltam cerca de $minutes minutos',
      one: 'Falta cerca de 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get progressUnderMinuteLeft => 'Falta menos de um minuto';

  @override
  String get progressQuip1 => 'Acertando os cantos…';

  @override
  String get progressQuip2 => 'Alisando as bordas…';

  @override
  String get progressQuip3 => 'Alinhando as margens…';

  @override
  String get progressQuip4 => 'Arrumando as páginas…';

  @override
  String get progressQuip5 => 'Medindo duas vezes, recortando uma…';

  @override
  String get progressQuip6 => 'Colocando os pixels no lugar…';

  @override
  String get straightenGo => 'Endireitar';

  @override
  String get straightenKeep => 'Manter como está';

  @override
  String get straightenAskLater =>
      'Escolha Manter como está se as páginas já estiverem retas. Você ainda pode endireitá-las depois em Revisar páginas.';

  @override
  String get reviewStraighten => 'Endireitar páginas';

  @override
  String get reviewStraightenNone =>
      'Nenhuma borda de página para corrigir foi encontrada.';

  @override
  String cropCheckingPage(int current, int total) {
    return 'Verificando a página $current de $total…';
  }

  @override
  String cropStraighteningPage(int current, int total) {
    return 'Endireitando a página $current de $total…';
  }

  @override
  String get cropUseWholeRest => 'Usar a imagem inteira no restante';

  @override
  String get importErrorMixed => 'Escolha um só PDF, ou uma ou mais fotos.';

  @override
  String get sendHome => 'Início';

  @override
  String searchPageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count páginas',
      one: '1 página',
    );
    return '$_temp0';
  }
}
