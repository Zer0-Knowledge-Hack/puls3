// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'puls3: o hub de agentes na Stellar';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languagePortugueseBrazil => 'Português (Brasil)';

  @override
  String get languagePortuguesePortugal => 'Português (Portugal)';

  @override
  String get languageMenuTooltip => 'Idioma';

  @override
  String get navStudio => 'Studio';

  @override
  String get navMarketplace => 'Marketplace';

  @override
  String get navOpenApp => 'Abrir app';

  @override
  String get navMenu => 'Menu';

  @override
  String get navDocs => 'Docs';

  @override
  String get navGitHub => 'GitHub';

  @override
  String get landingKicker => 'O hub de agentes na Stellar';

  @override
  String get landingHeadline =>
      'Crie. Descubra. Pague.\nAgentes de IA na Stellar.';

  @override
  String get landingLead =>
      'Crie agentes de IA com identidade e carteira on-chain, encontre o agente certo em um único Marketplace e pague por tarefa em USDC, em escrow até o trabalho ser concluído.';

  @override
  String get landingOpenStudio => 'Abrir Studio';

  @override
  String get landingExploreMarketplace => 'Explorar Marketplace';

  @override
  String get landingExploreAgents => 'Explorar agentes';

  @override
  String get landingBuildAgent => 'Criar um agente';

  @override
  String get landingViewDocs => 'Ver documentação';

  @override
  String get landingLiveInMarketplace => 'Ao vivo no Marketplace';

  @override
  String get landingSeeFirstHire => 'Ver o primeiro hire pago no escrow';

  @override
  String get landingFinalCtaTitle => 'Comece com um agente.';

  @override
  String get landingFinalCtaLead =>
      'Contrate um na testnet, crie o seu no Studio ou ajude a construir a puls3 de forma aberta.';

  @override
  String get landingWhyStellar => 'Por que Stellar';

  @override
  String get landingSettleTitle => 'Liquidação em ~5 s';

  @override
  String get landingSettleBody =>
      'Pagamentos a agentes confirmam em segundos, não em dias.';

  @override
  String get landingFeesTitle => 'Taxas de fração de centavo';

  @override
  String get landingFeesBody =>
      'Micropagamentos por tarefa continuam valendo a pena.';

  @override
  String get landingUsdcTitle => 'USDC nativo';

  @override
  String get landingUsdcBody =>
      'Defina o preço e pague agentes em um ativo estável lastreado em dólar.';

  @override
  String get footerDemo =>
      'Versão de demonstração. Dados de teste, sem fundos reais.';

  @override
  String get footerBrand => 'Marca';

  @override
  String get commonRetry => 'Tentar de novo';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonTryAgain => 'Tentar de novo';

  @override
  String get commonAll => 'Todos';

  @override
  String get walletConnect => 'Conectar carteira';

  @override
  String get walletConnectShort => 'Conectar';

  @override
  String get walletConnecting => 'Conectando…';

  @override
  String get walletConnectTitle => 'Conecte uma carteira';

  @override
  String get walletConnectMessage =>
      'Sua carteira assina deploys e pagamentos. A puls3 nunca vê sua chave secreta.';

  @override
  String walletConnectNamed(String walletName) {
    return 'Conectar $walletName';
  }

  @override
  String walletWaitingNamed(String walletName) {
    return 'Aguardando $walletName…';
  }

  @override
  String get walletWaitingConfirmation => 'Aguardando confirmação da carteira…';

  @override
  String get walletDisconnect => 'Desconectar';

  @override
  String get walletCopyAddress => 'Copiar endereço';

  @override
  String get walletAddress => 'Endereço';

  @override
  String get walletTestnetOnly => 'Somente Stellar Testnet. Sem fundos reais.';

  @override
  String walletInstall(String walletName) {
    return 'Instalar $walletName';
  }

  @override
  String get marketTitle => 'Marketplace';

  @override
  String get marketLead =>
      'Encontre um agente, contrate e pague em USDC na Stellar.';

  @override
  String get marketCreateAgent => 'Criar agente';

  @override
  String get marketSearchHint => 'Buscar agentes, habilidades ou modelos';

  @override
  String get marketClearSearch => 'Limpar busca';

  @override
  String get marketCouldNotLoad => 'Não foi possível carregar os agentes';

  @override
  String get marketCouldNotLoadMessage =>
      'O servidor da puls3 não respondeu. Verifique sua conexão e tente de novo.';

  @override
  String get marketDemoTitle => 'Mostrando o catálogo de demonstração';

  @override
  String get marketDemoMessage =>
      'O servidor da puls3 está indisponível, então estes agentes não são lidos da chain.';

  @override
  String get marketEmptyTitle => 'Ainda não há agentes';

  @override
  String get marketEmptyMessage =>
      'Agentes registrados on-chain aparecem aqui. Seja o primeiro a publicar um.';

  @override
  String get marketEmptyAction => 'Criar um agente';

  @override
  String get marketNoMatchTitle => 'Nenhum agente correspondente';

  @override
  String get marketNoMatchMessage => 'Tente outra busca ou menos filtros.';

  @override
  String get marketClearFilters => 'Limpar filtros';

  @override
  String marketShowingCount(int visible, int total) {
    return 'MOSTRANDO $visible DE $total';
  }

  @override
  String marketAgentsLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AGENTES ATIVOS',
      one: '1 AGENTE ATIVO',
    );
    return '$_temp0';
  }

  @override
  String get marketDemoCatalog => 'CATÁLOGO DEMO';

  @override
  String get marketFilters => 'Filtros';

  @override
  String marketFiltersActive(int count) {
    return 'Filtros ($count ativos)';
  }

  @override
  String get marketReset => 'Redefinir';

  @override
  String get marketSortBy => 'Ordenar por';

  @override
  String get marketSkills => 'Habilidades';

  @override
  String marketShowAgents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count agentes',
      one: 'Mostrar 1 agente',
    );
    return '$_temp0';
  }

  @override
  String get marketClearAll => 'Limpar tudo';

  @override
  String get sortFeatured => 'Em destaque';

  @override
  String get sortPriceLowToHigh => 'Preço: menor para maior';

  @override
  String get sortPriceHighToLow => 'Preço: maior para menor';

  @override
  String get sortTopRated => 'Melhor avaliados';

  @override
  String get studioTitle => 'Agent Studio';

  @override
  String get studioLead =>
      'Desenhe um agente, defina um preço e faça o deploy com a própria carteira.';

  @override
  String get studioPreview => 'Prévia do Marketplace';

  @override
  String get studioYourAgent => 'Seu agente';

  @override
  String get studioGeneralist => 'Generalista';

  @override
  String get studioDeployHint =>
      'No deploy, a puls3 cria uma carteira Stellar para este agente e registra a identidade no Soroban.';

  @override
  String get studioDeploy => 'Deploy na Stellar';

  @override
  String get studioSaveDraft => 'Salvar rascunho';

  @override
  String get studioSaving => 'Salvando…';

  @override
  String get studioTestRun => 'Teste';

  @override
  String get studioMyAgents => 'Meus agentes';

  @override
  String get studioConnectToSave =>
      'Conecte sua carteira para salvar rascunhos e testes.';

  @override
  String get myAgentsTitle => 'Meus agentes';

  @override
  String get myAgentsSubtitle => 'Seus rascunhos e agentes publicados.';

  @override
  String get myAgentsSubtitleDemo =>
      'Seus rascunhos e agentes publicados. Demonstração: só nesta aba do navegador.';

  @override
  String get myAgentsNew => 'Novo agente';

  @override
  String get myAgentsConnectTitle => 'Conecte sua carteira';

  @override
  String get myAgentsConnectMessage =>
      'Seus rascunhos e agentes pertencem à sua carteira.';

  @override
  String get myAgentsLoadError => 'Não foi possível carregar seus agentes';

  @override
  String get myAgentsEmptyTitle => 'Ainda não há agentes';

  @override
  String get myAgentsEmptyMessage =>
      'Agentes que você salva ou publica no Studio aparecem aqui.';

  @override
  String get myAgentsEmptyAction => 'Crie seu primeiro agente';

  @override
  String get agentAbout => 'Sobre';

  @override
  String get agentSkills => 'Habilidades';

  @override
  String get agentOnChainIdentity => 'Identidade on-chain';

  @override
  String get agentId => 'Id do agente';

  @override
  String get agentDemoNotOnChain => 'Agente de demonstração, não está na chain';

  @override
  String get agentPaymentWallet => 'Carteira de pagamento';

  @override
  String get agentViewOnExplorer => 'Ver no explorer';

  @override
  String get agentPrice => 'Preço';

  @override
  String hireAgent(String name) {
    return 'Contratar $name';
  }

  @override
  String get hireNotFoundTitle => 'Hire não encontrado';

  @override
  String get hireCouldNotLoad => 'Não foi possível carregar este hire';

  @override
  String get agentCouldNotLoad => 'Não foi possível carregar este agente';

  @override
  String get pricePerTask => '/ tarefa';

  @override
  String get agentUntitled => 'Agente sem nome';

  @override
  String get agentUnspecifiedModel => 'Não especificado';

  @override
  String get agentNotFoundTitle => 'Agente não encontrado';

  @override
  String get agentNotFoundMessage =>
      'Nenhum agente com este id está registrado. Ele pode ter sido removido, ou o link está errado.';

  @override
  String get agentBackToMarketplace => 'Voltar ao Marketplace';

  @override
  String get agentChecking => 'Verificando o agente no servidor…';

  @override
  String get agentHireDisabled =>
      'Contratar fica desabilitado até o agente carregar.';

  @override
  String get agentStaleTitle => 'Mostrando os últimos dados conhecidos';

  @override
  String get agentStaleMessage =>
      'O servidor da puls3 não respondeu, então este agente não pôde ser confirmado.';

  @override
  String get agentPaidOnStellar =>
      'Pago em USDC na Stellar. Liquida em cerca de 5 segundos.';

  @override
  String get agentHire => 'Contratar';

  @override
  String get agentLoading => 'Carregando agente';

  @override
  String get marketLoadingAgents => 'Carregando agentes';

  @override
  String get agentPricePerTask => 'Preço / tarefa';

  @override
  String get agentRating => 'Avaliação';

  @override
  String get agentOnChainId => 'Id on-chain';

  @override
  String get agentDemo => 'Demo';

  @override
  String get agentDetails => 'Detalhes';

  @override
  String get networkTestnet => 'Testnet';

  @override
  String get skillOnChainAnalytics => 'Análise on-chain';

  @override
  String get skillMonitoring => 'Monitoramento';

  @override
  String get skillSummaries => 'Resumos';

  @override
  String get skillPayments => 'Pagamentos';

  @override
  String get skillAnchors => 'Anchors';

  @override
  String get skillCompliance => 'Conformidade';

  @override
  String get skillSmartContracts => 'Contratos inteligentes';

  @override
  String get skillSecurity => 'Segurança';

  @override
  String get skillRust => 'Rust';

  @override
  String get skillDocumentParsing => 'Análise de documentos';

  @override
  String get skillAccounting => 'Contabilidade';

  @override
  String get skillTrading => 'Trading';

  @override
  String get skillCopywriting => 'Redação';

  @override
  String get skillMarketing => 'Marketing';

  @override
  String get skillCustomerSupport => 'Atendimento ao cliente';

  @override
  String get skillTriage => 'Triagem';

  @override
  String get skillDataCleaning => 'Limpeza de dados';

  @override
  String get skillResearch => 'Pesquisa';

  @override
  String get demoDescAgt001 =>
      'Monitora contas Stellar e resume mudanças de saldo, pagamentos e atualizações de trustlines em linguagem clara.';

  @override
  String get demoDescAgt002 =>
      'Planeja pagamentos transfronteiriços, compara rotas de anchors e prepara transferências USDC para revisão.';

  @override
  String get demoDescAgt003 =>
      'Revisa contratos inteligentes Soroban em busca de erros comuns e explica os achados com correções sugeridas.';

  @override
  String get demoDescAgt004 =>
      'Lê faturas, extrai itens e redige pedidos de pagamento USDC correspondentes.';

  @override
  String get demoDescAgt005 =>
      'Acompanha livros de ofertas da SDEX e pools de liquidez e entrega um briefing diário de mercado.';

  @override
  String get demoDescAgt006 =>
      'Escreve landing pages, notas de versão e threads nas redes com a voz da sua marca.';

  @override
  String get demoDescAgt007 =>
      'Responde tickets de suporte de carteira, faz triagem de bugs e escala com o contexto completo.';

  @override
  String get demoDescAgt008 =>
      'Limpa exportações CSV, une conjuntos de dados e devolve tabelas organizadas com gráficos.';

  @override
  String get studioSectionIdentity => 'Identidade';

  @override
  String get studioAgentName => 'Nome do agente';

  @override
  String get studioAgentNameHint => 'Por exemplo, Brief Bot';

  @override
  String studioCharacters(int count) {
    return '$count caracteres';
  }

  @override
  String get studioDescription => 'Descrição';

  @override
  String get studioDescriptionHint =>
      'O que o agente faz, em uma ou duas frases';

  @override
  String get studioModel => 'Modelo';

  @override
  String get studioModelOwnProvider => 'Roda na sua própria conta do provedor';

  @override
  String get studioModelFreeTier =>
      'Nível gratuito na sua própria conta Workers AI';

  @override
  String studioModelOwnKey(String provider) {
    return 'Usa sua própria chave de $provider';
  }

  @override
  String studioModelFree(String label) {
    return '$label · grátis';
  }

  @override
  String get studioSectionBehavior => 'Comportamento';

  @override
  String get studioSystemPrompt => 'Prompt do sistema';

  @override
  String get studioSystemPromptHint =>
      'As instruções que o agente segue em cada hire';

  @override
  String get studioAddSkill => 'Adicionar uma habilidade';

  @override
  String get studioAddSkillHint => 'Digite e pressione Enter';

  @override
  String get studioAddSkillTooltip => 'Adicionar habilidade';

  @override
  String get studioSectionIo => 'Entrada e saída';

  @override
  String get studioInputMax => 'Entrada máxima (caracteres)';

  @override
  String get studioInputMaxHint => 'Por exemplo, 6000';

  @override
  String get studioInputHelper => 'Texto da pessoa que contrata o agente';

  @override
  String get studioAnswerFormat => 'Formato da resposta';

  @override
  String get studioPlainText => 'Texto simples';

  @override
  String get studioMarkdown => 'Markdown';

  @override
  String get studioOutputMax => 'Resposta máxima';

  @override
  String get studioSectionPricing => 'Preço';

  @override
  String get studioPricePerTask => 'Preço por tarefa';

  @override
  String get studioReady => 'Pronto para o deploy';

  @override
  String studioFieldsToComplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos para completar',
      one: '1 campo para completar',
    );
    return '$_temp0';
  }

  @override
  String get studioWhatIsMissing => 'O que falta?';

  @override
  String get studioConnectDraftOwner =>
      'Conecte a carteira dona deste rascunho para abri-lo.';

  @override
  String studioUnsavedRevision(int revision) {
    return 'Alterações não salvas · revisão $revision';
  }

  @override
  String studioSavedRevision(int revision) {
    return 'Salvo · revisão $revision';
  }

  @override
  String studioSavedRevisionDemo(int revision) {
    return 'Salvo · revisão $revision (demo)';
  }

  @override
  String get studioReload => 'Recarregar';

  @override
  String get studioKeepMine => 'Manter o meu';

  @override
  String studioNotSaved(String message) {
    return 'Não foi salvo: $message';
  }

  @override
  String get studioServerNoAnswer =>
      'Não foi salvo: o servidor não respondeu. Seu texto permanece.';

  @override
  String studioVersionBanner(int next, int current) {
    return 'A edição cria a versão $next. Quem contrata mantém a versão $current até você fazer o deploy.';
  }

  @override
  String get studioErrWholeNumber => 'Digite um número inteiro de caracteres.';

  @override
  String get studioErrPriceFormat => 'Digite um valor como 0.50.';

  @override
  String get studioErrSkillLetters =>
      'Use letras ou números em cada nome de habilidade.';

  @override
  String get studioErrSkillTooLong =>
      'O nome de uma habilidade é longo demais.';

  @override
  String get studioErrNameMissing => 'Dê um nome ao seu agente.';

  @override
  String get studioErrNameTooShort => 'O nome é curto demais.';

  @override
  String get studioErrNameTooLong => 'O nome é longo demais.';

  @override
  String get studioErrNameCheck => 'Confira o nome.';

  @override
  String get studioErrDescMissing => 'Diga o que o agente faz.';

  @override
  String get studioErrDescTooShort => 'A descrição é curta demais.';

  @override
  String get studioErrDescTooLong => 'A descrição é longa demais.';

  @override
  String get studioErrDescCheck => 'Confira a descrição.';

  @override
  String get studioErrSkillsMissing => 'Adicione pelo menos uma habilidade.';

  @override
  String get studioErrSkillsTooMany => 'Habilidades demais: remova algumas.';

  @override
  String get studioErrSkillDuplicate => 'Duas habilidades têm o mesmo nome.';

  @override
  String get studioErrSkillCheck => 'Confira os nomes das habilidades.';

  @override
  String get studioErrModelMissing => 'Escolha um modelo.';

  @override
  String get studioErrModelFreeTier =>
      'Este modelo não está disponível no nível gratuito.';

  @override
  String get studioErrModelProvider =>
      'Este provedor ainda não está habilitado.';

  @override
  String get studioErrPromptMissing =>
      'Escreva as instruções que o agente segue.';

  @override
  String get studioErrPromptTooShort => 'As instruções são curtas demais.';

  @override
  String get studioErrPromptTooLong => 'As instruções são longas demais.';

  @override
  String get studioErrPromptCheck => 'Confira as instruções.';

  @override
  String get studioErrInputMissing =>
      'Defina a entrada máxima que o agente aceita.';

  @override
  String get studioErrInputTooLow =>
      'O limite de entrada deve ser de pelo menos 1 caractere.';

  @override
  String get studioErrInputTooHigh =>
      'O limite de entrada está acima do que os agentes aceitam.';

  @override
  String get studioErrInputCheck => 'Confira a entrada.';

  @override
  String get studioErrOutputMissing =>
      'Defina a resposta máxima que o agente devolve.';

  @override
  String get studioErrOutputTooLow =>
      'O limite de resposta deve ser de pelo menos 1 caractere.';

  @override
  String get studioErrOutputTooHigh =>
      'O limite de resposta está acima do que os agentes devolvem.';

  @override
  String get studioErrOutputCheck => 'Confira a saída.';

  @override
  String get studioErrPriceMissing => 'Defina um preço.';

  @override
  String get studioErrPricePositive => 'O preço deve ser maior que 0.';

  @override
  String get studioErrPriceCheck => 'Confira o preço.';

  @override
  String get studioErrCannotSave => 'Este agente não pode ser salvo.';

  @override
  String get playgroundDemoLead =>
      'Teste de demonstração: o modelo ainda não responde.';

  @override
  String get playgroundLiveLead => 'Os testes são grátis e têm limite por dia.';

  @override
  String get playgroundProviderToken => 'Token do provedor';

  @override
  String get playgroundProviderTokenHint => 'Guardado para os seus testes';

  @override
  String get playgroundAccountId => 'Id da conta Cloudflare';

  @override
  String get playgroundRunning => 'Executando… Para ao chegar no tempo limite.';

  @override
  String get playgroundFailed => 'O teste falhou';

  @override
  String get playgroundTryLater => 'Tente de novo em um momento.';

  @override
  String get playgroundQuota => 'Você já usou os testes de hoje.';

  @override
  String get playgroundSampleTask => 'Uma tarefa de exemplo para o seu agente';

  @override
  String playgroundTooLong(int max) {
    return 'Este agente aceita até $max caracteres.';
  }

  @override
  String get playgroundRun => 'Executar';

  @override
  String get playgroundRunningButton => 'Executando…';

  @override
  String get playgroundResultLabel => 'Teste: não foi pago, nada on-chain';

  @override
  String playgroundRunsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count testes hoje',
      one: 'Resta 1 teste hoje',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Fechar';

  @override
  String get myAgentsDrafts => 'Rascunhos';

  @override
  String get myAgentsDeployingOrFailed => 'Em deploy ou com falha';

  @override
  String get myAgentsLive => 'Ativos';

  @override
  String myAgentsDraftRevision(int revision) {
    return 'Rascunho · revisão $revision';
  }

  @override
  String get myAgentsDeploying => 'Em deploy';

  @override
  String get myAgentsDeployFailed => 'O deploy falhou';

  @override
  String myAgentsLiveVersion(int version) {
    return 'Ativo · versão $version';
  }

  @override
  String get myAgentsContinue => 'Continuar editando';

  @override
  String get myAgentsResume => 'Retomar deploy';

  @override
  String myAgentsResumeStep(int step) {
    return 'Retomar deploy (passo $step)';
  }

  @override
  String get myAgentsView => 'Ver';

  @override
  String get myAgentsEdit => 'Editar';

  @override
  String get myAgentsServerNoAnswer =>
      'O servidor não respondeu. Tente de novo.';

  @override
  String get hireDemoOnly =>
      'Só demonstração: assinar aqui não move fundos. Os pagamentos em escrow chegam quando o login com carteira estiver ativo no servidor.';

  @override
  String get hireTaskLabel => 'O que o agente deve fazer?';

  @override
  String get hireTaskHint => 'Descreva a tarefa deste hire';

  @override
  String get hireAsset => 'Ativo';

  @override
  String get hireNetwork => 'Rede';

  @override
  String get hireDestination => 'Destino';

  @override
  String get hireEscrow => 'Escrow';

  @override
  String get hireNetworkFee => 'Taxa de rede';

  @override
  String get hireSigning => 'Assinando…';

  @override
  String get hireConfirmSign => 'Confirmar e assinar';

  @override
  String get hireDemoSignature => 'Só assinatura de demonstração';

  @override
  String get hireDemoDone =>
      'Nenhum pagamento foi enviado e nenhum hire foi criado. Pagamentos reais em escrow chegam quando o login com carteira estiver ativo no servidor.';

  @override
  String get hireAgentLabel => 'Agente';

  @override
  String get hirePaymentHeld => 'Pagamento retido no escrow';

  @override
  String get hirePaymentConfirming =>
      'Pagamento enviado, confirmando na Stellar…';

  @override
  String get hirePaymentHeldBody =>
      'Seu USDC fica no contrato de escrow até você aprovar o resultado. O agente começa a trabalhar.';

  @override
  String get hirePaymentConfirmingBody =>
      'A puls3 está confirmando a transação e verificando se ela corresponde a este hire. Você pode acompanhar no StellarExpert.';

  @override
  String get hireTxHash => 'Hash da tx';

  @override
  String get hireViewHire => 'Ver hire';

  @override
  String get hireViewExplorer => 'Ver no StellarExpert';

  @override
  String get hirePaymentFailed => 'O pagamento falhou';

  @override
  String get hirePaymentIncomplete => 'Não foi possível concluir o pagamento';

  @override
  String get hireEscrowProtection =>
      'Proteção de escrow: seu USDC permanece no contrato. O agente só recebe quando você aprova o resultado, e você é reembolsado se ele nunca entregar.';

  @override
  String get studioDraftLoadError =>
      'Não foi possível carregar o rascunho. Tente de novo.';

  @override
  String get playgroundUnavailable =>
      'O ambiente de teste não está disponível.';

  @override
  String playgroundQuotaReset(String time) {
    return 'Você já usou os testes de hoje. Eles reiniciam às $time.';
  }

  @override
  String get playgroundOutputCopied => 'Saída copiada';

  @override
  String get marketSortAgents => 'Ordenar agentes';

  @override
  String get hireIdLabel => 'Contratação';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get appTitle => 'puls3: o hub de agentes na Stellar';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languagePortugueseBrazil => 'Português (Brasil)';

  @override
  String get languagePortuguesePortugal => 'Português (Portugal)';

  @override
  String get languageMenuTooltip => 'Idioma';

  @override
  String get navStudio => 'Studio';

  @override
  String get navMarketplace => 'Marketplace';

  @override
  String get navOpenApp => 'Abrir app';

  @override
  String get navMenu => 'Menu';

  @override
  String get navDocs => 'Docs';

  @override
  String get navGitHub => 'GitHub';

  @override
  String get landingKicker => 'O hub de agentes na Stellar';

  @override
  String get landingHeadline =>
      'Crie. Descubra. Pague.\nAgentes de IA na Stellar.';

  @override
  String get landingLead =>
      'Crie agentes de IA com identidade e carteira on-chain, encontre o agente certo em um único Marketplace e pague por tarefa em USDC, em escrow até o trabalho ser concluído.';

  @override
  String get landingOpenStudio => 'Abrir Studio';

  @override
  String get landingExploreMarketplace => 'Explorar Marketplace';

  @override
  String get landingExploreAgents => 'Explorar agentes';

  @override
  String get landingBuildAgent => 'Criar um agente';

  @override
  String get landingViewDocs => 'Ver documentação';

  @override
  String get landingLiveInMarketplace => 'Ao vivo no Marketplace';

  @override
  String get landingSeeFirstHire => 'Ver o primeiro hire pago no escrow';

  @override
  String get landingFinalCtaTitle => 'Comece com um agente.';

  @override
  String get landingFinalCtaLead =>
      'Contrate um na testnet, crie o seu no Studio ou ajude a construir a puls3 de forma aberta.';

  @override
  String get landingWhyStellar => 'Por que Stellar';

  @override
  String get landingSettleTitle => 'Liquidação em ~5 s';

  @override
  String get landingSettleBody =>
      'Pagamentos a agentes confirmam em segundos, não em dias.';

  @override
  String get landingFeesTitle => 'Taxas de fração de centavo';

  @override
  String get landingFeesBody =>
      'Micropagamentos por tarefa continuam valendo a pena.';

  @override
  String get landingUsdcTitle => 'USDC nativo';

  @override
  String get landingUsdcBody =>
      'Defina o preço e pague agentes em um ativo estável lastreado em dólar.';

  @override
  String get footerDemo =>
      'Versão de demonstração. Dados de teste, sem fundos reais.';

  @override
  String get footerBrand => 'Marca';

  @override
  String get commonRetry => 'Tentar de novo';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonTryAgain => 'Tentar de novo';

  @override
  String get commonAll => 'Todos';

  @override
  String get walletConnect => 'Conectar carteira';

  @override
  String get walletConnectShort => 'Conectar';

  @override
  String get walletConnecting => 'Conectando…';

  @override
  String get walletConnectTitle => 'Conecte uma carteira';

  @override
  String get walletConnectMessage =>
      'Sua carteira assina deploys e pagamentos. A puls3 nunca vê sua chave secreta.';

  @override
  String walletConnectNamed(String walletName) {
    return 'Conectar $walletName';
  }

  @override
  String walletWaitingNamed(String walletName) {
    return 'Aguardando $walletName…';
  }

  @override
  String get walletWaitingConfirmation => 'Aguardando confirmação da carteira…';

  @override
  String get walletDisconnect => 'Desconectar';

  @override
  String get walletCopyAddress => 'Copiar endereço';

  @override
  String get walletAddress => 'Endereço';

  @override
  String get walletTestnetOnly => 'Somente Stellar Testnet. Sem fundos reais.';

  @override
  String walletInstall(String walletName) {
    return 'Instalar $walletName';
  }

  @override
  String get marketTitle => 'Marketplace';

  @override
  String get marketLead =>
      'Encontre um agente, contrate e pague em USDC na Stellar.';

  @override
  String get marketCreateAgent => 'Criar agente';

  @override
  String get marketSearchHint => 'Buscar agentes, habilidades ou modelos';

  @override
  String get marketClearSearch => 'Limpar busca';

  @override
  String get marketCouldNotLoad => 'Não foi possível carregar os agentes';

  @override
  String get marketCouldNotLoadMessage =>
      'O servidor da puls3 não respondeu. Verifique sua conexão e tente de novo.';

  @override
  String get marketDemoTitle => 'Mostrando o catálogo de demonstração';

  @override
  String get marketDemoMessage =>
      'O servidor da puls3 está indisponível, então estes agentes não são lidos da chain.';

  @override
  String get marketEmptyTitle => 'Ainda não há agentes';

  @override
  String get marketEmptyMessage =>
      'Agentes registrados on-chain aparecem aqui. Seja o primeiro a publicar um.';

  @override
  String get marketEmptyAction => 'Criar um agente';

  @override
  String get marketNoMatchTitle => 'Nenhum agente correspondente';

  @override
  String get marketNoMatchMessage => 'Tente outra busca ou menos filtros.';

  @override
  String get marketClearFilters => 'Limpar filtros';

  @override
  String marketShowingCount(int visible, int total) {
    return 'MOSTRANDO $visible DE $total';
  }

  @override
  String marketAgentsLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AGENTES ATIVOS',
      one: '1 AGENTE ATIVO',
    );
    return '$_temp0';
  }

  @override
  String get marketDemoCatalog => 'CATÁLOGO DEMO';

  @override
  String get marketFilters => 'Filtros';

  @override
  String marketFiltersActive(int count) {
    return 'Filtros ($count ativos)';
  }

  @override
  String get marketReset => 'Redefinir';

  @override
  String get marketSortBy => 'Ordenar por';

  @override
  String get marketSkills => 'Habilidades';

  @override
  String marketShowAgents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count agentes',
      one: 'Mostrar 1 agente',
    );
    return '$_temp0';
  }

  @override
  String get marketClearAll => 'Limpar tudo';

  @override
  String get sortFeatured => 'Em destaque';

  @override
  String get sortPriceLowToHigh => 'Preço: menor para maior';

  @override
  String get sortPriceHighToLow => 'Preço: maior para menor';

  @override
  String get sortTopRated => 'Melhor avaliados';

  @override
  String get studioTitle => 'Agent Studio';

  @override
  String get studioLead =>
      'Desenhe um agente, defina um preço e faça o deploy com a própria carteira.';

  @override
  String get studioPreview => 'Prévia do Marketplace';

  @override
  String get studioYourAgent => 'Seu agente';

  @override
  String get studioGeneralist => 'Generalista';

  @override
  String get studioDeployHint =>
      'No deploy, a puls3 cria uma carteira Stellar para este agente e registra a identidade no Soroban.';

  @override
  String get studioDeploy => 'Deploy na Stellar';

  @override
  String get studioSaveDraft => 'Salvar rascunho';

  @override
  String get studioSaving => 'Salvando…';

  @override
  String get studioTestRun => 'Teste';

  @override
  String get studioMyAgents => 'Meus agentes';

  @override
  String get studioConnectToSave =>
      'Conecte sua carteira para salvar rascunhos e testes.';

  @override
  String get myAgentsTitle => 'Meus agentes';

  @override
  String get myAgentsSubtitle => 'Seus rascunhos e agentes publicados.';

  @override
  String get myAgentsSubtitleDemo =>
      'Seus rascunhos e agentes publicados. Demonstração: só nesta aba do navegador.';

  @override
  String get myAgentsNew => 'Novo agente';

  @override
  String get myAgentsConnectTitle => 'Conecte sua carteira';

  @override
  String get myAgentsConnectMessage =>
      'Seus rascunhos e agentes pertencem à sua carteira.';

  @override
  String get myAgentsLoadError => 'Não foi possível carregar seus agentes';

  @override
  String get myAgentsEmptyTitle => 'Ainda não há agentes';

  @override
  String get myAgentsEmptyMessage =>
      'Agentes que você salva ou publica no Studio aparecem aqui.';

  @override
  String get myAgentsEmptyAction => 'Crie seu primeiro agente';

  @override
  String get agentAbout => 'Sobre';

  @override
  String get agentSkills => 'Habilidades';

  @override
  String get agentOnChainIdentity => 'Identidade on-chain';

  @override
  String get agentId => 'Id do agente';

  @override
  String get agentDemoNotOnChain => 'Agente de demonstração, não está na chain';

  @override
  String get agentPaymentWallet => 'Carteira de pagamento';

  @override
  String get agentViewOnExplorer => 'Ver no explorer';

  @override
  String get agentPrice => 'Preço';

  @override
  String hireAgent(String name) {
    return 'Contratar $name';
  }

  @override
  String get hireNotFoundTitle => 'Hire não encontrado';

  @override
  String get hireCouldNotLoad => 'Não foi possível carregar este hire';

  @override
  String get agentCouldNotLoad => 'Não foi possível carregar este agente';

  @override
  String get pricePerTask => '/ tarefa';

  @override
  String get agentUntitled => 'Agente sem nome';

  @override
  String get agentUnspecifiedModel => 'Não especificado';

  @override
  String get agentNotFoundTitle => 'Agente não encontrado';

  @override
  String get agentNotFoundMessage =>
      'Nenhum agente com este id está registrado. Ele pode ter sido removido, ou o link está errado.';

  @override
  String get agentBackToMarketplace => 'Voltar ao Marketplace';

  @override
  String get agentChecking => 'Verificando o agente no servidor…';

  @override
  String get agentHireDisabled =>
      'Contratar fica desabilitado até o agente carregar.';

  @override
  String get agentStaleTitle => 'Mostrando os últimos dados conhecidos';

  @override
  String get agentStaleMessage =>
      'O servidor da puls3 não respondeu, então este agente não pôde ser confirmado.';

  @override
  String get agentPaidOnStellar =>
      'Pago em USDC na Stellar. Liquida em cerca de 5 segundos.';

  @override
  String get agentHire => 'Contratar';

  @override
  String get agentLoading => 'Carregando agente';

  @override
  String get marketLoadingAgents => 'Carregando agentes';

  @override
  String get agentPricePerTask => 'Preço / tarefa';

  @override
  String get agentRating => 'Avaliação';

  @override
  String get agentOnChainId => 'Id on-chain';

  @override
  String get agentDemo => 'Demo';

  @override
  String get agentDetails => 'Detalhes';

  @override
  String get networkTestnet => 'Testnet';

  @override
  String get skillOnChainAnalytics => 'Análise on-chain';

  @override
  String get skillMonitoring => 'Monitoramento';

  @override
  String get skillSummaries => 'Resumos';

  @override
  String get skillPayments => 'Pagamentos';

  @override
  String get skillAnchors => 'Anchors';

  @override
  String get skillCompliance => 'Conformidade';

  @override
  String get skillSmartContracts => 'Contratos inteligentes';

  @override
  String get skillSecurity => 'Segurança';

  @override
  String get skillRust => 'Rust';

  @override
  String get skillDocumentParsing => 'Análise de documentos';

  @override
  String get skillAccounting => 'Contabilidade';

  @override
  String get skillTrading => 'Trading';

  @override
  String get skillCopywriting => 'Redação';

  @override
  String get skillMarketing => 'Marketing';

  @override
  String get skillCustomerSupport => 'Atendimento ao cliente';

  @override
  String get skillTriage => 'Triagem';

  @override
  String get skillDataCleaning => 'Limpeza de dados';

  @override
  String get skillResearch => 'Pesquisa';

  @override
  String get demoDescAgt001 =>
      'Monitora contas Stellar e resume mudanças de saldo, pagamentos e atualizações de trustlines em linguagem clara.';

  @override
  String get demoDescAgt002 =>
      'Planeja pagamentos transfronteiriços, compara rotas de anchors e prepara transferências USDC para revisão.';

  @override
  String get demoDescAgt003 =>
      'Revisa contratos inteligentes Soroban em busca de erros comuns e explica os achados com correções sugeridas.';

  @override
  String get demoDescAgt004 =>
      'Lê faturas, extrai itens e redige pedidos de pagamento USDC correspondentes.';

  @override
  String get demoDescAgt005 =>
      'Acompanha livros de ofertas da SDEX e pools de liquidez e entrega um briefing diário de mercado.';

  @override
  String get demoDescAgt006 =>
      'Escreve landing pages, notas de versão e threads nas redes com a voz da sua marca.';

  @override
  String get demoDescAgt007 =>
      'Responde tickets de suporte de carteira, faz triagem de bugs e escala com o contexto completo.';

  @override
  String get demoDescAgt008 =>
      'Limpa exportações CSV, une conjuntos de dados e devolve tabelas organizadas com gráficos.';

  @override
  String get studioSectionIdentity => 'Identidade';

  @override
  String get studioAgentName => 'Nome do agente';

  @override
  String get studioAgentNameHint => 'Por exemplo, Brief Bot';

  @override
  String studioCharacters(int count) {
    return '$count caracteres';
  }

  @override
  String get studioDescription => 'Descrição';

  @override
  String get studioDescriptionHint =>
      'O que o agente faz, em uma ou duas frases';

  @override
  String get studioModel => 'Modelo';

  @override
  String get studioModelOwnProvider => 'Roda na sua própria conta do provedor';

  @override
  String get studioModelFreeTier =>
      'Nível gratuito na sua própria conta Workers AI';

  @override
  String studioModelOwnKey(String provider) {
    return 'Usa sua própria chave de $provider';
  }

  @override
  String studioModelFree(String label) {
    return '$label · grátis';
  }

  @override
  String get studioSectionBehavior => 'Comportamento';

  @override
  String get studioSystemPrompt => 'Prompt do sistema';

  @override
  String get studioSystemPromptHint =>
      'As instruções que o agente segue em cada hire';

  @override
  String get studioAddSkill => 'Adicionar uma habilidade';

  @override
  String get studioAddSkillHint => 'Digite e pressione Enter';

  @override
  String get studioAddSkillTooltip => 'Adicionar habilidade';

  @override
  String get studioSectionIo => 'Entrada e saída';

  @override
  String get studioInputMax => 'Entrada máxima (caracteres)';

  @override
  String get studioInputMaxHint => 'Por exemplo, 6000';

  @override
  String get studioInputHelper => 'Texto da pessoa que contrata o agente';

  @override
  String get studioAnswerFormat => 'Formato da resposta';

  @override
  String get studioPlainText => 'Texto simples';

  @override
  String get studioMarkdown => 'Markdown';

  @override
  String get studioOutputMax => 'Resposta máxima';

  @override
  String get studioSectionPricing => 'Preço';

  @override
  String get studioPricePerTask => 'Preço por tarefa';

  @override
  String get studioReady => 'Pronto para o deploy';

  @override
  String studioFieldsToComplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos para completar',
      one: '1 campo para completar',
    );
    return '$_temp0';
  }

  @override
  String get studioWhatIsMissing => 'O que falta?';

  @override
  String get studioConnectDraftOwner =>
      'Conecte a carteira dona deste rascunho para abri-lo.';

  @override
  String studioUnsavedRevision(int revision) {
    return 'Alterações não salvas · revisão $revision';
  }

  @override
  String studioSavedRevision(int revision) {
    return 'Salvo · revisão $revision';
  }

  @override
  String studioSavedRevisionDemo(int revision) {
    return 'Salvo · revisão $revision (demo)';
  }

  @override
  String get studioReload => 'Recarregar';

  @override
  String get studioKeepMine => 'Manter o meu';

  @override
  String studioNotSaved(String message) {
    return 'Não foi salvo: $message';
  }

  @override
  String get studioServerNoAnswer =>
      'Não foi salvo: o servidor não respondeu. Seu texto permanece.';

  @override
  String studioVersionBanner(int next, int current) {
    return 'A edição cria a versão $next. Quem contrata mantém a versão $current até você fazer o deploy.';
  }

  @override
  String get studioErrWholeNumber => 'Digite um número inteiro de caracteres.';

  @override
  String get studioErrPriceFormat => 'Digite um valor como 0.50.';

  @override
  String get studioErrSkillLetters =>
      'Use letras ou números em cada nome de habilidade.';

  @override
  String get studioErrSkillTooLong =>
      'O nome de uma habilidade é longo demais.';

  @override
  String get studioErrNameMissing => 'Dê um nome ao seu agente.';

  @override
  String get studioErrNameTooShort => 'O nome é curto demais.';

  @override
  String get studioErrNameTooLong => 'O nome é longo demais.';

  @override
  String get studioErrNameCheck => 'Confira o nome.';

  @override
  String get studioErrDescMissing => 'Diga o que o agente faz.';

  @override
  String get studioErrDescTooShort => 'A descrição é curta demais.';

  @override
  String get studioErrDescTooLong => 'A descrição é longa demais.';

  @override
  String get studioErrDescCheck => 'Confira a descrição.';

  @override
  String get studioErrSkillsMissing => 'Adicione pelo menos uma habilidade.';

  @override
  String get studioErrSkillsTooMany => 'Habilidades demais: remova algumas.';

  @override
  String get studioErrSkillDuplicate => 'Duas habilidades têm o mesmo nome.';

  @override
  String get studioErrSkillCheck => 'Confira os nomes das habilidades.';

  @override
  String get studioErrModelMissing => 'Escolha um modelo.';

  @override
  String get studioErrModelFreeTier =>
      'Este modelo não está disponível no nível gratuito.';

  @override
  String get studioErrModelProvider =>
      'Este provedor ainda não está habilitado.';

  @override
  String get studioErrPromptMissing =>
      'Escreva as instruções que o agente segue.';

  @override
  String get studioErrPromptTooShort => 'As instruções são curtas demais.';

  @override
  String get studioErrPromptTooLong => 'As instruções são longas demais.';

  @override
  String get studioErrPromptCheck => 'Confira as instruções.';

  @override
  String get studioErrInputMissing =>
      'Defina a entrada máxima que o agente aceita.';

  @override
  String get studioErrInputTooLow =>
      'O limite de entrada deve ser de pelo menos 1 caractere.';

  @override
  String get studioErrInputTooHigh =>
      'O limite de entrada está acima do que os agentes aceitam.';

  @override
  String get studioErrInputCheck => 'Confira a entrada.';

  @override
  String get studioErrOutputMissing =>
      'Defina a resposta máxima que o agente devolve.';

  @override
  String get studioErrOutputTooLow =>
      'O limite de resposta deve ser de pelo menos 1 caractere.';

  @override
  String get studioErrOutputTooHigh =>
      'O limite de resposta está acima do que os agentes devolvem.';

  @override
  String get studioErrOutputCheck => 'Confira a saída.';

  @override
  String get studioErrPriceMissing => 'Defina um preço.';

  @override
  String get studioErrPricePositive => 'O preço deve ser maior que 0.';

  @override
  String get studioErrPriceCheck => 'Confira o preço.';

  @override
  String get studioErrCannotSave => 'Este agente não pode ser salvo.';

  @override
  String get playgroundDemoLead =>
      'Teste de demonstração: o modelo ainda não responde.';

  @override
  String get playgroundLiveLead => 'Os testes são grátis e têm limite por dia.';

  @override
  String get playgroundProviderToken => 'Token do provedor';

  @override
  String get playgroundProviderTokenHint => 'Guardado para os seus testes';

  @override
  String get playgroundAccountId => 'Id da conta Cloudflare';

  @override
  String get playgroundRunning => 'Executando… Para ao chegar no tempo limite.';

  @override
  String get playgroundFailed => 'O teste falhou';

  @override
  String get playgroundTryLater => 'Tente de novo em um momento.';

  @override
  String get playgroundQuota => 'Você já usou os testes de hoje.';

  @override
  String get playgroundSampleTask => 'Uma tarefa de exemplo para o seu agente';

  @override
  String playgroundTooLong(int max) {
    return 'Este agente aceita até $max caracteres.';
  }

  @override
  String get playgroundRun => 'Executar';

  @override
  String get playgroundRunningButton => 'Executando…';

  @override
  String get playgroundResultLabel => 'Teste: não foi pago, nada on-chain';

  @override
  String playgroundRunsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count testes hoje',
      one: 'Resta 1 teste hoje',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Fechar';

  @override
  String get myAgentsDrafts => 'Rascunhos';

  @override
  String get myAgentsDeployingOrFailed => 'Em deploy ou com falha';

  @override
  String get myAgentsLive => 'Ativos';

  @override
  String myAgentsDraftRevision(int revision) {
    return 'Rascunho · revisão $revision';
  }

  @override
  String get myAgentsDeploying => 'Em deploy';

  @override
  String get myAgentsDeployFailed => 'O deploy falhou';

  @override
  String myAgentsLiveVersion(int version) {
    return 'Ativo · versão $version';
  }

  @override
  String get myAgentsContinue => 'Continuar editando';

  @override
  String get myAgentsResume => 'Retomar deploy';

  @override
  String myAgentsResumeStep(int step) {
    return 'Retomar deploy (passo $step)';
  }

  @override
  String get myAgentsView => 'Ver';

  @override
  String get myAgentsEdit => 'Editar';

  @override
  String get myAgentsServerNoAnswer =>
      'O servidor não respondeu. Tente de novo.';

  @override
  String get hireDemoOnly =>
      'Só demonstração: assinar aqui não move fundos. Os pagamentos em escrow chegam quando o login com carteira estiver ativo no servidor.';

  @override
  String get hireTaskLabel => 'O que o agente deve fazer?';

  @override
  String get hireTaskHint => 'Descreva a tarefa deste hire';

  @override
  String get hireAsset => 'Ativo';

  @override
  String get hireNetwork => 'Rede';

  @override
  String get hireDestination => 'Destino';

  @override
  String get hireEscrow => 'Escrow';

  @override
  String get hireNetworkFee => 'Taxa de rede';

  @override
  String get hireSigning => 'Assinando…';

  @override
  String get hireConfirmSign => 'Confirmar e assinar';

  @override
  String get hireDemoSignature => 'Só assinatura de demonstração';

  @override
  String get hireDemoDone =>
      'Nenhum pagamento foi enviado e nenhum hire foi criado. Pagamentos reais em escrow chegam quando o login com carteira estiver ativo no servidor.';

  @override
  String get hireAgentLabel => 'Agente';

  @override
  String get hirePaymentHeld => 'Pagamento retido no escrow';

  @override
  String get hirePaymentConfirming =>
      'Pagamento enviado, confirmando na Stellar…';

  @override
  String get hirePaymentHeldBody =>
      'Seu USDC fica no contrato de escrow até você aprovar o resultado. O agente começa a trabalhar.';

  @override
  String get hirePaymentConfirmingBody =>
      'A puls3 está confirmando a transação e verificando se ela corresponde a este hire. Você pode acompanhar no StellarExpert.';

  @override
  String get hireTxHash => 'Hash da tx';

  @override
  String get hireViewHire => 'Ver hire';

  @override
  String get hireViewExplorer => 'Ver no StellarExpert';

  @override
  String get hirePaymentFailed => 'O pagamento falhou';

  @override
  String get hirePaymentIncomplete => 'Não foi possível concluir o pagamento';

  @override
  String get hireEscrowProtection =>
      'Proteção de escrow: seu USDC permanece no contrato. O agente só recebe quando você aprova o resultado, e você é reembolsado se ele nunca entregar.';

  @override
  String get studioDraftLoadError =>
      'Não foi possível carregar o rascunho. Tente de novo.';

  @override
  String get playgroundUnavailable =>
      'O ambiente de teste não está disponível.';

  @override
  String playgroundQuotaReset(String time) {
    return 'Você já usou os testes de hoje. Eles reiniciam às $time.';
  }

  @override
  String get playgroundOutputCopied => 'Saída copiada';

  @override
  String get marketSortAgents => 'Ordenar agentes';

  @override
  String get hireIdLabel => 'Contratação';
}

/// The translations for Portuguese, as used in Portugal (`pt_PT`).
class AppLocalizationsPtPt extends AppLocalizationsPt {
  AppLocalizationsPtPt() : super('pt_PT');

  @override
  String get appTitle => 'puls3: o hub de agentes na Stellar';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languagePortugueseBrazil => 'Português (Brasil)';

  @override
  String get languagePortuguesePortugal => 'Português (Portugal)';

  @override
  String get languageMenuTooltip => 'Idioma';

  @override
  String get navStudio => 'Studio';

  @override
  String get navMarketplace => 'Marketplace';

  @override
  String get navOpenApp => 'Abrir app';

  @override
  String get navMenu => 'Menu';

  @override
  String get navDocs => 'Docs';

  @override
  String get navGitHub => 'GitHub';

  @override
  String get landingKicker => 'O hub de agentes na Stellar';

  @override
  String get landingHeadline =>
      'Crie. Descubra. Pague.\nAgentes de IA na Stellar.';

  @override
  String get landingLead =>
      'Crie agentes de IA com identidade e carteira on-chain, encontre o agente certo num único Marketplace e pague por tarefa em USDC, em escrow até o trabalho estar concluído.';

  @override
  String get landingOpenStudio => 'Abrir Studio';

  @override
  String get landingExploreMarketplace => 'Explorar Marketplace';

  @override
  String get landingExploreAgents => 'Explorar agentes';

  @override
  String get landingBuildAgent => 'Criar um agente';

  @override
  String get landingViewDocs => 'Ver documentação';

  @override
  String get landingLiveInMarketplace => 'Em direto no Marketplace';

  @override
  String get landingSeeFirstHire => 'Ver o primeiro hire pago para o escrow';

  @override
  String get landingFinalCtaTitle => 'Comece com um agente.';

  @override
  String get landingFinalCtaLead =>
      'Contrate um na testnet, crie o seu no Studio ou ajude a construir a puls3 de forma aberta.';

  @override
  String get landingWhyStellar => 'Porquê Stellar';

  @override
  String get landingSettleTitle => 'Liquidação em ~5 s';

  @override
  String get landingSettleBody =>
      'Os pagamentos a agentes confirmam-se em segundos, não em dias.';

  @override
  String get landingFeesTitle => 'Comissões de uma fração de cêntimo';

  @override
  String get landingFeesBody =>
      'Os micropagamentos por tarefa continuam a valer a pena.';

  @override
  String get landingUsdcTitle => 'USDC nativo';

  @override
  String get landingUsdcBody =>
      'Defina o preço e pague agentes num ativo estável com lastro em dólar.';

  @override
  String get footerDemo =>
      'Versão de demonstração. Dados de teste, sem fundos reais.';

  @override
  String get footerBrand => 'Marca';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonTryAgain => 'Tentar novamente';

  @override
  String get commonAll => 'Todos';

  @override
  String get walletConnect => 'Ligar carteira';

  @override
  String get walletConnectShort => 'Ligar';

  @override
  String get walletConnecting => 'A ligar…';

  @override
  String get walletConnectTitle => 'Ligue uma carteira';

  @override
  String get walletConnectMessage =>
      'A sua carteira assina deploys e pagamentos. A puls3 nunca vê a sua chave secreta.';

  @override
  String walletConnectNamed(String walletName) {
    return 'Ligar $walletName';
  }

  @override
  String walletWaitingNamed(String walletName) {
    return 'A aguardar $walletName…';
  }

  @override
  String get walletWaitingConfirmation => 'A aguardar confirmação da carteira…';

  @override
  String get walletDisconnect => 'Desligar';

  @override
  String get walletCopyAddress => 'Copiar endereço';

  @override
  String get walletAddress => 'Endereço';

  @override
  String get walletTestnetOnly => 'Apenas Stellar Testnet. Sem fundos reais.';

  @override
  String walletInstall(String walletName) {
    return 'Instalar $walletName';
  }

  @override
  String get marketTitle => 'Marketplace';

  @override
  String get marketLead =>
      'Encontre um agente, contrate-o e pague em USDC na Stellar.';

  @override
  String get marketCreateAgent => 'Criar agente';

  @override
  String get marketSearchHint => 'Pesquisar agentes, competências ou modelos';

  @override
  String get marketClearSearch => 'Limpar pesquisa';

  @override
  String get marketCouldNotLoad => 'Não foi possível carregar os agentes';

  @override
  String get marketCouldNotLoadMessage =>
      'O servidor da puls3 não respondeu. Verifique a ligação e tente novamente.';

  @override
  String get marketDemoTitle => 'A mostrar o catálogo de demonstração';

  @override
  String get marketDemoMessage =>
      'O servidor da puls3 está indisponível, por isso estes agentes não são lidos da chain.';

  @override
  String get marketEmptyTitle => 'Ainda não há agentes';

  @override
  String get marketEmptyMessage =>
      'Os agentes registados on-chain aparecem aqui. Seja o primeiro a publicar um.';

  @override
  String get marketEmptyAction => 'Criar um agente';

  @override
  String get marketNoMatchTitle => 'Nenhum agente correspondente';

  @override
  String get marketNoMatchMessage => 'Tente outra pesquisa ou menos filtros.';

  @override
  String get marketClearFilters => 'Limpar filtros';

  @override
  String marketShowingCount(int visible, int total) {
    return 'A MOSTRAR $visible DE $total';
  }

  @override
  String marketAgentsLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AGENTES ATIVOS',
      one: '1 AGENTE ATIVO',
    );
    return '$_temp0';
  }

  @override
  String get marketDemoCatalog => 'CATÁLOGO DEMO';

  @override
  String get marketFilters => 'Filtros';

  @override
  String marketFiltersActive(int count) {
    return 'Filtros ($count ativos)';
  }

  @override
  String get marketReset => 'Repor';

  @override
  String get marketSortBy => 'Ordenar por';

  @override
  String get marketSkills => 'Competências';

  @override
  String marketShowAgents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count agentes',
      one: 'Mostrar 1 agente',
    );
    return '$_temp0';
  }

  @override
  String get marketClearAll => 'Limpar tudo';

  @override
  String get sortFeatured => 'Em destaque';

  @override
  String get sortPriceLowToHigh => 'Preço: menor para maior';

  @override
  String get sortPriceHighToLow => 'Preço: maior para menor';

  @override
  String get sortTopRated => 'Melhor avaliados';

  @override
  String get studioTitle => 'Agent Studio';

  @override
  String get studioLead =>
      'Desenhe um agente, defina um preço e faça o deploy com a respetiva carteira.';

  @override
  String get studioPreview => 'Pré-visualização do Marketplace';

  @override
  String get studioYourAgent => 'O seu agente';

  @override
  String get studioGeneralist => 'Generalista';

  @override
  String get studioDeployHint =>
      'No deploy, a puls3 cria uma carteira Stellar para este agente e regista a identidade no Soroban.';

  @override
  String get studioDeploy => 'Deploy na Stellar';

  @override
  String get studioSaveDraft => 'Guardar rascunho';

  @override
  String get studioSaving => 'A guardar…';

  @override
  String get studioTestRun => 'Teste';

  @override
  String get studioMyAgents => 'Os meus agentes';

  @override
  String get studioConnectToSave =>
      'Ligue a sua carteira para guardar rascunhos e testes.';

  @override
  String get myAgentsTitle => 'Os meus agentes';

  @override
  String get myAgentsSubtitle => 'Os seus rascunhos e agentes publicados.';

  @override
  String get myAgentsSubtitleDemo =>
      'Os seus rascunhos e agentes publicados. Demonstração: apenas neste separador.';

  @override
  String get myAgentsNew => 'Novo agente';

  @override
  String get myAgentsConnectTitle => 'Ligue a sua carteira';

  @override
  String get myAgentsConnectMessage =>
      'Os seus rascunhos e agentes pertencem à sua carteira.';

  @override
  String get myAgentsLoadError => 'Não foi possível carregar os seus agentes';

  @override
  String get myAgentsEmptyTitle => 'Ainda não há agentes';

  @override
  String get myAgentsEmptyMessage =>
      'Os agentes que guarda ou publica no Studio aparecem aqui.';

  @override
  String get myAgentsEmptyAction => 'Crie o seu primeiro agente';

  @override
  String get agentAbout => 'Sobre';

  @override
  String get agentSkills => 'Competências';

  @override
  String get agentOnChainIdentity => 'Identidade on-chain';

  @override
  String get agentId => 'Id do agente';

  @override
  String get agentDemoNotOnChain => 'Agente de demonstração, não está na chain';

  @override
  String get agentPaymentWallet => 'Carteira de pagamento';

  @override
  String get agentViewOnExplorer => 'Ver no explorer';

  @override
  String get agentPrice => 'Preço';

  @override
  String hireAgent(String name) {
    return 'Contratar $name';
  }

  @override
  String get hireNotFoundTitle => 'Hire não encontrado';

  @override
  String get hireCouldNotLoad => 'Não foi possível carregar este hire';

  @override
  String get agentCouldNotLoad => 'Não foi possível carregar este agente';

  @override
  String get pricePerTask => '/ tarefa';

  @override
  String get agentUntitled => 'Agente sem nome';

  @override
  String get agentUnspecifiedModel => 'Não especificado';

  @override
  String get agentNotFoundTitle => 'Agente não encontrado';

  @override
  String get agentNotFoundMessage =>
      'Não existe nenhum agente registado com este id. Pode ter sido removido, ou a ligação está errada.';

  @override
  String get agentBackToMarketplace => 'Voltar ao Marketplace';

  @override
  String get agentChecking => 'A verificar o agente no servidor…';

  @override
  String get agentHireDisabled =>
      'Contratar fica indisponível até o agente carregar.';

  @override
  String get agentStaleTitle => 'A mostrar os últimos dados conhecidos';

  @override
  String get agentStaleMessage =>
      'O servidor da puls3 não respondeu, por isso este agente não pôde ser confirmado.';

  @override
  String get agentPaidOnStellar =>
      'Pago em USDC na Stellar. Liquida em cerca de 5 segundos.';

  @override
  String get agentHire => 'Contratar';

  @override
  String get agentLoading => 'A carregar agente';

  @override
  String get marketLoadingAgents => 'A carregar agentes';

  @override
  String get agentPricePerTask => 'Preço / tarefa';

  @override
  String get agentRating => 'Avaliação';

  @override
  String get agentOnChainId => 'Id on-chain';

  @override
  String get agentDemo => 'Demo';

  @override
  String get agentDetails => 'Detalhes';

  @override
  String get networkTestnet => 'Testnet';

  @override
  String get skillOnChainAnalytics => 'Análise on-chain';

  @override
  String get skillMonitoring => 'Monitorização';

  @override
  String get skillSummaries => 'Resumos';

  @override
  String get skillPayments => 'Pagamentos';

  @override
  String get skillAnchors => 'Anchors';

  @override
  String get skillCompliance => 'Conformidade';

  @override
  String get skillSmartContracts => 'Contratos inteligentes';

  @override
  String get skillSecurity => 'Segurança';

  @override
  String get skillRust => 'Rust';

  @override
  String get skillDocumentParsing => 'Análise de documentos';

  @override
  String get skillAccounting => 'Contabilidade';

  @override
  String get skillTrading => 'Trading';

  @override
  String get skillCopywriting => 'Redação';

  @override
  String get skillMarketing => 'Marketing';

  @override
  String get skillCustomerSupport => 'Apoio ao cliente';

  @override
  String get skillTriage => 'Triagem';

  @override
  String get skillDataCleaning => 'Limpeza de dados';

  @override
  String get skillResearch => 'Pesquisa';

  @override
  String get demoDescAgt001 =>
      'Monitoriza contas Stellar e resume alterações de saldo, pagamentos e atualizações de trustlines em linguagem clara.';

  @override
  String get demoDescAgt002 =>
      'Planeia pagamentos transfronteiriços, compara rotas de anchors e prepara transferências USDC para revisão.';

  @override
  String get demoDescAgt003 =>
      'Revisa contratos inteligentes Soroban em busca de erros comuns e explica as conclusões com correções sugeridas.';

  @override
  String get demoDescAgt004 =>
      'Lê faturas, extrai linhas e redige pedidos de pagamento USDC correspondentes.';

  @override
  String get demoDescAgt005 =>
      'Acompanha os livros de ofertas da SDEX e as pools de liquidez e entrega um briefing diário de mercado.';

  @override
  String get demoDescAgt006 =>
      'Escreve landing pages, notas de versão e publicações nas redes com a voz da sua marca.';

  @override
  String get demoDescAgt007 =>
      'Responde a tickets de apoio de carteira, faz triagem de erros e escala com o contexto completo.';

  @override
  String get demoDescAgt008 =>
      'Limpa exportações CSV, une conjuntos de dados e devolve tabelas organizadas com gráficos.';

  @override
  String get studioSectionIdentity => 'Identidade';

  @override
  String get studioAgentName => 'Nome do agente';

  @override
  String get studioAgentNameHint => 'Por exemplo, Brief Bot';

  @override
  String studioCharacters(int count) {
    return '$count caracteres';
  }

  @override
  String get studioDescription => 'Descrição';

  @override
  String get studioDescriptionHint => 'O que o agente faz, numa ou duas frases';

  @override
  String get studioModel => 'Modelo';

  @override
  String get studioModelOwnProvider =>
      'Corre na sua própria conta do fornecedor';

  @override
  String get studioModelFreeTier =>
      'Nível gratuito na sua própria conta Workers AI';

  @override
  String studioModelOwnKey(String provider) {
    return 'Usa a sua própria chave de $provider';
  }

  @override
  String studioModelFree(String label) {
    return '$label · grátis';
  }

  @override
  String get studioSectionBehavior => 'Comportamento';

  @override
  String get studioSystemPrompt => 'Prompt do sistema';

  @override
  String get studioSystemPromptHint =>
      'As instruções que o agente segue em cada hire';

  @override
  String get studioAddSkill => 'Adicionar uma competência';

  @override
  String get studioAddSkillHint => 'Escreva e prima Enter';

  @override
  String get studioAddSkillTooltip => 'Adicionar competência';

  @override
  String get studioSectionIo => 'Entrada e saída';

  @override
  String get studioInputMax => 'Entrada máxima (caracteres)';

  @override
  String get studioInputMaxHint => 'Por exemplo, 6000';

  @override
  String get studioInputHelper => 'Texto da pessoa que contrata o agente';

  @override
  String get studioAnswerFormat => 'Formato da resposta';

  @override
  String get studioPlainText => 'Texto simples';

  @override
  String get studioMarkdown => 'Markdown';

  @override
  String get studioOutputMax => 'Resposta máxima';

  @override
  String get studioSectionPricing => 'Preço';

  @override
  String get studioPricePerTask => 'Preço por tarefa';

  @override
  String get studioReady => 'Pronto para o deploy';

  @override
  String studioFieldsToComplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos por completar',
      one: '1 campo por completar',
    );
    return '$_temp0';
  }

  @override
  String get studioWhatIsMissing => 'O que falta?';

  @override
  String get studioConnectDraftOwner =>
      'Ligue a carteira dona deste rascunho para o abrir.';

  @override
  String studioUnsavedRevision(int revision) {
    return 'Alterações não guardadas · revisão $revision';
  }

  @override
  String studioSavedRevision(int revision) {
    return 'Guardado · revisão $revision';
  }

  @override
  String studioSavedRevisionDemo(int revision) {
    return 'Guardado · revisão $revision (demo)';
  }

  @override
  String get studioReload => 'Recarregar';

  @override
  String get studioKeepMine => 'Manter o meu';

  @override
  String studioNotSaved(String message) {
    return 'Não foi guardado: $message';
  }

  @override
  String get studioServerNoAnswer =>
      'Não foi guardado: o servidor não respondeu. O seu texto permanece.';

  @override
  String studioVersionBanner(int next, int current) {
    return 'A edição cria a versão $next. Quem contrata mantém a versão $current até fazer o deploy.';
  }

  @override
  String get studioErrWholeNumber =>
      'Introduza um número inteiro de caracteres.';

  @override
  String get studioErrPriceFormat => 'Introduza um valor como 0.50.';

  @override
  String get studioErrSkillLetters =>
      'Use letras ou números em cada nome de competência.';

  @override
  String get studioErrSkillTooLong =>
      'O nome de uma competência é demasiado longo.';

  @override
  String get studioErrNameMissing => 'Dê um nome ao seu agente.';

  @override
  String get studioErrNameTooShort => 'O nome é demasiado curto.';

  @override
  String get studioErrNameTooLong => 'O nome é demasiado longo.';

  @override
  String get studioErrNameCheck => 'Verifique o nome.';

  @override
  String get studioErrDescMissing => 'Diga o que o agente faz.';

  @override
  String get studioErrDescTooShort => 'A descrição é demasiado curta.';

  @override
  String get studioErrDescTooLong => 'A descrição é demasiado longa.';

  @override
  String get studioErrDescCheck => 'Verifique a descrição.';

  @override
  String get studioErrSkillsMissing => 'Adicione pelo menos uma competência.';

  @override
  String get studioErrSkillsTooMany =>
      'Demasiadas competências: remova algumas.';

  @override
  String get studioErrSkillDuplicate => 'Duas competências têm o mesmo nome.';

  @override
  String get studioErrSkillCheck => 'Verifique os nomes das competências.';

  @override
  String get studioErrModelMissing => 'Escolha um modelo.';

  @override
  String get studioErrModelFreeTier =>
      'Este modelo não está disponível no nível gratuito.';

  @override
  String get studioErrModelProvider =>
      'Este fornecedor ainda não está ativado.';

  @override
  String get studioErrPromptMissing =>
      'Escreva as instruções que o agente segue.';

  @override
  String get studioErrPromptTooShort => 'As instruções são demasiado curtas.';

  @override
  String get studioErrPromptTooLong => 'As instruções são demasiado longas.';

  @override
  String get studioErrPromptCheck => 'Verifique as instruções.';

  @override
  String get studioErrInputMissing =>
      'Defina a entrada máxima que o agente aceita.';

  @override
  String get studioErrInputTooLow =>
      'O limite de entrada deve ser de pelo menos 1 carácter.';

  @override
  String get studioErrInputTooHigh =>
      'O limite de entrada está acima do que os agentes aceitam.';

  @override
  String get studioErrInputCheck => 'Verifique a entrada.';

  @override
  String get studioErrOutputMissing =>
      'Defina a resposta máxima que o agente devolve.';

  @override
  String get studioErrOutputTooLow =>
      'O limite de resposta deve ser de pelo menos 1 carácter.';

  @override
  String get studioErrOutputTooHigh =>
      'O limite de resposta está acima do que os agentes devolvem.';

  @override
  String get studioErrOutputCheck => 'Verifique a saída.';

  @override
  String get studioErrPriceMissing => 'Defina um preço.';

  @override
  String get studioErrPricePositive => 'O preço deve ser maior do que 0.';

  @override
  String get studioErrPriceCheck => 'Verifique o preço.';

  @override
  String get studioErrCannotSave => 'Este agente não pode ser guardado.';

  @override
  String get playgroundDemoLead =>
      'Teste de demonstração: o modelo ainda não responde.';

  @override
  String get playgroundLiveLead => 'Os testes são grátis e têm limite por dia.';

  @override
  String get playgroundProviderToken => 'Token do fornecedor';

  @override
  String get playgroundProviderTokenHint => 'Guardado para os seus testes';

  @override
  String get playgroundAccountId => 'Id da conta Cloudflare';

  @override
  String get playgroundRunning => 'A executar… Para ao chegar ao tempo limite.';

  @override
  String get playgroundFailed => 'O teste falhou';

  @override
  String get playgroundTryLater => 'Tente novamente daqui a pouco.';

  @override
  String get playgroundQuota => 'Já utilizou os testes de hoje.';

  @override
  String get playgroundSampleTask => 'Uma tarefa de exemplo para o seu agente';

  @override
  String playgroundTooLong(int max) {
    return 'Este agente aceita até $max caracteres.';
  }

  @override
  String get playgroundRun => 'Executar';

  @override
  String get playgroundRunningButton => 'A executar…';

  @override
  String get playgroundResultLabel => 'Teste: não foi pago, nada on-chain';

  @override
  String playgroundRunsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count testes hoje',
      one: 'Resta 1 teste hoje',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Fechar';

  @override
  String get myAgentsDrafts => 'Rascunhos';

  @override
  String get myAgentsDeployingOrFailed => 'Em deploy ou com falha';

  @override
  String get myAgentsLive => 'Ativos';

  @override
  String myAgentsDraftRevision(int revision) {
    return 'Rascunho · revisão $revision';
  }

  @override
  String get myAgentsDeploying => 'Em deploy';

  @override
  String get myAgentsDeployFailed => 'O deploy falhou';

  @override
  String myAgentsLiveVersion(int version) {
    return 'Ativo · versão $version';
  }

  @override
  String get myAgentsContinue => 'Continuar a editar';

  @override
  String get myAgentsResume => 'Retomar deploy';

  @override
  String myAgentsResumeStep(int step) {
    return 'Retomar deploy (passo $step)';
  }

  @override
  String get myAgentsView => 'Ver';

  @override
  String get myAgentsEdit => 'Editar';

  @override
  String get myAgentsServerNoAnswer =>
      'O servidor não respondeu. Tente novamente.';

  @override
  String get hireDemoOnly =>
      'Apenas demonstração: assinar aqui não move fundos. Os pagamentos em escrow chegam quando o início de sessão com carteira estiver ativo no servidor.';

  @override
  String get hireTaskLabel => 'O que deve o agente fazer?';

  @override
  String get hireTaskHint => 'Descreva a tarefa deste hire';

  @override
  String get hireAsset => 'Ativo';

  @override
  String get hireNetwork => 'Rede';

  @override
  String get hireDestination => 'Destino';

  @override
  String get hireEscrow => 'Escrow';

  @override
  String get hireNetworkFee => 'Comissão de rede';

  @override
  String get hireSigning => 'A assinar…';

  @override
  String get hireConfirmSign => 'Confirmar e assinar';

  @override
  String get hireDemoSignature => 'Apenas assinatura de demonstração';

  @override
  String get hireDemoDone =>
      'Não foi enviado nenhum pagamento nem criado nenhum hire. Os pagamentos reais em escrow chegam quando o início de sessão com carteira estiver ativo no servidor.';

  @override
  String get hireAgentLabel => 'Agente';

  @override
  String get hirePaymentHeld => 'Pagamento retido no escrow';

  @override
  String get hirePaymentConfirming =>
      'Pagamento enviado, a confirmar na Stellar…';

  @override
  String get hirePaymentHeldBody =>
      'O seu USDC fica no contrato de escrow até aprovar o resultado. O agente começa a trabalhar.';

  @override
  String get hirePaymentConfirmingBody =>
      'A puls3 está a confirmar a transação e a verificar se corresponde a este hire. Pode acompanhá-la no StellarExpert.';

  @override
  String get hireTxHash => 'Hash da tx';

  @override
  String get hireViewHire => 'Ver hire';

  @override
  String get hireViewExplorer => 'Ver no StellarExpert';

  @override
  String get hirePaymentFailed => 'O pagamento falhou';

  @override
  String get hirePaymentIncomplete => 'Não foi possível concluir o pagamento';

  @override
  String get hireEscrowProtection =>
      'Proteção de escrow: o seu USDC permanece no contrato. O agente só recebe quando aprova o resultado, e é reembolsado se nunca entregar.';

  @override
  String get studioDraftLoadError =>
      'Não foi possível carregar o rascunho. Tente novamente.';

  @override
  String get playgroundUnavailable =>
      'O ambiente de teste não está disponível.';

  @override
  String playgroundQuotaReset(String time) {
    return 'Já usou os testes de hoje. Reiniciam às $time.';
  }

  @override
  String get playgroundOutputCopied => 'Saída copiada';

  @override
  String get marketSortAgents => 'Ordenar agentes';

  @override
  String get hireIdLabel => 'Contratação';
}
