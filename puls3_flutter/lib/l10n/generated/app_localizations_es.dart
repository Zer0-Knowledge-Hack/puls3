// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'puls3: el hub de agentes en Stellar';

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
  String get navMenu => 'Menú';

  @override
  String get navDocs => 'Docs';

  @override
  String get navGitHub => 'GitHub';

  @override
  String get landingKicker => 'El hub de agentes en Stellar';

  @override
  String get landingHeadline =>
      'Crea. Descubre. Paga.\nAgentes de IA en Stellar.';

  @override
  String get landingLead =>
      'Crea agentes de IA con identidad y wallet on-chain, encuentra el indicado en un solo Marketplace y págalo por tarea en USDC, en escrow hasta que el trabajo esté listo.';

  @override
  String get landingOpenStudio => 'Abrir Studio';

  @override
  String get landingExploreMarketplace => 'Explorar Marketplace';

  @override
  String get landingExploreAgents => 'Explorar agentes';

  @override
  String get landingBuildAgent => 'Crear un agente';

  @override
  String get landingViewDocs => 'Ver documentación';

  @override
  String get landingLiveInMarketplace => 'En vivo en el Marketplace';

  @override
  String get landingSeeFirstHire => 'Ver el primer hire pagado a escrow';

  @override
  String get landingFinalCtaTitle => 'Empieza con un agente.';

  @override
  String get landingFinalCtaLead =>
      'Contrata uno en testnet, crea el tuyo en el Studio o ayuda a construir puls3 de forma abierta.';

  @override
  String get landingWhyStellar => 'Por qué Stellar';

  @override
  String get landingSettleTitle => 'Liquidación en ~5 s';

  @override
  String get landingSettleBody =>
      'Los pagos a agentes se confirman en segundos, no en días.';

  @override
  String get landingFeesTitle => 'Comisiones de una fracción de centavo';

  @override
  String get landingFeesBody =>
      'Los micropagos por tarea siguen valiendo la pena.';

  @override
  String get landingUsdcTitle => 'USDC nativo';

  @override
  String get landingUsdcBody =>
      'Fija el precio y paga a los agentes en un activo estable respaldado en dólares.';

  @override
  String get footerDemo =>
      'Versión de demostración. Datos de prueba, sin fondos reales.';

  @override
  String get footerBrand => 'Marca';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonTryAgain => 'Intentar de nuevo';

  @override
  String get commonAll => 'Todos';

  @override
  String get walletConnect => 'Conectar wallet';

  @override
  String get walletConnectShort => 'Conectar';

  @override
  String get walletConnecting => 'Conectando…';

  @override
  String get walletConnectTitle => 'Conecta una wallet';

  @override
  String get walletConnectMessage =>
      'Tu wallet firma deploys y pagos. puls3 nunca ve tu clave secreta.';

  @override
  String walletConnectNamed(String walletName) {
    return 'Conectar $walletName';
  }

  @override
  String walletWaitingNamed(String walletName) {
    return 'Esperando $walletName…';
  }

  @override
  String get walletWaitingConfirmation =>
      'Esperando confirmación de la wallet…';

  @override
  String get walletDisconnect => 'Desconectar';

  @override
  String get walletCopyAddress => 'Copiar dirección';

  @override
  String get walletAddress => 'Dirección';

  @override
  String get walletTestnetOnly => 'Solo Stellar Testnet. Sin fondos reales.';

  @override
  String walletInstall(String walletName) {
    return 'Instalar $walletName';
  }

  @override
  String get marketTitle => 'Marketplace';

  @override
  String get marketLead =>
      'Encuentra un agente, contrátalo y págalo en USDC en Stellar.';

  @override
  String get marketCreateAgent => 'Crear agente';

  @override
  String get marketSearchHint => 'Buscar agentes, habilidades o modelos';

  @override
  String get marketClearSearch => 'Borrar búsqueda';

  @override
  String get marketCouldNotLoad => 'No se pudieron cargar los agentes';

  @override
  String get marketCouldNotLoadMessage =>
      'El servidor de puls3 no respondió. Revisa la conexión e inténtalo de nuevo.';

  @override
  String get marketDemoTitle => 'Mostrando el catálogo de demostración';

  @override
  String get marketDemoMessage =>
      'El servidor de puls3 no está disponible, así que estos agentes no se leen de la chain.';

  @override
  String get marketEmptyTitle => 'Todavía no hay agentes';

  @override
  String get marketEmptyMessage =>
      'Los agentes registrados on-chain aparecen aquí. Sé el primero en publicar uno.';

  @override
  String get marketEmptyAction => 'Crear un agente';

  @override
  String get marketNoMatchTitle => 'No hay agentes que coincidan';

  @override
  String get marketNoMatchMessage => 'Prueba otra búsqueda o menos filtros.';

  @override
  String get marketClearFilters => 'Limpiar filtros';

  @override
  String marketShowingCount(int visible, int total) {
    return 'MOSTRANDO $visible DE $total';
  }

  @override
  String marketAgentsLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AGENTES ACTIVOS',
      one: '1 AGENTE ACTIVO',
    );
    return '$_temp0';
  }

  @override
  String get marketDemoCatalog => 'CATÁLOGO DEMO';

  @override
  String get marketFilters => 'Filtros';

  @override
  String marketFiltersActive(int count) {
    return 'Filtros ($count activos)';
  }

  @override
  String get marketReset => 'Restablecer';

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
  String get marketClearAll => 'Limpiar todo';

  @override
  String get sortFeatured => 'Destacados';

  @override
  String get sortPriceLowToHigh => 'Precio: menor a mayor';

  @override
  String get sortPriceHighToLow => 'Precio: mayor a menor';

  @override
  String get sortTopRated => 'Mejor valorados';

  @override
  String get studioTitle => 'Agent Studio';

  @override
  String get studioLead =>
      'Diseña un agente, asígnale un precio y despliégalo con su propia wallet.';

  @override
  String get studioPreview => 'Vista previa del Marketplace';

  @override
  String get studioYourAgent => 'Tu agente';

  @override
  String get studioGeneralist => 'Generalista';

  @override
  String get studioDeployHint =>
      'Al hacer deploy, puls3 crea una wallet Stellar para este agente y registra su identidad en Soroban.';

  @override
  String get studioDeploy => 'Deploy a Stellar';

  @override
  String get studioSaveDraft => 'Guardar borrador';

  @override
  String get studioSaving => 'Guardando…';

  @override
  String get studioTestRun => 'Prueba';

  @override
  String get studioMyAgents => 'Mis agentes';

  @override
  String get studioConnectToSave =>
      'Conecta tu wallet para guardar borradores y pruebas.';

  @override
  String get myAgentsTitle => 'Mis agentes';

  @override
  String get myAgentsSubtitle => 'Tus borradores y agentes desplegados.';

  @override
  String get myAgentsSubtitleDemo =>
      'Tus borradores y agentes desplegados. Demostración: solo en esta pestaña.';

  @override
  String get myAgentsNew => 'Nuevo agente';

  @override
  String get myAgentsConnectTitle => 'Conecta tu wallet';

  @override
  String get myAgentsConnectMessage =>
      'Tus borradores y agentes pertenecen a tu wallet.';

  @override
  String get myAgentsLoadError => 'No se pudieron cargar tus agentes';

  @override
  String get myAgentsEmptyTitle => 'Todavía no hay agentes';

  @override
  String get myAgentsEmptyMessage =>
      'Los agentes que guardes o despliegues desde el Studio aparecen aquí.';

  @override
  String get myAgentsEmptyAction => 'Crea tu primer agente';

  @override
  String get agentAbout => 'Acerca de';

  @override
  String get agentSkills => 'Habilidades';

  @override
  String get agentOnChainIdentity => 'Identidad on-chain';

  @override
  String get agentId => 'Id del agente';

  @override
  String get agentDemoNotOnChain =>
      'Agente de demostración, no está en la chain';

  @override
  String get agentPaymentWallet => 'Wallet de pago';

  @override
  String get agentViewOnExplorer => 'Ver en el explorer';

  @override
  String get agentPrice => 'Precio';

  @override
  String hireAgent(String name) {
    return 'Contratar $name';
  }

  @override
  String get hireNotFoundTitle => 'Hire no encontrado';

  @override
  String get hireCouldNotLoad => 'No se pudo cargar este hire';

  @override
  String get agentCouldNotLoad => 'No se pudo cargar este agente';

  @override
  String get pricePerTask => '/ tarea';

  @override
  String get agentUntitled => 'Agente sin nombre';

  @override
  String get agentUnspecifiedModel => 'No especificado';

  @override
  String get agentNotFoundTitle => 'Agente no encontrado';

  @override
  String get agentNotFoundMessage =>
      'No hay un agente registrado con este id. Puede que se haya eliminado o que el enlace sea incorrecto.';

  @override
  String get agentBackToMarketplace => 'Volver al Marketplace';

  @override
  String get agentChecking => 'Comprobando el agente en el servidor…';

  @override
  String get agentHireDisabled =>
      'Contratar está deshabilitado hasta que cargue el agente.';

  @override
  String get agentStaleTitle => 'Mostrando los últimos datos conocidos';

  @override
  String get agentStaleMessage =>
      'El servidor de puls3 no respondió, así que no se pudo confirmar este agente.';

  @override
  String get agentPaidOnStellar =>
      'Se paga en USDC en Stellar. Se liquida en unos 5 segundos.';

  @override
  String get agentHire => 'Contratar';

  @override
  String get agentLoading => 'Cargando agente';

  @override
  String get marketLoadingAgents => 'Cargando agentes';

  @override
  String get agentPricePerTask => 'Precio / tarea';

  @override
  String get agentRating => 'Valoración';

  @override
  String get agentOnChainId => 'Id on-chain';

  @override
  String get agentDemo => 'Demo';

  @override
  String get agentDetails => 'Detalles';

  @override
  String get networkTestnet => 'Testnet';

  @override
  String get skillOnChainAnalytics => 'Análisis on-chain';

  @override
  String get skillMonitoring => 'Monitoreo';

  @override
  String get skillSummaries => 'Resúmenes';

  @override
  String get skillPayments => 'Pagos';

  @override
  String get skillAnchors => 'Anchors';

  @override
  String get skillCompliance => 'Cumplimiento';

  @override
  String get skillSmartContracts => 'Contratos inteligentes';

  @override
  String get skillSecurity => 'Seguridad';

  @override
  String get skillRust => 'Rust';

  @override
  String get skillDocumentParsing => 'Análisis de documentos';

  @override
  String get skillAccounting => 'Contabilidad';

  @override
  String get skillTrading => 'Trading';

  @override
  String get skillCopywriting => 'Redacción';

  @override
  String get skillMarketing => 'Marketing';

  @override
  String get skillCustomerSupport => 'Atención al cliente';

  @override
  String get skillTriage => 'Clasificación';

  @override
  String get skillDataCleaning => 'Limpieza de datos';

  @override
  String get skillResearch => 'Investigación';

  @override
  String get demoDescAgt001 =>
      'Monitorea cuentas de Stellar y resume cambios de saldo, pagos y actualizaciones de trustlines en lenguaje claro.';

  @override
  String get demoDescAgt002 =>
      'Planifica pagos transfronterizos, compara rutas de anchors y prepara transferencias USDC para revisión.';

  @override
  String get demoDescAgt003 =>
      'Revisa contratos inteligentes de Soroban en busca de errores comunes y explica los hallazgos con correcciones sugeridas.';

  @override
  String get demoDescAgt004 =>
      'Lee facturas, extrae partidas y redacta solicitudes de pago USDC coincidentes.';

  @override
  String get demoDescAgt005 =>
      'Sigue los libros de órdenes de SDEX y los pools de liquidez, y entrega un informe de mercado diario.';

  @override
  String get demoDescAgt006 =>
      'Escribe landing pages, notas de versión y hilos para redes con la voz de tu marca.';

  @override
  String get demoDescAgt007 =>
      'Responde tickets de soporte de wallet, clasifica errores y escala con todo el contexto.';

  @override
  String get demoDescAgt008 =>
      'Limpia exportaciones CSV, une conjuntos de datos y devuelve tablas ordenadas con gráficos.';

  @override
  String get studioSectionIdentity => 'Identidad';

  @override
  String get studioAgentName => 'Nombre del agente';

  @override
  String get studioAgentNameHint => 'Por ejemplo, Brief Bot';

  @override
  String studioCharacters(int count) {
    return '$count caracteres';
  }

  @override
  String get studioDescription => 'Descripción';

  @override
  String get studioDescriptionHint => 'Qué hace el agente, en una o dos frases';

  @override
  String get studioModel => 'Modelo';

  @override
  String get studioModelOwnProvider =>
      'Se ejecuta en tu propia cuenta del proveedor';

  @override
  String get studioModelFreeTier =>
      'Nivel gratuito en tu propia cuenta de Workers AI';

  @override
  String studioModelOwnKey(String provider) {
    return 'Usa tu propia clave de $provider';
  }

  @override
  String studioModelFree(String label) {
    return '$label · gratis';
  }

  @override
  String get studioSectionBehavior => 'Comportamiento';

  @override
  String get studioSystemPrompt => 'Prompt del sistema';

  @override
  String get studioSystemPromptHint =>
      'Las instrucciones que el agente sigue en cada hire';

  @override
  String get studioAddSkill => 'Agregar una habilidad';

  @override
  String get studioAddSkillHint => 'Escribe y pulsa Enter';

  @override
  String get studioAddSkillTooltip => 'Agregar habilidad';

  @override
  String get studioSectionIo => 'Entrada y salida';

  @override
  String get studioInputMax => 'Entrada máxima (caracteres)';

  @override
  String get studioInputMaxHint => 'Por ejemplo, 6000';

  @override
  String get studioInputHelper => 'Texto de la persona que contrata al agente';

  @override
  String get studioAnswerFormat => 'Formato de respuesta';

  @override
  String get studioPlainText => 'Texto plano';

  @override
  String get studioMarkdown => 'Markdown';

  @override
  String get studioOutputMax => 'Respuesta máxima';

  @override
  String get studioSectionPricing => 'Precio';

  @override
  String get studioPricePerTask => 'Precio por tarea';

  @override
  String get studioReady => 'Listo para el deploy';

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
  String get studioWhatIsMissing => '¿Qué falta?';

  @override
  String get studioConnectDraftOwner =>
      'Conecta la wallet que posee este borrador para abrirlo.';

  @override
  String studioUnsavedRevision(int revision) {
    return 'Cambios sin guardar · revisión $revision';
  }

  @override
  String studioSavedRevision(int revision) {
    return 'Guardado · revisión $revision';
  }

  @override
  String studioSavedRevisionDemo(int revision) {
    return 'Guardado · revisión $revision (demo)';
  }

  @override
  String get studioReload => 'Recargar';

  @override
  String get studioKeepMine => 'Conservar el mío';

  @override
  String studioNotSaved(String message) {
    return 'No se guardó: $message';
  }

  @override
  String get studioServerNoAnswer =>
      'No se guardó: el servidor no respondió. Tu texto se mantiene.';

  @override
  String studioVersionBanner(int next, int current) {
    return 'La edición crea la versión $next. Quienes contratan conservan la versión $current hasta que hagas deploy.';
  }

  @override
  String get studioErrWholeNumber => 'Ingresa un número entero de caracteres.';

  @override
  String get studioErrPriceFormat => 'Ingresa un monto como 0.50.';

  @override
  String get studioErrSkillLetters =>
      'Usa letras o números en cada nombre de habilidad.';

  @override
  String get studioErrSkillTooLong =>
      'El nombre de una habilidad es demasiado largo.';

  @override
  String get studioErrNameMissing => 'Ponle un nombre a tu agente.';

  @override
  String get studioErrNameTooShort => 'El nombre es demasiado corto.';

  @override
  String get studioErrNameTooLong => 'El nombre es demasiado largo.';

  @override
  String get studioErrNameCheck => 'Revisa el nombre.';

  @override
  String get studioErrDescMissing => 'Di qué hace el agente.';

  @override
  String get studioErrDescTooShort => 'La descripción es demasiado corta.';

  @override
  String get studioErrDescTooLong => 'La descripción es demasiado larga.';

  @override
  String get studioErrDescCheck => 'Revisa la descripción.';

  @override
  String get studioErrSkillsMissing => 'Agrega al menos una habilidad.';

  @override
  String get studioErrSkillsTooMany => 'Demasiadas habilidades: quita algunas.';

  @override
  String get studioErrSkillDuplicate =>
      'Dos habilidades tienen el mismo nombre.';

  @override
  String get studioErrSkillCheck => 'Revisa los nombres de las habilidades.';

  @override
  String get studioErrModelMissing => 'Elige un modelo.';

  @override
  String get studioErrModelFreeTier =>
      'Este modelo no está disponible en el nivel gratuito.';

  @override
  String get studioErrModelProvider =>
      'Este proveedor todavía no está habilitado.';

  @override
  String get studioErrPromptMissing =>
      'Escribe las instrucciones que sigue el agente.';

  @override
  String get studioErrPromptTooShort =>
      'Las instrucciones son demasiado cortas.';

  @override
  String get studioErrPromptTooLong =>
      'Las instrucciones son demasiado largas.';

  @override
  String get studioErrPromptCheck => 'Revisa las instrucciones.';

  @override
  String get studioErrInputMissing =>
      'Define la entrada máxima que acepta el agente.';

  @override
  String get studioErrInputTooLow =>
      'El límite de entrada debe ser de al menos 1 carácter.';

  @override
  String get studioErrInputTooHigh =>
      'El límite de entrada supera lo que aceptan los agentes.';

  @override
  String get studioErrInputCheck => 'Revisa la entrada.';

  @override
  String get studioErrOutputMissing =>
      'Define la respuesta máxima que devuelve el agente.';

  @override
  String get studioErrOutputTooLow =>
      'El límite de respuesta debe ser de al menos 1 carácter.';

  @override
  String get studioErrOutputTooHigh =>
      'El límite de respuesta supera lo que devuelven los agentes.';

  @override
  String get studioErrOutputCheck => 'Revisa la salida.';

  @override
  String get studioErrPriceMissing => 'Define un precio.';

  @override
  String get studioErrPricePositive => 'El precio debe ser mayor que 0.';

  @override
  String get studioErrPriceCheck => 'Revisa el precio.';

  @override
  String get studioErrCannotSave => 'Este agente no se puede guardar.';

  @override
  String get playgroundDemoLead =>
      'Prueba de demostración: el modelo todavía no responde.';

  @override
  String get playgroundLiveLead =>
      'Las pruebas son gratis y tienen un límite por día.';

  @override
  String get playgroundProviderToken => 'Token del proveedor';

  @override
  String get playgroundProviderTokenHint => 'Se guarda para tus pruebas';

  @override
  String get playgroundAccountId => 'Id de cuenta de Cloudflare';

  @override
  String get playgroundRunning =>
      'Ejecutando… Se detiene al llegar al tiempo límite.';

  @override
  String get playgroundFailed => 'La prueba falló';

  @override
  String get playgroundTryLater => 'Inténtalo de nuevo en un momento.';

  @override
  String get playgroundQuota => 'Ya usaste las pruebas de hoy.';

  @override
  String get playgroundSampleTask => 'Una tarea de ejemplo para tu agente';

  @override
  String playgroundTooLong(int max) {
    return 'Este agente acepta hasta $max caracteres.';
  }

  @override
  String get playgroundRun => 'Ejecutar';

  @override
  String get playgroundRunningButton => 'Ejecutando…';

  @override
  String get playgroundResultLabel => 'Prueba: no se pagó, nada on-chain';

  @override
  String playgroundRunsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count pruebas hoy',
      one: 'Queda 1 prueba hoy',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Cerrar';

  @override
  String get myAgentsDrafts => 'Borradores';

  @override
  String get myAgentsDeployingOrFailed => 'En deploy o con error';

  @override
  String get myAgentsLive => 'Activos';

  @override
  String myAgentsDraftRevision(int revision) {
    return 'Borrador · revisión $revision';
  }

  @override
  String get myAgentsDeploying => 'En deploy';

  @override
  String get myAgentsDeployFailed => 'El deploy falló';

  @override
  String myAgentsLiveVersion(int version) {
    return 'Activo · versión $version';
  }

  @override
  String get myAgentsContinue => 'Seguir editando';

  @override
  String get myAgentsResume => 'Reanudar deploy';

  @override
  String myAgentsResumeStep(int step) {
    return 'Reanudar deploy (paso $step)';
  }

  @override
  String get myAgentsView => 'Ver';

  @override
  String get myAgentsEdit => 'Editar';

  @override
  String get myAgentsServerNoAnswer =>
      'El servidor no respondió. Inténtalo de nuevo.';

  @override
  String get hireDemoOnly =>
      'Solo demostración: firmar aquí no mueve fondos. Los pagos a escrow llegan cuando el inicio de sesión con wallet esté activo en el servidor.';

  @override
  String get hireTaskLabel => '¿Qué debe hacer el agente?';

  @override
  String get hireTaskHint => 'Describe la tarea de este hire';

  @override
  String get hireAsset => 'Activo';

  @override
  String get hireNetwork => 'Red';

  @override
  String get hireDestination => 'Destino';

  @override
  String get hireEscrow => 'Escrow';

  @override
  String get hireNetworkFee => 'Comisión de red';

  @override
  String get hireSigning => 'Firmando…';

  @override
  String get hireConfirmSign => 'Confirmar y firmar';

  @override
  String get hireDemoSignature => 'Solo firma de demostración';

  @override
  String get hireDemoDone =>
      'No se envió ningún pago ni se creó un hire. Los pagos reales a escrow llegan cuando el inicio de sesión con wallet esté activo en el servidor.';

  @override
  String get hireAgentLabel => 'Agente';

  @override
  String get hirePaymentHeld => 'Pago retenido en el escrow';

  @override
  String get hirePaymentConfirming => 'Pago enviado, confirmando en Stellar…';

  @override
  String get hirePaymentHeldBody =>
      'Tu USDC queda en el contrato de escrow hasta que apruebes el resultado. El agente empieza a trabajar.';

  @override
  String get hirePaymentConfirmingBody =>
      'puls3 está confirmando la transacción y comprobando que coincida con este hire. Puedes seguirla en StellarExpert.';

  @override
  String get hireTxHash => 'Hash de la tx';

  @override
  String get hireViewHire => 'Ver hire';

  @override
  String get hireViewExplorer => 'Ver en StellarExpert';

  @override
  String get hirePaymentFailed => 'El pago falló';

  @override
  String get hirePaymentIncomplete => 'No se pudo completar el pago';

  @override
  String get hireEscrowProtection =>
      'Protección de escrow: tu USDC permanece en el contrato. El agente cobra solo cuando apruebas el resultado, y recibes un reembolso si nunca entrega.';

  @override
  String get studioDraftLoadError =>
      'No se pudo cargar el borrador. Inténtalo de nuevo.';

  @override
  String get playgroundUnavailable =>
      'El entorno de prueba no está disponible.';

  @override
  String playgroundQuotaReset(String time) {
    return 'Ya usaste las pruebas de hoy. Se restablecen a las $time.';
  }

  @override
  String get playgroundOutputCopied => 'Salida copiada';

  @override
  String get marketSortAgents => 'Ordenar agentes';

  @override
  String get hireIdLabel => 'Contratación';
}
