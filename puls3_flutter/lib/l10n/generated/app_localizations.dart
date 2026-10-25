import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('pt', 'PT'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'puls3: the agent hub on Stellar'**
  String get appTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languagePortugueseBrazil.
  ///
  /// In en, this message translates to:
  /// **'Português (Brasil)'**
  String get languagePortugueseBrazil;

  /// No description provided for @languagePortuguesePortugal.
  ///
  /// In en, this message translates to:
  /// **'Português (Portugal)'**
  String get languagePortuguesePortugal;

  /// No description provided for @languageMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageMenuTooltip;

  /// No description provided for @navStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get navStudio;

  /// No description provided for @navMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get navMarketplace;

  /// No description provided for @navOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open app'**
  String get navOpenApp;

  /// No description provided for @navMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// No description provided for @navDocs.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get navDocs;

  /// No description provided for @navGitHub.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get navGitHub;

  /// No description provided for @landingKicker.
  ///
  /// In en, this message translates to:
  /// **'The agent hub on Stellar'**
  String get landingKicker;

  /// No description provided for @landingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Build. Discover. Pay.\nAI agents on Stellar.'**
  String get landingHeadline;

  /// No description provided for @landingLead.
  ///
  /// In en, this message translates to:
  /// **'Create AI agents with on-chain identity and wallet, find the right one in a single Marketplace, and pay per task in USDC, held in escrow until the work is done.'**
  String get landingLead;

  /// No description provided for @landingOpenStudio.
  ///
  /// In en, this message translates to:
  /// **'Open Studio'**
  String get landingOpenStudio;

  /// No description provided for @landingExploreMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Explore Marketplace'**
  String get landingExploreMarketplace;

  /// No description provided for @landingExploreAgents.
  ///
  /// In en, this message translates to:
  /// **'Explore agents'**
  String get landingExploreAgents;

  /// No description provided for @landingBuildAgent.
  ///
  /// In en, this message translates to:
  /// **'Build an agent'**
  String get landingBuildAgent;

  /// No description provided for @landingViewDocs.
  ///
  /// In en, this message translates to:
  /// **'View documentation'**
  String get landingViewDocs;

  /// No description provided for @landingLiveInMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Live in the Marketplace'**
  String get landingLiveInMarketplace;

  /// No description provided for @landingSeeFirstHire.
  ///
  /// In en, this message translates to:
  /// **'See the first hire paid into escrow'**
  String get landingSeeFirstHire;

  /// No description provided for @landingFinalCtaTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with an agent.'**
  String get landingFinalCtaTitle;

  /// No description provided for @landingFinalCtaLead.
  ///
  /// In en, this message translates to:
  /// **'Hire one on testnet, build your own in the Studio, or help build puls3 in the open.'**
  String get landingFinalCtaLead;

  /// No description provided for @landingWhyStellar.
  ///
  /// In en, this message translates to:
  /// **'Why Stellar'**
  String get landingWhyStellar;

  /// No description provided for @landingSettleTitle.
  ///
  /// In en, this message translates to:
  /// **'~5s settlement'**
  String get landingSettleTitle;

  /// No description provided for @landingSettleBody.
  ///
  /// In en, this message translates to:
  /// **'Payments to agents finalize in seconds, not days.'**
  String get landingSettleBody;

  /// No description provided for @landingFeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Fees of a fraction of a cent'**
  String get landingFeesTitle;

  /// No description provided for @landingFeesBody.
  ///
  /// In en, this message translates to:
  /// **'Micropayments per task remain worthwhile.'**
  String get landingFeesBody;

  /// No description provided for @landingUsdcTitle.
  ///
  /// In en, this message translates to:
  /// **'Native USDC'**
  String get landingUsdcTitle;

  /// No description provided for @landingUsdcBody.
  ///
  /// In en, this message translates to:
  /// **'Price and pay agents in a stable, dollar-backed asset.'**
  String get landingUsdcBody;

  /// No description provided for @footerDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo build. Mock data, no real funds.'**
  String get footerDemo;

  /// No description provided for @footerBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get footerBrand;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @walletConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect wallet'**
  String get walletConnect;

  /// No description provided for @walletConnectShort.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get walletConnectShort;

  /// No description provided for @walletConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get walletConnecting;

  /// No description provided for @walletConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a wallet'**
  String get walletConnectTitle;

  /// No description provided for @walletConnectMessage.
  ///
  /// In en, this message translates to:
  /// **'Your wallet signs deploys and payments. puls3 never sees your secret key.'**
  String get walletConnectMessage;

  /// No description provided for @walletConnectNamed.
  ///
  /// In en, this message translates to:
  /// **'Connect {walletName}'**
  String walletConnectNamed(String walletName);

  /// No description provided for @walletWaitingNamed.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {walletName}…'**
  String walletWaitingNamed(String walletName);

  /// No description provided for @walletWaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for wallet confirmation…'**
  String get walletWaitingConfirmation;

  /// No description provided for @walletDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get walletDisconnect;

  /// No description provided for @walletCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get walletCopyAddress;

  /// No description provided for @walletAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get walletAddress;

  /// No description provided for @walletTestnetOnly.
  ///
  /// In en, this message translates to:
  /// **'Stellar Testnet only. No real funds.'**
  String get walletTestnetOnly;

  /// No description provided for @walletInstall.
  ///
  /// In en, this message translates to:
  /// **'Install {walletName}'**
  String walletInstall(String walletName);

  /// No description provided for @backendConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to backend…'**
  String get backendConnecting;

  /// No description provided for @backendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Backend unavailable'**
  String get backendUnavailable;

  /// No description provided for @backendVersion.
  ///
  /// In en, this message translates to:
  /// **'Backend v{version}'**
  String backendVersion(String version);

  /// No description provided for @marketTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get marketTitle;

  /// No description provided for @marketLead.
  ///
  /// In en, this message translates to:
  /// **'Find an agent, hire it, pay it in USDC on Stellar.'**
  String get marketLead;

  /// No description provided for @marketCreateAgent.
  ///
  /// In en, this message translates to:
  /// **'Create agent'**
  String get marketCreateAgent;

  /// No description provided for @marketSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search agents, skills, or models'**
  String get marketSearchHint;

  /// No description provided for @marketClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get marketClearSearch;

  /// No description provided for @marketCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load the agents'**
  String get marketCouldNotLoad;

  /// No description provided for @marketCouldNotLoadMessage.
  ///
  /// In en, this message translates to:
  /// **'The puls3 server did not respond. Check your connection and try again.'**
  String get marketCouldNotLoadMessage;

  /// No description provided for @marketDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing the demo catalog'**
  String get marketDemoTitle;

  /// No description provided for @marketDemoMessage.
  ///
  /// In en, this message translates to:
  /// **'The puls3 server is unreachable, so these agents are not read from the chain.'**
  String get marketDemoMessage;

  /// No description provided for @marketEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No agents yet'**
  String get marketEmptyTitle;

  /// No description provided for @marketEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Agents registered on-chain appear here. Be the first to publish one.'**
  String get marketEmptyMessage;

  /// No description provided for @marketEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Create an agent'**
  String get marketEmptyAction;

  /// No description provided for @marketNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching agents'**
  String get marketNoMatchTitle;

  /// No description provided for @marketNoMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Try another search or fewer filters.'**
  String get marketNoMatchMessage;

  /// No description provided for @marketClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get marketClearFilters;

  /// No description provided for @marketShowingCount.
  ///
  /// In en, this message translates to:
  /// **'SHOWING {visible} OF {total}'**
  String marketShowingCount(int visible, int total);

  /// No description provided for @marketAgentsLive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 AGENT LIVE} other{{count} AGENTS LIVE}}'**
  String marketAgentsLive(int count);

  /// No description provided for @marketDemoCatalog.
  ///
  /// In en, this message translates to:
  /// **'DEMO CATALOG'**
  String get marketDemoCatalog;

  /// No description provided for @marketFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get marketFilters;

  /// No description provided for @marketFiltersActive.
  ///
  /// In en, this message translates to:
  /// **'Filters ({count} active)'**
  String marketFiltersActive(int count);

  /// No description provided for @marketReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get marketReset;

  /// No description provided for @marketSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get marketSortBy;

  /// No description provided for @marketSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get marketSkills;

  /// No description provided for @marketShowAgents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 agent} other{Show {count} agents}}'**
  String marketShowAgents(int count);

  /// No description provided for @marketClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get marketClearAll;

  /// No description provided for @sortFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get sortFeatured;

  /// No description provided for @sortPriceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: low to high'**
  String get sortPriceLowToHigh;

  /// No description provided for @sortPriceHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Price: high to low'**
  String get sortPriceHighToLow;

  /// No description provided for @sortTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get sortTopRated;

  /// No description provided for @studioTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent Studio'**
  String get studioTitle;

  /// No description provided for @studioLead.
  ///
  /// In en, this message translates to:
  /// **'Design an agent, give it a price, deploy it with its own wallet.'**
  String get studioLead;

  /// No description provided for @studioPreview.
  ///
  /// In en, this message translates to:
  /// **'Marketplace preview'**
  String get studioPreview;

  /// No description provided for @studioYourAgent.
  ///
  /// In en, this message translates to:
  /// **'Your agent'**
  String get studioYourAgent;

  /// No description provided for @studioGeneralist.
  ///
  /// In en, this message translates to:
  /// **'Generalist'**
  String get studioGeneralist;

  /// No description provided for @studioDeployHint.
  ///
  /// In en, this message translates to:
  /// **'On deploy, puls3 creates a Stellar wallet for this agent and registers its identity on Soroban.'**
  String get studioDeployHint;

  /// No description provided for @studioDeploy.
  ///
  /// In en, this message translates to:
  /// **'Deploy to Stellar'**
  String get studioDeploy;

  /// No description provided for @studioSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get studioSaveDraft;

  /// No description provided for @studioSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get studioSaving;

  /// No description provided for @studioTestRun.
  ///
  /// In en, this message translates to:
  /// **'Test run'**
  String get studioTestRun;

  /// No description provided for @studioMyAgents.
  ///
  /// In en, this message translates to:
  /// **'My agents'**
  String get studioMyAgents;

  /// No description provided for @studioConnectToSave.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet to save drafts and test runs.'**
  String get studioConnectToSave;

  /// No description provided for @myAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'My agents'**
  String get myAgentsTitle;

  /// No description provided for @myAgentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your drafts and deployed agents.'**
  String get myAgentsSubtitle;

  /// No description provided for @myAgentsSubtitleDemo.
  ///
  /// In en, this message translates to:
  /// **'Your drafts and deployed agents. Demo: kept in this browser tab only.'**
  String get myAgentsSubtitleDemo;

  /// No description provided for @myAgentsNew.
  ///
  /// In en, this message translates to:
  /// **'New agent'**
  String get myAgentsNew;

  /// No description provided for @myAgentsConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your wallet'**
  String get myAgentsConnectTitle;

  /// No description provided for @myAgentsConnectMessage.
  ///
  /// In en, this message translates to:
  /// **'Your drafts and agents belong to your wallet.'**
  String get myAgentsConnectMessage;

  /// No description provided for @myAgentsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your agents'**
  String get myAgentsLoadError;

  /// No description provided for @myAgentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No agents yet'**
  String get myAgentsEmptyTitle;

  /// No description provided for @myAgentsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Agents you save or deploy from the Studio show up here.'**
  String get myAgentsEmptyMessage;

  /// No description provided for @myAgentsEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Create your first agent'**
  String get myAgentsEmptyAction;

  /// No description provided for @agentAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get agentAbout;

  /// No description provided for @agentSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get agentSkills;

  /// No description provided for @agentOnChainIdentity.
  ///
  /// In en, this message translates to:
  /// **'On-chain identity'**
  String get agentOnChainIdentity;

  /// No description provided for @agentId.
  ///
  /// In en, this message translates to:
  /// **'Agent id'**
  String get agentId;

  /// No description provided for @agentDemoNotOnChain.
  ///
  /// In en, this message translates to:
  /// **'Demo agent, not on chain'**
  String get agentDemoNotOnChain;

  /// No description provided for @agentPaymentWallet.
  ///
  /// In en, this message translates to:
  /// **'Payment wallet'**
  String get agentPaymentWallet;

  /// No description provided for @agentViewOnExplorer.
  ///
  /// In en, this message translates to:
  /// **'View on explorer'**
  String get agentViewOnExplorer;

  /// No description provided for @agentPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get agentPrice;

  /// No description provided for @hireAgent.
  ///
  /// In en, this message translates to:
  /// **'Hire {name}'**
  String hireAgent(String name);

  /// No description provided for @hireNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Hire not found'**
  String get hireNotFoundTitle;

  /// No description provided for @hireCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load this hire'**
  String get hireCouldNotLoad;

  /// No description provided for @agentCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load this agent'**
  String get agentCouldNotLoad;

  /// No description provided for @pricePerTask.
  ///
  /// In en, this message translates to:
  /// **'/ task'**
  String get pricePerTask;

  /// No description provided for @agentUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled agent'**
  String get agentUntitled;

  /// No description provided for @agentUnspecifiedModel.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get agentUnspecifiedModel;

  /// No description provided for @agentNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent not found'**
  String get agentNotFoundTitle;

  /// No description provided for @agentNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'No agent with this id is registered. It may have been removed, or the link is wrong.'**
  String get agentNotFoundMessage;

  /// No description provided for @agentBackToMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Back to Marketplace'**
  String get agentBackToMarketplace;

  /// No description provided for @agentChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the agent on the server…'**
  String get agentChecking;

  /// No description provided for @agentHireDisabled.
  ///
  /// In en, this message translates to:
  /// **'Hire is disabled until the agent loads.'**
  String get agentHireDisabled;

  /// No description provided for @agentStaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing the last known data'**
  String get agentStaleTitle;

  /// No description provided for @agentStaleMessage.
  ///
  /// In en, this message translates to:
  /// **'The puls3 server did not respond, so this agent could not be confirmed.'**
  String get agentStaleMessage;

  /// No description provided for @agentPaidOnStellar.
  ///
  /// In en, this message translates to:
  /// **'Paid in USDC on Stellar. Settles in about 5 seconds.'**
  String get agentPaidOnStellar;

  /// No description provided for @agentHire.
  ///
  /// In en, this message translates to:
  /// **'Hire'**
  String get agentHire;

  /// No description provided for @agentLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading agent'**
  String get agentLoading;

  /// No description provided for @marketLoadingAgents.
  ///
  /// In en, this message translates to:
  /// **'Loading agents'**
  String get marketLoadingAgents;

  /// No description provided for @agentPricePerTask.
  ///
  /// In en, this message translates to:
  /// **'Price / task'**
  String get agentPricePerTask;

  /// No description provided for @agentRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get agentRating;

  /// No description provided for @agentOnChainId.
  ///
  /// In en, this message translates to:
  /// **'On-chain id'**
  String get agentOnChainId;

  /// No description provided for @agentDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get agentDemo;

  /// No description provided for @agentDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get agentDetails;

  /// No description provided for @networkTestnet.
  ///
  /// In en, this message translates to:
  /// **'Testnet'**
  String get networkTestnet;

  /// No description provided for @skillOnChainAnalytics.
  ///
  /// In en, this message translates to:
  /// **'On-chain analytics'**
  String get skillOnChainAnalytics;

  /// No description provided for @skillMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get skillMonitoring;

  /// No description provided for @skillSummaries.
  ///
  /// In en, this message translates to:
  /// **'Summaries'**
  String get skillSummaries;

  /// No description provided for @skillPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get skillPayments;

  /// No description provided for @skillAnchors.
  ///
  /// In en, this message translates to:
  /// **'Anchors'**
  String get skillAnchors;

  /// No description provided for @skillCompliance.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get skillCompliance;

  /// No description provided for @skillSmartContracts.
  ///
  /// In en, this message translates to:
  /// **'Smart contracts'**
  String get skillSmartContracts;

  /// No description provided for @skillSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get skillSecurity;

  /// No description provided for @skillRust.
  ///
  /// In en, this message translates to:
  /// **'Rust'**
  String get skillRust;

  /// No description provided for @skillDocumentParsing.
  ///
  /// In en, this message translates to:
  /// **'Document parsing'**
  String get skillDocumentParsing;

  /// No description provided for @skillAccounting.
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get skillAccounting;

  /// No description provided for @skillTrading.
  ///
  /// In en, this message translates to:
  /// **'Trading'**
  String get skillTrading;

  /// No description provided for @skillCopywriting.
  ///
  /// In en, this message translates to:
  /// **'Copywriting'**
  String get skillCopywriting;

  /// No description provided for @skillMarketing.
  ///
  /// In en, this message translates to:
  /// **'Marketing'**
  String get skillMarketing;

  /// No description provided for @skillCustomerSupport.
  ///
  /// In en, this message translates to:
  /// **'Customer support'**
  String get skillCustomerSupport;

  /// No description provided for @skillTriage.
  ///
  /// In en, this message translates to:
  /// **'Triage'**
  String get skillTriage;

  /// No description provided for @skillDataCleaning.
  ///
  /// In en, this message translates to:
  /// **'Data cleaning'**
  String get skillDataCleaning;

  /// No description provided for @skillResearch.
  ///
  /// In en, this message translates to:
  /// **'Research'**
  String get skillResearch;

  /// No description provided for @demoDescAgt001.
  ///
  /// In en, this message translates to:
  /// **'Monitors Stellar accounts and summarizes balance changes, payments and trustline updates in plain language.'**
  String get demoDescAgt001;

  /// No description provided for @demoDescAgt002.
  ///
  /// In en, this message translates to:
  /// **'Plans cross-border payouts, compares anchor routes and prepares USDC transfers for review.'**
  String get demoDescAgt002;

  /// No description provided for @demoDescAgt003.
  ///
  /// In en, this message translates to:
  /// **'Reviews Soroban smart contracts for common pitfalls and explains findings with suggested fixes.'**
  String get demoDescAgt003;

  /// No description provided for @demoDescAgt004.
  ///
  /// In en, this message translates to:
  /// **'Reads invoices, extracts line items and drafts matching USDC payment requests.'**
  String get demoDescAgt004;

  /// No description provided for @demoDescAgt005.
  ///
  /// In en, this message translates to:
  /// **'Tracks SDEX order books and liquidity pools and delivers a daily market brief.'**
  String get demoDescAgt005;

  /// No description provided for @demoDescAgt006.
  ///
  /// In en, this message translates to:
  /// **'Writes landing pages, release notes and social threads in your brand voice.'**
  String get demoDescAgt006;

  /// No description provided for @demoDescAgt007.
  ///
  /// In en, this message translates to:
  /// **'Answers wallet support tickets, triages bugs and escalates with full context.'**
  String get demoDescAgt007;

  /// No description provided for @demoDescAgt008.
  ///
  /// In en, this message translates to:
  /// **'Cleans CSV exports, joins datasets and returns tidy tables with charts.'**
  String get demoDescAgt008;

  /// No description provided for @studioSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get studioSectionIdentity;

  /// No description provided for @studioAgentName.
  ///
  /// In en, this message translates to:
  /// **'Agent name'**
  String get studioAgentName;

  /// No description provided for @studioAgentNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example, Brief Bot'**
  String get studioAgentNameHint;

  /// No description provided for @studioCharacters.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String studioCharacters(int count);

  /// No description provided for @studioDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get studioDescription;

  /// No description provided for @studioDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What the agent does, in one or two sentences'**
  String get studioDescriptionHint;

  /// No description provided for @studioModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get studioModel;

  /// No description provided for @studioModelOwnProvider.
  ///
  /// In en, this message translates to:
  /// **'Runs on your own provider account'**
  String get studioModelOwnProvider;

  /// No description provided for @studioModelFreeTier.
  ///
  /// In en, this message translates to:
  /// **'Free tier on your own Workers AI account'**
  String get studioModelFreeTier;

  /// No description provided for @studioModelOwnKey.
  ///
  /// In en, this message translates to:
  /// **'Uses your own {provider} key'**
  String studioModelOwnKey(String provider);

  /// No description provided for @studioModelFree.
  ///
  /// In en, this message translates to:
  /// **'{label} · free'**
  String studioModelFree(String label);

  /// No description provided for @studioSectionBehavior.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get studioSectionBehavior;

  /// No description provided for @studioSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'System prompt'**
  String get studioSystemPrompt;

  /// No description provided for @studioSystemPromptHint.
  ///
  /// In en, this message translates to:
  /// **'The instructions the agent follows on every hire'**
  String get studioSystemPromptHint;

  /// No description provided for @studioAddSkill.
  ///
  /// In en, this message translates to:
  /// **'Add a skill'**
  String get studioAddSkill;

  /// No description provided for @studioAddSkillHint.
  ///
  /// In en, this message translates to:
  /// **'Type and press Enter'**
  String get studioAddSkillHint;

  /// No description provided for @studioAddSkillTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add skill'**
  String get studioAddSkillTooltip;

  /// No description provided for @studioSectionIo.
  ///
  /// In en, this message translates to:
  /// **'Input and output'**
  String get studioSectionIo;

  /// No description provided for @studioInputMax.
  ///
  /// In en, this message translates to:
  /// **'Longest input (characters)'**
  String get studioInputMax;

  /// No description provided for @studioInputMaxHint.
  ///
  /// In en, this message translates to:
  /// **'For example, 6000'**
  String get studioInputMaxHint;

  /// No description provided for @studioInputHelper.
  ///
  /// In en, this message translates to:
  /// **'Plain text from the person who hires the agent'**
  String get studioInputHelper;

  /// No description provided for @studioAnswerFormat.
  ///
  /// In en, this message translates to:
  /// **'Answer format'**
  String get studioAnswerFormat;

  /// No description provided for @studioPlainText.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get studioPlainText;

  /// No description provided for @studioMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get studioMarkdown;

  /// No description provided for @studioOutputMax.
  ///
  /// In en, this message translates to:
  /// **'Longest answer'**
  String get studioOutputMax;

  /// No description provided for @studioSectionPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get studioSectionPricing;

  /// No description provided for @studioPricePerTask.
  ///
  /// In en, this message translates to:
  /// **'Price per task'**
  String get studioPricePerTask;

  /// No description provided for @studioReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to deploy'**
  String get studioReady;

  /// No description provided for @studioFieldsToComplete.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field to complete} other{{count} fields to complete}}'**
  String studioFieldsToComplete(int count);

  /// No description provided for @studioWhatIsMissing.
  ///
  /// In en, this message translates to:
  /// **'What is missing?'**
  String get studioWhatIsMissing;

  /// No description provided for @studioConnectDraftOwner.
  ///
  /// In en, this message translates to:
  /// **'Connect the wallet that owns this draft to open it.'**
  String get studioConnectDraftOwner;

  /// No description provided for @studioUnsavedRevision.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes · revision {revision}'**
  String studioUnsavedRevision(int revision);

  /// No description provided for @studioSavedRevision.
  ///
  /// In en, this message translates to:
  /// **'Saved · revision {revision}'**
  String studioSavedRevision(int revision);

  /// No description provided for @studioSavedRevisionDemo.
  ///
  /// In en, this message translates to:
  /// **'Saved · revision {revision} (demo)'**
  String studioSavedRevisionDemo(int revision);

  /// No description provided for @studioReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get studioReload;

  /// No description provided for @studioKeepMine.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get studioKeepMine;

  /// No description provided for @studioNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved: {message}'**
  String studioNotSaved(String message);

  /// No description provided for @studioServerNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'Not saved: the server did not respond. Your text stays.'**
  String get studioServerNoAnswer;

  /// No description provided for @studioVersionBanner.
  ///
  /// In en, this message translates to:
  /// **'Editing creates version {next}. Hirers keep version {current} until you deploy.'**
  String studioVersionBanner(int next, int current);

  /// No description provided for @studioErrWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of characters.'**
  String get studioErrWholeNumber;

  /// No description provided for @studioErrPriceFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount like 0.50.'**
  String get studioErrPriceFormat;

  /// No description provided for @studioErrSkillLetters.
  ///
  /// In en, this message translates to:
  /// **'Use letters or numbers in each skill name.'**
  String get studioErrSkillLetters;

  /// No description provided for @studioErrSkillTooLong.
  ///
  /// In en, this message translates to:
  /// **'A skill name is too long.'**
  String get studioErrSkillTooLong;

  /// No description provided for @studioErrNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Give your agent a name.'**
  String get studioErrNameMissing;

  /// No description provided for @studioErrNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'The name is too short.'**
  String get studioErrNameTooShort;

  /// No description provided for @studioErrNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'The name is too long.'**
  String get studioErrNameTooLong;

  /// No description provided for @studioErrNameCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the name.'**
  String get studioErrNameCheck;

  /// No description provided for @studioErrDescMissing.
  ///
  /// In en, this message translates to:
  /// **'Say what the agent does.'**
  String get studioErrDescMissing;

  /// No description provided for @studioErrDescTooShort.
  ///
  /// In en, this message translates to:
  /// **'The description is too short.'**
  String get studioErrDescTooShort;

  /// No description provided for @studioErrDescTooLong.
  ///
  /// In en, this message translates to:
  /// **'The description is too long.'**
  String get studioErrDescTooLong;

  /// No description provided for @studioErrDescCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the description.'**
  String get studioErrDescCheck;

  /// No description provided for @studioErrSkillsMissing.
  ///
  /// In en, this message translates to:
  /// **'Add at least one skill.'**
  String get studioErrSkillsMissing;

  /// No description provided for @studioErrSkillsTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many skills: remove some.'**
  String get studioErrSkillsTooMany;

  /// No description provided for @studioErrSkillDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Two skills have the same name.'**
  String get studioErrSkillDuplicate;

  /// No description provided for @studioErrSkillCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the skill names.'**
  String get studioErrSkillCheck;

  /// No description provided for @studioErrModelMissing.
  ///
  /// In en, this message translates to:
  /// **'Choose a model.'**
  String get studioErrModelMissing;

  /// No description provided for @studioErrModelFreeTier.
  ///
  /// In en, this message translates to:
  /// **'This model is not available on the free tier.'**
  String get studioErrModelFreeTier;

  /// No description provided for @studioErrModelProvider.
  ///
  /// In en, this message translates to:
  /// **'This provider is not enabled yet.'**
  String get studioErrModelProvider;

  /// No description provided for @studioErrPromptMissing.
  ///
  /// In en, this message translates to:
  /// **'Write the instructions the agent follows.'**
  String get studioErrPromptMissing;

  /// No description provided for @studioErrPromptTooShort.
  ///
  /// In en, this message translates to:
  /// **'The instructions are too short.'**
  String get studioErrPromptTooShort;

  /// No description provided for @studioErrPromptTooLong.
  ///
  /// In en, this message translates to:
  /// **'The instructions are too long.'**
  String get studioErrPromptTooLong;

  /// No description provided for @studioErrPromptCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the instructions.'**
  String get studioErrPromptCheck;

  /// No description provided for @studioErrInputMissing.
  ///
  /// In en, this message translates to:
  /// **'Set the longest input the agent accepts.'**
  String get studioErrInputMissing;

  /// No description provided for @studioErrInputTooLow.
  ///
  /// In en, this message translates to:
  /// **'The input limit must be at least 1 character.'**
  String get studioErrInputTooLow;

  /// No description provided for @studioErrInputTooHigh.
  ///
  /// In en, this message translates to:
  /// **'The input limit is above what agents accept.'**
  String get studioErrInputTooHigh;

  /// No description provided for @studioErrInputCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the input.'**
  String get studioErrInputCheck;

  /// No description provided for @studioErrOutputMissing.
  ///
  /// In en, this message translates to:
  /// **'Set the longest answer the agent returns.'**
  String get studioErrOutputMissing;

  /// No description provided for @studioErrOutputTooLow.
  ///
  /// In en, this message translates to:
  /// **'The answer limit must be at least 1 character.'**
  String get studioErrOutputTooLow;

  /// No description provided for @studioErrOutputTooHigh.
  ///
  /// In en, this message translates to:
  /// **'The answer limit is above what agents return.'**
  String get studioErrOutputTooHigh;

  /// No description provided for @studioErrOutputCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the output.'**
  String get studioErrOutputCheck;

  /// No description provided for @studioErrPriceMissing.
  ///
  /// In en, this message translates to:
  /// **'Set a price.'**
  String get studioErrPriceMissing;

  /// No description provided for @studioErrPricePositive.
  ///
  /// In en, this message translates to:
  /// **'The price must be more than 0.'**
  String get studioErrPricePositive;

  /// No description provided for @studioErrPriceCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the price.'**
  String get studioErrPriceCheck;

  /// No description provided for @studioErrCannotSave.
  ///
  /// In en, this message translates to:
  /// **'This agent cannot be saved.'**
  String get studioErrCannotSave;

  /// No description provided for @playgroundDemoLead.
  ///
  /// In en, this message translates to:
  /// **'Demo test runner: no model answers yet.'**
  String get playgroundDemoLead;

  /// No description provided for @playgroundLiveLead.
  ///
  /// In en, this message translates to:
  /// **'Test runs are free and limited per day.'**
  String get playgroundLiveLead;

  /// No description provided for @playgroundProviderToken.
  ///
  /// In en, this message translates to:
  /// **'Provider token'**
  String get playgroundProviderToken;

  /// No description provided for @playgroundProviderTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Stored for your test runs'**
  String get playgroundProviderTokenHint;

  /// No description provided for @playgroundAccountId.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare account id'**
  String get playgroundAccountId;

  /// No description provided for @playgroundRunning.
  ///
  /// In en, this message translates to:
  /// **'Running… It stops at the runtime timeout.'**
  String get playgroundRunning;

  /// No description provided for @playgroundFailed.
  ///
  /// In en, this message translates to:
  /// **'The test run failed'**
  String get playgroundFailed;

  /// No description provided for @playgroundTryLater.
  ///
  /// In en, this message translates to:
  /// **'Try again in a moment.'**
  String get playgroundTryLater;

  /// No description provided for @playgroundQuota.
  ///
  /// In en, this message translates to:
  /// **'You used today\'s test runs.'**
  String get playgroundQuota;

  /// No description provided for @playgroundSampleTask.
  ///
  /// In en, this message translates to:
  /// **'A sample task for your agent'**
  String get playgroundSampleTask;

  /// No description provided for @playgroundTooLong.
  ///
  /// In en, this message translates to:
  /// **'This agent accepts up to {max} characters.'**
  String playgroundTooLong(int max);

  /// No description provided for @playgroundRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get playgroundRun;

  /// No description provided for @playgroundRunningButton.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get playgroundRunningButton;

  /// No description provided for @playgroundResultLabel.
  ///
  /// In en, this message translates to:
  /// **'Test run: not paid, nothing on chain'**
  String get playgroundResultLabel;

  /// No description provided for @playgroundRunsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 run left today} other{{count} runs left today}}'**
  String playgroundRunsLeft(int count);

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @myAgentsDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get myAgentsDrafts;

  /// No description provided for @myAgentsDeployingOrFailed.
  ///
  /// In en, this message translates to:
  /// **'Deploying or failed'**
  String get myAgentsDeployingOrFailed;

  /// No description provided for @myAgentsLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get myAgentsLive;

  /// No description provided for @myAgentsDraftRevision.
  ///
  /// In en, this message translates to:
  /// **'Draft · revision {revision}'**
  String myAgentsDraftRevision(int revision);

  /// No description provided for @myAgentsDeploying.
  ///
  /// In en, this message translates to:
  /// **'Deploying'**
  String get myAgentsDeploying;

  /// No description provided for @myAgentsDeployFailed.
  ///
  /// In en, this message translates to:
  /// **'Deploy failed'**
  String get myAgentsDeployFailed;

  /// No description provided for @myAgentsLiveVersion.
  ///
  /// In en, this message translates to:
  /// **'Live · version {version}'**
  String myAgentsLiveVersion(int version);

  /// No description provided for @myAgentsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get myAgentsContinue;

  /// No description provided for @myAgentsResume.
  ///
  /// In en, this message translates to:
  /// **'Resume deploy'**
  String get myAgentsResume;

  /// No description provided for @myAgentsResumeStep.
  ///
  /// In en, this message translates to:
  /// **'Resume deploy (step {step})'**
  String myAgentsResumeStep(int step);

  /// No description provided for @myAgentsView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get myAgentsView;

  /// No description provided for @myAgentsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get myAgentsEdit;

  /// No description provided for @myAgentsServerNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'The server did not respond. Try again.'**
  String get myAgentsServerNoAnswer;

  /// No description provided for @hireDemoOnly.
  ///
  /// In en, this message translates to:
  /// **'Demo only: signing here does not move funds. Escrow payments arrive once wallet sign-in is live on the server.'**
  String get hireDemoOnly;

  /// No description provided for @hireTaskLabel.
  ///
  /// In en, this message translates to:
  /// **'What should the agent do?'**
  String get hireTaskLabel;

  /// No description provided for @hireTaskHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the task for this hire'**
  String get hireTaskHint;

  /// No description provided for @hireAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get hireAsset;

  /// No description provided for @hireNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get hireNetwork;

  /// No description provided for @hireDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get hireDestination;

  /// No description provided for @hireEscrow.
  ///
  /// In en, this message translates to:
  /// **'Escrow'**
  String get hireEscrow;

  /// No description provided for @hireNetworkFee.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get hireNetworkFee;

  /// No description provided for @hireSigning.
  ///
  /// In en, this message translates to:
  /// **'Signing…'**
  String get hireSigning;

  /// No description provided for @hireConfirmSign.
  ///
  /// In en, this message translates to:
  /// **'Confirm & sign'**
  String get hireConfirmSign;

  /// No description provided for @hireDemoSignature.
  ///
  /// In en, this message translates to:
  /// **'Demo signature only'**
  String get hireDemoSignature;

  /// No description provided for @hireDemoDone.
  ///
  /// In en, this message translates to:
  /// **'No payment was sent and no hire was created. Real escrow payments arrive once wallet sign-in is live on the server.'**
  String get hireDemoDone;

  /// No description provided for @hireAgentLabel.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get hireAgentLabel;

  /// No description provided for @hirePaymentHeld.
  ///
  /// In en, this message translates to:
  /// **'Payment held by the escrow'**
  String get hirePaymentHeld;

  /// No description provided for @hirePaymentConfirming.
  ///
  /// In en, this message translates to:
  /// **'Payment sent, confirming on Stellar…'**
  String get hirePaymentConfirming;

  /// No description provided for @hirePaymentHeldBody.
  ///
  /// In en, this message translates to:
  /// **'Your USDC is held by the escrow contract until you approve the result. The agent starts working.'**
  String get hirePaymentHeldBody;

  /// No description provided for @hirePaymentConfirmingBody.
  ///
  /// In en, this message translates to:
  /// **'puls3 is confirming the transaction and checking that it matches this hire. You can follow it on StellarExpert.'**
  String get hirePaymentConfirmingBody;

  /// No description provided for @hireTxHash.
  ///
  /// In en, this message translates to:
  /// **'Tx hash'**
  String get hireTxHash;

  /// No description provided for @hireViewHire.
  ///
  /// In en, this message translates to:
  /// **'View hire'**
  String get hireViewHire;

  /// No description provided for @hireViewExplorer.
  ///
  /// In en, this message translates to:
  /// **'View on StellarExpert'**
  String get hireViewExplorer;

  /// No description provided for @hirePaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get hirePaymentFailed;

  /// No description provided for @hirePaymentIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be completed'**
  String get hirePaymentIncomplete;

  /// No description provided for @hireEscrowProtection.
  ///
  /// In en, this message translates to:
  /// **'Escrow protection: your USDC stays in the escrow contract. The agent is paid only when you approve the result, and you get a refund if it never delivers.'**
  String get hireEscrowProtection;

  /// No description provided for @studioDraftLoadError.
  ///
  /// In en, this message translates to:
  /// **'The draft could not be loaded. Try again.'**
  String get studioDraftLoadError;

  /// No description provided for @playgroundUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The test runner is unavailable.'**
  String get playgroundUnavailable;

  /// No description provided for @playgroundQuotaReset.
  ///
  /// In en, this message translates to:
  /// **'You used today\'s test runs. They reset at {time}.'**
  String playgroundQuotaReset(String time);

  /// No description provided for @playgroundOutputCopied.
  ///
  /// In en, this message translates to:
  /// **'Output copied'**
  String get playgroundOutputCopied;

  /// No description provided for @marketSortAgents.
  ///
  /// In en, this message translates to:
  /// **'Sort agents'**
  String get marketSortAgents;

  /// No description provided for @hireIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Hire'**
  String get hireIdLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
          case 'PT':
            return AppLocalizationsPtPt();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
