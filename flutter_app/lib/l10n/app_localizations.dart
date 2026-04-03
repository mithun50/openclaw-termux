import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'OpenClaw'**
  String get appName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @openUrl.
  ///
  /// In en, this message translates to:
  /// **'Open URL'**
  String get openUrl;

  /// No description provided for @screenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get screenshot;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @noUrlFound.
  ///
  /// In en, this message translates to:
  /// **'No URL found in selection'**
  String get noUrlFound;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open Link'**
  String get openLink;

  /// No description provided for @aiGatewayForAndroid.
  ///
  /// In en, this message translates to:
  /// **'AI Gateway for Android'**
  String get aiGatewayForAndroid;

  /// No description provided for @checkingSetup.
  ///
  /// In en, this message translates to:
  /// **'Checking setup status...'**
  String get checkingSetup;

  /// No description provided for @repairingBypass.
  ///
  /// In en, this message translates to:
  /// **'Repairing bionic bypass...'**
  String get repairingBypass;

  /// No description provided for @reinstallingNode.
  ///
  /// In en, this message translates to:
  /// **'Reinstalling Node.js...'**
  String get reinstallingNode;

  /// No description provided for @reinstallingOpenClaw.
  ///
  /// In en, this message translates to:
  /// **'Reinstalling OpenClaw...'**
  String get reinstallingOpenClaw;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'QUICK ACTIONS'**
  String get quickActions;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @terminalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open Ubuntu shell with OpenClaw'**
  String get terminalSubtitle;

  /// No description provided for @webDashboard.
  ///
  /// In en, this message translates to:
  /// **'Web Dashboard'**
  String get webDashboard;

  /// No description provided for @webDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open OpenClaw dashboard in browser'**
  String get webDashboardSubtitle;

  /// No description provided for @startGatewayFirst.
  ///
  /// In en, this message translates to:
  /// **'Start gateway first'**
  String get startGatewayFirst;

  /// No description provided for @onboarding.
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get onboarding;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure API keys and binding'**
  String get onboardingSubtitle;

  /// No description provided for @configure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get configure;

  /// No description provided for @configureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage gateway settings'**
  String get configureSubtitle;

  /// No description provided for @aiProviders.
  ///
  /// In en, this message translates to:
  /// **'AI Providers'**
  String get aiProviders;

  /// No description provided for @aiProvidersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure models and API keys'**
  String get aiProvidersSubtitle;

  /// No description provided for @packages.
  ///
  /// In en, this message translates to:
  /// **'Packages'**
  String get packages;

  /// No description provided for @packagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Install optional tools (Go, Homebrew, SSH)'**
  String get packagesSubtitle;

  /// No description provided for @sshAccess.
  ///
  /// In en, this message translates to:
  /// **'SSH Access'**
  String get sshAccess;

  /// No description provided for @sshAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remote terminal access via SSH'**
  String get sshAccessSubtitle;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @logsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View gateway output and errors'**
  String get logsSubtitle;

  /// No description provided for @snapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot'**
  String get snapshot;

  /// No description provided for @snapshotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup or restore your config'**
  String get snapshotSubtitle;

  /// No description provided for @node.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get node;

  /// No description provided for @nodeConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to gateway'**
  String get nodeConnected;

  /// No description provided for @nodeCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Device capabilities for AI'**
  String get nodeCapabilities;

  /// No description provided for @dashboardUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Dashboard URL copied'**
  String get dashboardUrlCopied;

  /// No description provided for @copyDashboardUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy dashboard URL'**
  String get copyDashboardUrl;

  /// No description provided for @cliProxy.
  ///
  /// In en, this message translates to:
  /// **'CLIProxy Manager'**
  String get cliProxy;

  /// No description provided for @cliProxySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage free AI account proxy'**
  String get cliProxySubtitle;

  /// No description provided for @gateway.
  ///
  /// In en, this message translates to:
  /// **'Gateway'**
  String get gateway;

  /// No description provided for @startGateway.
  ///
  /// In en, this message translates to:
  /// **'Start Gateway'**
  String get startGateway;

  /// No description provided for @stopGateway.
  ///
  /// In en, this message translates to:
  /// **'Stop Gateway'**
  String get stopGateway;

  /// No description provided for @viewLogs.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get viewLogs;

  /// No description provided for @urlCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied to clipboard'**
  String get urlCopied;

  /// No description provided for @copyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get copyUrl;

  /// No description provided for @openDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open dashboard'**
  String get openDashboard;

  /// No description provided for @gatewayRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get gatewayRunning;

  /// No description provided for @gatewayStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get gatewayStarting;

  /// No description provided for @gatewayError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get gatewayError;

  /// No description provided for @gatewayStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get gatewayStopped;

  /// No description provided for @enableNode.
  ///
  /// In en, this message translates to:
  /// **'Enable Node'**
  String get enableNode;

  /// No description provided for @disableNode.
  ///
  /// In en, this message translates to:
  /// **'Disable Node'**
  String get disableNode;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @nodePaired.
  ///
  /// In en, this message translates to:
  /// **'Paired'**
  String get nodePaired;

  /// No description provided for @nodeConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get nodeConnecting;

  /// No description provided for @nodeDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get nodeDisconnected;

  /// No description provided for @nodeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get nodeDisabled;

  /// No description provided for @nodeConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get nodeConfigure;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get general;

  /// No description provided for @autoStartGateway.
  ///
  /// In en, this message translates to:
  /// **'Auto-start gateway'**
  String get autoStartGateway;

  /// No description provided for @autoStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start the gateway when the app opens'**
  String get autoStartSubtitle;

  /// No description provided for @batteryOptimization.
  ///
  /// In en, this message translates to:
  /// **'Battery Optimization'**
  String get batteryOptimization;

  /// No description provided for @batteryOptimized.
  ///
  /// In en, this message translates to:
  /// **'Optimized (may kill background sessions)'**
  String get batteryOptimized;

  /// No description provided for @batteryUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'Unrestricted (recommended)'**
  String get batteryUnrestricted;

  /// No description provided for @setupStorage.
  ///
  /// In en, this message translates to:
  /// **'Setup Storage'**
  String get setupStorage;

  /// No description provided for @storageGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted — proot can access /sdcard. Revoke if not needed.'**
  String get storageGranted;

  /// No description provided for @storageNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Allow access to shared storage'**
  String get storageNotGranted;

  /// No description provided for @nodeSection.
  ///
  /// In en, this message translates to:
  /// **'NODE'**
  String get nodeSection;

  /// No description provided for @enableNodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Node'**
  String get enableNodeTitle;

  /// No description provided for @enableNodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Provide device capabilities to the gateway'**
  String get enableNodeSubtitle;

  /// No description provided for @nodeConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Node Configuration'**
  String get nodeConfiguration;

  /// No description provided for @nodeConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connection, pairing, and capabilities'**
  String get nodeConfigSubtitle;

  /// No description provided for @systemInfo.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM INFO'**
  String get systemInfo;

  /// No description provided for @architecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get architecture;

  /// No description provided for @prootPath.
  ///
  /// In en, this message translates to:
  /// **'PRoot path'**
  String get prootPath;

  /// No description provided for @rootfs.
  ///
  /// In en, this message translates to:
  /// **'Rootfs'**
  String get rootfs;

  /// No description provided for @installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installed;

  /// No description provided for @notInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get notInstalled;

  /// No description provided for @maintenance.
  ///
  /// In en, this message translates to:
  /// **'MAINTENANCE'**
  String get maintenance;

  /// No description provided for @exportSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Export Snapshot'**
  String get exportSnapshot;

  /// No description provided for @exportSnapshotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup config to Downloads'**
  String get exportSnapshotSubtitle;

  /// No description provided for @importSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Import Snapshot'**
  String get importSnapshot;

  /// No description provided for @importSnapshotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore config from backup'**
  String get importSnapshotSubtitle;

  /// No description provided for @rerunSetup.
  ///
  /// In en, this message translates to:
  /// **'Re-run setup'**
  String get rerunSetup;

  /// No description provided for @rerunSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reinstall or repair the environment'**
  String get rerunSetupSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get about;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @checkUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check GitHub for a newer release'**
  String get checkUpdatesSubtitle;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @github.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get github;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentVersion;

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latestVersion;

  /// No description provided for @alreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version'**
  String get alreadyLatest;

  /// No description provided for @checkUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates'**
  String get checkUpdateFailed;

  /// No description provided for @snapshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Snapshot saved to'**
  String get snapshotSaved;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @noSnapshotFound.
  ///
  /// In en, this message translates to:
  /// **'No snapshot found at'**
  String get noSnapshotFound;

  /// No description provided for @snapshotRestored.
  ///
  /// In en, this message translates to:
  /// **'Snapshot restored successfully. Restart the gateway to apply.'**
  String get snapshotRestored;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// No description provided for @setupOpenClaw.
  ///
  /// In en, this message translates to:
  /// **'Setup OpenClaw'**
  String get setupOpenClaw;

  /// No description provided for @setupRunning.
  ///
  /// In en, this message translates to:
  /// **'Setting up the environment. This may take several minutes.'**
  String get setupRunning;

  /// No description provided for @setupDescription.
  ///
  /// In en, this message translates to:
  /// **'This will download Ubuntu, Node.js, and OpenClaw into a self-contained environment.'**
  String get setupDescription;

  /// No description provided for @downloadRootfs.
  ///
  /// In en, this message translates to:
  /// **'Download Ubuntu rootfs'**
  String get downloadRootfs;

  /// No description provided for @extractRootfs.
  ///
  /// In en, this message translates to:
  /// **'Extract rootfs'**
  String get extractRootfs;

  /// No description provided for @installNode.
  ///
  /// In en, this message translates to:
  /// **'Install Node.js'**
  String get installNode;

  /// No description provided for @installOpenClaw.
  ///
  /// In en, this message translates to:
  /// **'Install OpenClaw'**
  String get installOpenClaw;

  /// No description provided for @configureBionicBypass.
  ///
  /// In en, this message translates to:
  /// **'Configure Bionic Bypass'**
  String get configureBionicBypass;

  /// No description provided for @setupComplete.
  ///
  /// In en, this message translates to:
  /// **'Setup complete!'**
  String get setupComplete;

  /// No description provided for @configureApiKeys.
  ///
  /// In en, this message translates to:
  /// **'Configure API Keys'**
  String get configureApiKeys;

  /// No description provided for @beginSetup.
  ///
  /// In en, this message translates to:
  /// **'Begin Setup'**
  String get beginSetup;

  /// No description provided for @retrySetup.
  ///
  /// In en, this message translates to:
  /// **'Retry Setup'**
  String get retrySetup;

  /// No description provided for @storageRequired.
  ///
  /// In en, this message translates to:
  /// **'Requires ~500MB of storage and an internet connection'**
  String get storageRequired;

  /// No description provided for @optionalPackages.
  ///
  /// In en, this message translates to:
  /// **'OPTIONAL PACKAGES'**
  String get optionalPackages;

  /// No description provided for @gatewayLogs.
  ///
  /// In en, this message translates to:
  /// **'Gateway Logs'**
  String get gatewayLogs;

  /// No description provided for @filterLogs.
  ///
  /// In en, this message translates to:
  /// **'Filter logs...'**
  String get filterLogs;

  /// No description provided for @noLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No logs yet. Start the gateway.'**
  String get noLogsYet;

  /// No description provided for @noMatchingLogs.
  ///
  /// In en, this message translates to:
  /// **'No matching logs.'**
  String get noMatchingLogs;

  /// No description provided for @copyAllLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy all logs'**
  String get copyAllLogs;

  /// No description provided for @autoScrollOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll on'**
  String get autoScrollOn;

  /// No description provided for @autoScrollOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll off'**
  String get autoScrollOff;

  /// No description provided for @activeModel.
  ///
  /// In en, this message translates to:
  /// **'Active Model'**
  String get activeModel;

  /// No description provided for @selectProvider.
  ///
  /// In en, this message translates to:
  /// **'Select a provider to configure its API key and model.'**
  String get selectProvider;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @configured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get configured;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @customModel.
  ///
  /// In en, this message translates to:
  /// **'Custom...'**
  String get customModel;

  /// No description provided for @customModelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. meta/llama-3.3-70b-instruct'**
  String get customModelHint;

  /// No description provided for @customModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom model name'**
  String get customModelLabel;

  /// No description provided for @saveAndActivate.
  ///
  /// In en, this message translates to:
  /// **'Save & Activate'**
  String get saveAndActivate;

  /// No description provided for @removeConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Remove Configuration'**
  String get removeConfiguration;

  /// No description provided for @apiKeyEmpty.
  ///
  /// In en, this message translates to:
  /// **'API key cannot be empty'**
  String get apiKeyEmpty;

  /// No description provided for @modelEmpty.
  ///
  /// In en, this message translates to:
  /// **'Model name cannot be empty'**
  String get modelEmpty;

  /// No description provided for @configuredAndActivated.
  ///
  /// In en, this message translates to:
  /// **'configured and activated'**
  String get configuredAndActivated;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get saveFailed;

  /// No description provided for @removeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove'**
  String get removeFailed;

  /// No description provided for @removeProvider.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeProvider;

  /// No description provided for @removeProviderContent.
  ///
  /// In en, this message translates to:
  /// **'This will delete the API key and deactivate the model.'**
  String get removeProviderContent;

  /// No description provided for @startingTerminal.
  ///
  /// In en, this message translates to:
  /// **'Starting terminal...'**
  String get startingTerminal;

  /// No description provided for @failedToStartTerminal.
  ///
  /// In en, this message translates to:
  /// **'Failed to start terminal'**
  String get failedToStartTerminal;

  /// No description provided for @openClawOnboarding.
  ///
  /// In en, this message translates to:
  /// **'OpenClaw Onboarding'**
  String get openClawOnboarding;

  /// No description provided for @startingOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Starting onboarding...'**
  String get startingOnboarding;

  /// No description provided for @failedToStartOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Failed to start onboarding'**
  String get failedToStartOnboarding;

  /// No description provided for @goToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to Dashboard'**
  String get goToDashboard;

  /// No description provided for @cliProxyManagement.
  ///
  /// In en, this message translates to:
  /// **'CLIProxy Management'**
  String get cliProxyManagement;

  /// No description provided for @cliProxyNotRunning.
  ///
  /// In en, this message translates to:
  /// **'CLIProxy service is not running'**
  String get cliProxyNotRunning;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @reconnectProxy.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnectProxy;

  /// No description provided for @installedBadge.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installedBadge;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
