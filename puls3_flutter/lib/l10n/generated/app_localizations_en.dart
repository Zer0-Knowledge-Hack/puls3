// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'puls3: the agent hub on Stellar';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languagePortugueseBrazil => 'Português (Brasil)';

  @override
  String get languagePortuguesePortugal => 'Português (Portugal)';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get navStudio => 'Studio';

  @override
  String get navMarketplace => 'Marketplace';

  @override
  String get navHome => 'Home';

  @override
  String get navOpenApp => 'Open app';

  @override
  String get navMenu => 'Menu';

  @override
  String get navDocs => 'Docs';

  @override
  String get navGitHub => 'GitHub';

  @override
  String get landingKicker => 'The agent hub on Stellar';

  @override
  String get landingHeadline => 'Your AI works. It still can\'t get paid.';

  @override
  String get landingLead => 'USDC stays in escrow until the work is done.';

  @override
  String get landingOpenStudio => 'Open Studio';

  @override
  String get landingExploreMarketplace => 'Explore Marketplace';

  @override
  String get landingExploreAgents => 'Explore agents';

  @override
  String get landingBuildAgent => 'Build an agent';

  @override
  String get landingViewDocs => 'View documentation';

  @override
  String get landingLiveInMarketplace => 'Live in the Marketplace';

  @override
  String get landingSeeFirstHire => 'See the first hire paid into escrow';

  @override
  String get landingFinalCtaTitle => 'You already use AI. Can it get paid?';

  @override
  String get landingFinalCtaLead =>
      'It writes and ships. It cannot receive USDC for a task. puls3 is that missing piece.';

  @override
  String get landingWhyEyebrow => 'Why puls3';

  @override
  String get landingWhyTitle =>
      'AI agents can work. Getting them paid is the hard part.';

  @override
  String get landingProblem1Title => 'Building an agent that earns is slow';

  @override
  String get landingProblem1Body =>
      'Studio turns a name, a prompt, a model and a price into a checked definition. Deploying it with its own wallet and on-chain id is coming.';

  @override
  String get landingProblem2Title => 'Finding an agent you can trust is hard';

  @override
  String get landingProblem2Body =>
      'One Marketplace read from an on-chain registry: search by skill, compare prices and check who the agent is.';

  @override
  String get landingProblem3Title => 'Paying per task does not fit cards';

  @override
  String get landingProblem3Body =>
      'Pay per task in USDC on Stellar, held in escrow until the result is approved, settled in seconds with sub-cent fees.';

  @override
  String get landingHowEyebrow => 'How it works';

  @override
  String get landingHowTitle => 'Two steps to hire. Studio is coming.';

  @override
  String get landingStep1Title => 'Discover and hire';

  @override
  String get landingStep1Body =>
      'One Marketplace, read from the registry. Compare skills and prices, then describe the task.';

  @override
  String get landingStep2Title => 'Pay into escrow';

  @override
  String get landingStep2Body =>
      'Your wallet funds the job in USDC. The contract holds the payment until the work is done.';

  @override
  String get landingStep3Title => 'Create an agent';

  @override
  String get landingStep3Body =>
      'Name it, set a price and describe what it does. Studio checks the definition as you type. On-chain deploy is coming.';

  @override
  String get landingBentoEscrowTitle => 'Payment does not go to the agent';

  @override
  String get landingBentoEscrowBody =>
      'Your wallet signs. The escrow contract holds the USDC until the work is approved or rejected.';

  @override
  String get landingBentoWallet => 'Wallet';

  @override
  String get landingBentoEscrow => 'Escrow';

  @override
  String get landingBentoAgent => 'Agent';

  @override
  String get landingBentoStudioTitle => 'Studio';

  @override
  String get landingBentoStudioBody =>
      'Define an agent with identity and a price. On-chain deploy is coming.';

  @override
  String get landingBentoIdentityTitle => 'On-chain identity';

  @override
  String get landingBentoIdentityBody =>
      'Every Marketplace agent has a registry id. You can see who it is before you pay.';

  @override
  String get landingDemoLive => 'Live demo';

  @override
  String get landingHireTry => 'Press Hire';

  @override
  String get landingHireHint =>
      'Press Hire. Watch USDC lock, the agent work, deliver, and only then get paid.';

  @override
  String get landingHireTask =>
      'Check this Stellar account for incoming payments.';

  @override
  String get landingHireCta => 'Hire';

  @override
  String get landingHireSigning => 'You hire';

  @override
  String get landingHireLocking => 'USDC locks';

  @override
  String get landingHireWorking => 'Agent at work';

  @override
  String get landingHireDelivering => 'Agent delivers';

  @override
  String get landingHireReview => 'You review';

  @override
  String get landingHireDone => 'You accept — paid';

  @override
  String landingHireWalletBody(String amount) {
    return 'You open the job. $amount USDC is still in your wallet — the agent is not paid yet.';
  }

  @override
  String get landingHireLockBody =>
      'The money enters a vault: the escrow contract. It cannot leave on its own.';

  @override
  String get landingHireWorkBody =>
      'The agent is notified and starts. The vault stays locked the whole time.';

  @override
  String get landingHireDeliverBody =>
      'The work comes to you. The money still cannot leave the vault.';

  @override
  String get landingHireReviewBody =>
      'You inspect the work. Nothing is paid until you accept.';

  @override
  String get landingHireReleaseBody =>
      'The vault pays the agent and releases the work. No accept, no payout — and no free work.';

  @override
  String get landingHireReplay => 'Replay';

  @override
  String get landingHireStepHire => 'Hire';

  @override
  String get landingHireStepLock => 'Lock';

  @override
  String get landingHireStepWork => 'Work';

  @override
  String get landingHireStepDeliver => 'Deliver';

  @override
  String get landingHireStepReview => 'Review';

  @override
  String get landingHireStepPay => 'Pay';

  @override
  String get landingHireYou => 'You';

  @override
  String get landingHireLegendUsdc => 'USDC';

  @override
  String get landingHireLegendWork => 'Work';

  @override
  String get landingComing => 'Coming';

  @override
  String get landingOpenExplorer => 'Open on StellarExpert';

  @override
  String get landingWhyStellar => 'Why Stellar';

  @override
  String get landingWhyStellarTitle =>
      'Micropayments that settle while the agent works.';

  @override
  String get landingSettleTitle => '~5s settlement';

  @override
  String get landingSettleBody =>
      'Payments to agents finalize in seconds, not days.';

  @override
  String get landingFeesTitle => 'Fees of a fraction of a cent';

  @override
  String get landingFeesBody => 'Micropayments per task remain worthwhile.';

  @override
  String get landingUsdcTitle => 'Native USDC';

  @override
  String get landingUsdcBody =>
      'Price and pay agents in a stable, dollar-backed asset.';

  @override
  String get footerDemo => 'Demo build. Mock data, no real funds.';

  @override
  String get footerBrand => 'Brand';

  @override
  String get footerProduct => 'Product';

  @override
  String get footerResources => 'Resources';

  @override
  String get footerIssues => 'Issues';

  @override
  String get footerTestnet => 'Runs on Stellar Testnet. Test USDC only.';

  @override
  String get footerBuiltOn => 'Built on';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonAll => 'All';

  @override
  String get walletConnect => 'Connect wallet';

  @override
  String get walletConnectShort => 'Connect';

  @override
  String get walletConnecting => 'Connecting…';

  @override
  String get walletConnectTitle => 'Connect a wallet';

  @override
  String get walletConnectMessage =>
      'Your wallet signs deploys and payments. puls3 never sees your secret key.';

  @override
  String walletConnectNamed(String walletName) {
    return 'Connect $walletName';
  }

  @override
  String walletWaitingNamed(String walletName) {
    return 'Waiting for $walletName…';
  }

  @override
  String get walletWaitingConfirmation => 'Waiting for wallet confirmation…';

  @override
  String get walletDisconnect => 'Disconnect';

  @override
  String get walletCopyAddress => 'Copy address';

  @override
  String get walletAddress => 'Address';

  @override
  String get walletTestnetOnly => 'Stellar Testnet only. No real funds.';

  @override
  String walletInstall(String walletName) {
    return 'Install $walletName';
  }

  @override
  String get marketTitle => 'Marketplace';

  @override
  String get marketLead => 'Find an agent, hire it, pay it in USDC on Stellar.';

  @override
  String get marketCreateAgent => 'Create agent';

  @override
  String get marketSearchHint => 'Search agents, skills, or models';

  @override
  String get marketClearSearch => 'Clear search';

  @override
  String get marketCouldNotLoad => 'Could not load the agents';

  @override
  String get marketCouldNotLoadMessage =>
      'The puls3 server did not respond. Check your connection and try again.';

  @override
  String get marketDemoTitle => 'Showing the demo catalog';

  @override
  String get marketDemoMessage =>
      'The puls3 server is unreachable, so these agents are not read from the chain.';

  @override
  String get marketEmptyTitle => 'No agents yet';

  @override
  String get marketEmptyMessage =>
      'Agents registered on-chain appear here. Be the first to publish one.';

  @override
  String get marketEmptyAction => 'Create an agent';

  @override
  String get marketNoMatchTitle => 'No matching agents';

  @override
  String get marketNoMatchMessage => 'Try another search or fewer filters.';

  @override
  String get marketClearFilters => 'Clear filters';

  @override
  String marketShowingCount(int visible, int total) {
    return 'SHOWING $visible OF $total';
  }

  @override
  String marketAgentsLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AGENTS LIVE',
      one: '1 AGENT LIVE',
    );
    return '$_temp0';
  }

  @override
  String get marketDemoCatalog => 'DEMO CATALOG';

  @override
  String get marketFilters => 'Filters';

  @override
  String marketFiltersActive(int count) {
    return 'Filters ($count active)';
  }

  @override
  String get marketReset => 'Reset';

  @override
  String get marketSortBy => 'Sort by';

  @override
  String get marketSkills => 'Skills';

  @override
  String marketShowAgents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count agents',
      one: 'Show 1 agent',
    );
    return '$_temp0';
  }

  @override
  String get marketClearAll => 'Clear all';

  @override
  String get sortFeatured => 'Featured';

  @override
  String get sortPriceLowToHigh => 'Price: low to high';

  @override
  String get sortPriceHighToLow => 'Price: high to low';

  @override
  String get sortTopRated => 'Top rated';

  @override
  String get studioTitle => 'Agent Studio';

  @override
  String get studioLead =>
      'Design an agent, give it a price, deploy it with its own wallet.';

  @override
  String get studioPreview => 'Marketplace preview';

  @override
  String get studioYourAgent => 'Your agent';

  @override
  String get studioGeneralist => 'Generalist';

  @override
  String get studioDeployHint =>
      'On deploy, puls3 creates a Stellar wallet for this agent and registers its identity on Soroban.';

  @override
  String get studioDeploy => 'Deploy to Stellar';

  @override
  String get studioSaveDraft => 'Save draft';

  @override
  String get studioSaving => 'Saving…';

  @override
  String get studioTestRun => 'Test run';

  @override
  String get studioMyAgents => 'My agents';

  @override
  String get studioConnectToSave =>
      'Connect your wallet to save drafts and test runs.';

  @override
  String get myAgentsTitle => 'My agents';

  @override
  String get myAgentsSubtitle => 'Your drafts and deployed agents.';

  @override
  String get myAgentsSubtitleDemo =>
      'Your drafts and deployed agents. Demo: kept in this browser tab only.';

  @override
  String get myAgentsNew => 'New agent';

  @override
  String get myAgentsConnectTitle => 'Connect your wallet';

  @override
  String get myAgentsConnectMessage =>
      'Your drafts and agents belong to your wallet.';

  @override
  String get myAgentsLoadError => 'Could not load your agents';

  @override
  String get myAgentsEmptyTitle => 'No agents yet';

  @override
  String get myAgentsEmptyMessage =>
      'Agents you save or deploy from the Studio show up here.';

  @override
  String get myAgentsEmptyAction => 'Create your first agent';

  @override
  String get agentAbout => 'About';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentOnChainIdentity => 'On-chain identity';

  @override
  String get agentId => 'Agent id';

  @override
  String get agentDemoNotOnChain => 'Demo agent, not on chain';

  @override
  String get agentPaymentWallet => 'Payment wallet';

  @override
  String get agentViewOnExplorer => 'View on explorer';

  @override
  String get agentPrice => 'Price';

  @override
  String hireAgent(String name) {
    return 'Hire $name';
  }

  @override
  String get hireNotFoundTitle => 'Hire not found';

  @override
  String get hireCouldNotLoad => 'Could not load this hire';

  @override
  String get agentCouldNotLoad => 'Could not load this agent';

  @override
  String get pricePerTask => '/ task';

  @override
  String get agentUntitled => 'Untitled agent';

  @override
  String get agentUnspecifiedModel => 'Unspecified';

  @override
  String get agentNotFoundTitle => 'Agent not found';

  @override
  String get agentNotFoundMessage =>
      'No agent with this id is registered. It may have been removed, or the link is wrong.';

  @override
  String get agentBackToMarketplace => 'Back to Marketplace';

  @override
  String get agentChecking => 'Checking the agent on the server…';

  @override
  String get agentHireDisabled => 'Hire is disabled until the agent loads.';

  @override
  String get agentStaleTitle => 'Showing the last known data';

  @override
  String get agentStaleMessage =>
      'The puls3 server did not respond, so this agent could not be confirmed.';

  @override
  String get agentPaidOnStellar =>
      'Paid in USDC on Stellar. Settles in about 5 seconds.';

  @override
  String get agentHire => 'Hire';

  @override
  String get agentLoading => 'Loading agent';

  @override
  String get marketLoadingAgents => 'Loading agents';

  @override
  String get agentPricePerTask => 'Price / task';

  @override
  String get agentRating => 'Rating';

  @override
  String get agentOnChainId => 'On-chain id';

  @override
  String get agentDemo => 'Demo';

  @override
  String get agentDetails => 'Details';

  @override
  String get networkTestnet => 'Testnet';

  @override
  String get skillOnChainAnalytics => 'On-chain analytics';

  @override
  String get skillMonitoring => 'Monitoring';

  @override
  String get skillSummaries => 'Summaries';

  @override
  String get skillPayments => 'Payments';

  @override
  String get skillAnchors => 'Anchors';

  @override
  String get skillCompliance => 'Compliance';

  @override
  String get skillSmartContracts => 'Smart contracts';

  @override
  String get skillSecurity => 'Security';

  @override
  String get skillRust => 'Rust';

  @override
  String get skillDocumentParsing => 'Document parsing';

  @override
  String get skillAccounting => 'Accounting';

  @override
  String get skillTrading => 'Trading';

  @override
  String get skillCopywriting => 'Copywriting';

  @override
  String get skillMarketing => 'Marketing';

  @override
  String get skillCustomerSupport => 'Customer support';

  @override
  String get skillTriage => 'Triage';

  @override
  String get skillDataCleaning => 'Data cleaning';

  @override
  String get skillResearch => 'Research';

  @override
  String get demoDescAgt001 =>
      'Monitors Stellar accounts and summarizes balance changes, payments and trustline updates in plain language.';

  @override
  String get demoDescAgt002 =>
      'Plans cross-border payouts, compares anchor routes and prepares USDC transfers for review.';

  @override
  String get demoDescAgt003 =>
      'Reviews Soroban smart contracts for common pitfalls and explains findings with suggested fixes.';

  @override
  String get demoDescAgt004 =>
      'Reads invoices, extracts line items and drafts matching USDC payment requests.';

  @override
  String get demoDescAgt005 =>
      'Tracks SDEX order books and liquidity pools and delivers a daily market brief.';

  @override
  String get demoDescAgt006 =>
      'Writes landing pages, release notes and social threads in your brand voice.';

  @override
  String get demoDescAgt007 =>
      'Answers wallet support tickets, triages bugs and escalates with full context.';

  @override
  String get demoDescAgt008 =>
      'Cleans CSV exports, joins datasets and returns tidy tables with charts.';

  @override
  String get studioSectionIdentity => 'Identity';

  @override
  String get studioAgentName => 'Agent name';

  @override
  String get studioAgentNameHint => 'For example, Brief Bot';

  @override
  String studioCharacters(int count) {
    return '$count characters';
  }

  @override
  String get studioDescription => 'Description';

  @override
  String get studioDescriptionHint =>
      'What the agent does, in one or two sentences';

  @override
  String get studioModel => 'Model';

  @override
  String get studioModelOwnProvider => 'Runs on your own provider account';

  @override
  String get studioModelFreeTier => 'Free tier on your own Workers AI account';

  @override
  String studioModelOwnKey(String provider) {
    return 'Uses your own $provider key';
  }

  @override
  String studioModelFree(String label) {
    return '$label · free';
  }

  @override
  String get studioSectionBehavior => 'Behavior';

  @override
  String get studioSystemPrompt => 'System prompt';

  @override
  String get studioSystemPromptHint =>
      'The instructions the agent follows on every hire';

  @override
  String get studioAddSkill => 'Add a skill';

  @override
  String get studioAddSkillHint => 'Type and press Enter';

  @override
  String get studioAddSkillTooltip => 'Add skill';

  @override
  String get studioSectionIo => 'Input and output';

  @override
  String get studioInputMax => 'Longest input (characters)';

  @override
  String get studioInputMaxHint => 'For example, 6000';

  @override
  String get studioInputHelper =>
      'Plain text from the person who hires the agent';

  @override
  String get studioAnswerFormat => 'Answer format';

  @override
  String get studioPlainText => 'Plain text';

  @override
  String get studioMarkdown => 'Markdown';

  @override
  String get studioOutputMax => 'Longest answer';

  @override
  String get studioSectionPricing => 'Pricing';

  @override
  String get studioPricePerTask => 'Price per task';

  @override
  String get studioReady => 'Ready to deploy';

  @override
  String studioFieldsToComplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields to complete',
      one: '1 field to complete',
    );
    return '$_temp0';
  }

  @override
  String get studioWhatIsMissing => 'What is missing?';

  @override
  String get studioConnectDraftOwner =>
      'Connect the wallet that owns this draft to open it.';

  @override
  String studioUnsavedRevision(int revision) {
    return 'Unsaved changes · revision $revision';
  }

  @override
  String studioSavedRevision(int revision) {
    return 'Saved · revision $revision';
  }

  @override
  String studioSavedRevisionDemo(int revision) {
    return 'Saved · revision $revision (demo)';
  }

  @override
  String get studioReload => 'Reload';

  @override
  String get studioKeepMine => 'Keep mine';

  @override
  String studioNotSaved(String message) {
    return 'Not saved: $message';
  }

  @override
  String get studioServerNoAnswer =>
      'Not saved: the server did not respond. Your text stays.';

  @override
  String studioVersionBanner(int next, int current) {
    return 'Editing creates version $next. Hirers keep version $current until you deploy.';
  }

  @override
  String get studioErrWholeNumber => 'Enter a whole number of characters.';

  @override
  String get studioErrPriceFormat => 'Enter an amount like 0.50.';

  @override
  String get studioErrSkillLetters =>
      'Use letters or numbers in each skill name.';

  @override
  String get studioErrSkillTooLong => 'A skill name is too long.';

  @override
  String get studioErrNameMissing => 'Give your agent a name.';

  @override
  String get studioErrNameTooShort => 'The name is too short.';

  @override
  String get studioErrNameTooLong => 'The name is too long.';

  @override
  String get studioErrNameCheck => 'Check the name.';

  @override
  String get studioErrDescMissing => 'Say what the agent does.';

  @override
  String get studioErrDescTooShort => 'The description is too short.';

  @override
  String get studioErrDescTooLong => 'The description is too long.';

  @override
  String get studioErrDescCheck => 'Check the description.';

  @override
  String get studioErrSkillsMissing => 'Add at least one skill.';

  @override
  String get studioErrSkillsTooMany => 'Too many skills: remove some.';

  @override
  String get studioErrSkillDuplicate => 'Two skills have the same name.';

  @override
  String get studioErrSkillCheck => 'Check the skill names.';

  @override
  String get studioErrModelMissing => 'Choose a model.';

  @override
  String get studioErrModelFreeTier =>
      'This model is not available on the free tier.';

  @override
  String get studioErrModelProvider => 'This provider is not enabled yet.';

  @override
  String get studioErrPromptMissing =>
      'Write the instructions the agent follows.';

  @override
  String get studioErrPromptTooShort => 'The instructions are too short.';

  @override
  String get studioErrPromptTooLong => 'The instructions are too long.';

  @override
  String get studioErrPromptCheck => 'Check the instructions.';

  @override
  String get studioErrInputMissing =>
      'Set the longest input the agent accepts.';

  @override
  String get studioErrInputTooLow =>
      'The input limit must be at least 1 character.';

  @override
  String get studioErrInputTooHigh =>
      'The input limit is above what agents accept.';

  @override
  String get studioErrInputCheck => 'Check the input.';

  @override
  String get studioErrOutputMissing =>
      'Set the longest answer the agent returns.';

  @override
  String get studioErrOutputTooLow =>
      'The answer limit must be at least 1 character.';

  @override
  String get studioErrOutputTooHigh =>
      'The answer limit is above what agents return.';

  @override
  String get studioErrOutputCheck => 'Check the output.';

  @override
  String get studioErrPriceMissing => 'Set a price.';

  @override
  String get studioErrPricePositive => 'The price must be more than 0.';

  @override
  String get studioErrPriceCheck => 'Check the price.';

  @override
  String get studioErrCannotSave => 'This agent cannot be saved.';

  @override
  String get playgroundDemoLead => 'Demo test runner: no model answers yet.';

  @override
  String get playgroundLiveLead => 'Test runs are free and limited per day.';

  @override
  String get playgroundProviderToken => 'Provider token';

  @override
  String get playgroundProviderTokenHint => 'Stored for your test runs';

  @override
  String get playgroundAccountId => 'Cloudflare account id';

  @override
  String get playgroundRunning => 'Running… It stops at the runtime timeout.';

  @override
  String get playgroundFailed => 'The test run failed';

  @override
  String get playgroundTryLater => 'Try again in a moment.';

  @override
  String get playgroundQuota => 'You used today\'s test runs.';

  @override
  String get playgroundSampleTask => 'A sample task for your agent';

  @override
  String playgroundTooLong(int max) {
    return 'This agent accepts up to $max characters.';
  }

  @override
  String get playgroundRun => 'Run';

  @override
  String get playgroundRunningButton => 'Running…';

  @override
  String get playgroundResultLabel => 'Test run: not paid, nothing on chain';

  @override
  String playgroundRunsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count runs left today',
      one: '1 run left today',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Close';

  @override
  String get myAgentsDrafts => 'Drafts';

  @override
  String get myAgentsDeployingOrFailed => 'Deploying or failed';

  @override
  String get myAgentsLive => 'Live';

  @override
  String myAgentsDraftRevision(int revision) {
    return 'Draft · revision $revision';
  }

  @override
  String get myAgentsDeploying => 'Deploying';

  @override
  String get myAgentsDeployFailed => 'Deploy failed';

  @override
  String myAgentsLiveVersion(int version) {
    return 'Live · version $version';
  }

  @override
  String get myAgentsContinue => 'Continue editing';

  @override
  String get myAgentsResume => 'Resume deploy';

  @override
  String myAgentsResumeStep(int step) {
    return 'Resume deploy (step $step)';
  }

  @override
  String get myAgentsView => 'View';

  @override
  String get myAgentsEdit => 'Edit';

  @override
  String get myAgentsServerNoAnswer => 'The server did not respond. Try again.';

  @override
  String get hireDemoOnly =>
      'Demo only: signing here does not move funds. Escrow payments arrive once wallet sign-in is live on the server.';

  @override
  String get hireTaskLabel => 'What should the agent do?';

  @override
  String get hireTaskHint => 'Describe the task for this hire';

  @override
  String get hireAsset => 'Asset';

  @override
  String get hireNetwork => 'Network';

  @override
  String get hireDestination => 'Destination';

  @override
  String get hireEscrow => 'Escrow';

  @override
  String get hireNetworkFee => 'Network fee';

  @override
  String get hireSigning => 'Signing…';

  @override
  String get hireConfirmSign => 'Confirm & sign';

  @override
  String get hireDemoSignature => 'Demo signature only';

  @override
  String get hireDemoDone =>
      'No payment was sent and no hire was created. Real escrow payments arrive once wallet sign-in is live on the server.';

  @override
  String get hireAgentLabel => 'Agent';

  @override
  String get hirePaymentHeld => 'Payment held by the escrow';

  @override
  String get hirePaymentConfirming => 'Payment sent, confirming on Stellar…';

  @override
  String get hirePaymentHeldBody =>
      'Your USDC is held by the escrow contract until you approve the result. The agent starts working.';

  @override
  String get hirePaymentConfirmingBody =>
      'puls3 is confirming the transaction and checking that it matches this hire. You can follow it on StellarExpert.';

  @override
  String get hireTxHash => 'Tx hash';

  @override
  String get hireViewHire => 'View hire';

  @override
  String get hireViewExplorer => 'View on StellarExpert';

  @override
  String get hirePaymentFailed => 'Payment failed';

  @override
  String get hirePaymentIncomplete => 'Payment could not be completed';

  @override
  String get hireEscrowProtection =>
      'Escrow protection: your USDC stays in the escrow contract. The agent is paid only when you approve the result, and you get a refund if it never delivers.';

  @override
  String get studioDraftLoadError =>
      'The draft could not be loaded. Try again.';

  @override
  String get playgroundUnavailable => 'The test runner is unavailable.';

  @override
  String playgroundQuotaReset(String time) {
    return 'You used today\'s test runs. They reset at $time.';
  }

  @override
  String get playgroundOutputCopied => 'Output copied';

  @override
  String get marketSortAgents => 'Sort agents';

  @override
  String get hireIdLabel => 'Hire';
}
