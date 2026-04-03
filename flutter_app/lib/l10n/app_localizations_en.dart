// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'OpenClaw';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get done => 'Done';

  @override
  String get save => 'Save';

  @override
  String get remove => 'Remove';

  @override
  String get install => 'Install';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get copy => 'Copy';

  @override
  String get paste => 'Paste';

  @override
  String get openUrl => 'Open URL';

  @override
  String get screenshot => 'Screenshot';

  @override
  String get restart => 'Restart';

  @override
  String get later => 'Later';

  @override
  String get download => 'Download';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get noUrlFound => 'No URL found in selection';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get openLink => 'Open Link';

  @override
  String get aiGatewayForAndroid => 'AI Gateway for Android';

  @override
  String get checkingSetup => 'Checking setup status...';

  @override
  String get repairingBypass => 'Repairing bionic bypass...';

  @override
  String get reinstallingNode => 'Reinstalling Node.js...';

  @override
  String get reinstallingOpenClaw => 'Reinstalling OpenClaw...';

  @override
  String get quickActions => 'QUICK ACTIONS';

  @override
  String get terminal => 'Terminal';

  @override
  String get terminalSubtitle => 'Open Ubuntu shell with OpenClaw';

  @override
  String get webDashboard => 'Web Dashboard';

  @override
  String get webDashboardSubtitle => 'Open OpenClaw dashboard in browser';

  @override
  String get startGatewayFirst => 'Start gateway first';

  @override
  String get onboarding => 'Onboarding';

  @override
  String get onboardingSubtitle => 'Configure API keys and binding';

  @override
  String get configure => 'Configure';

  @override
  String get configureSubtitle => 'Manage gateway settings';

  @override
  String get aiProviders => 'AI Providers';

  @override
  String get aiProvidersSubtitle => 'Configure models and API keys';

  @override
  String get packages => 'Packages';

  @override
  String get packagesSubtitle => 'Install optional tools (Go, Homebrew, SSH)';

  @override
  String get sshAccess => 'SSH Access';

  @override
  String get sshAccessSubtitle => 'Remote terminal access via SSH';

  @override
  String get logs => 'Logs';

  @override
  String get logsSubtitle => 'View gateway output and errors';

  @override
  String get snapshot => 'Snapshot';

  @override
  String get snapshotSubtitle => 'Backup or restore your config';

  @override
  String get node => 'Node';

  @override
  String get nodeConnected => 'Connected to gateway';

  @override
  String get nodeCapabilities => 'Device capabilities for AI';

  @override
  String get dashboardUrlCopied => 'Dashboard URL copied';

  @override
  String get copyDashboardUrl => 'Copy dashboard URL';

  @override
  String get cliProxy => 'CLIProxy Manager';

  @override
  String get cliProxySubtitle => 'Manage free AI account proxy';

  @override
  String get gateway => 'Gateway';

  @override
  String get startGateway => 'Start Gateway';

  @override
  String get stopGateway => 'Stop Gateway';

  @override
  String get viewLogs => 'View Logs';

  @override
  String get urlCopied => 'URL copied to clipboard';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get openDashboard => 'Open dashboard';

  @override
  String get gatewayRunning => 'Running';

  @override
  String get gatewayStarting => 'Starting';

  @override
  String get gatewayError => 'Error';

  @override
  String get gatewayStopped => 'Stopped';

  @override
  String get enableNode => 'Enable Node';

  @override
  String get disableNode => 'Disable Node';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get nodePaired => 'Paired';

  @override
  String get nodeConnecting => 'Connecting';

  @override
  String get nodeDisconnected => 'Disconnected';

  @override
  String get nodeDisabled => 'Disabled';

  @override
  String get nodeConfigure => 'Configure';

  @override
  String get settings => 'Settings';

  @override
  String get general => 'GENERAL';

  @override
  String get autoStartGateway => 'Auto-start gateway';

  @override
  String get autoStartSubtitle => 'Start the gateway when the app opens';

  @override
  String get batteryOptimization => 'Battery Optimization';

  @override
  String get batteryOptimized => 'Optimized (may kill background sessions)';

  @override
  String get batteryUnrestricted => 'Unrestricted (recommended)';

  @override
  String get setupStorage => 'Setup Storage';

  @override
  String get storageGranted =>
      'Granted — proot can access /sdcard. Revoke if not needed.';

  @override
  String get storageNotGranted => 'Allow access to shared storage';

  @override
  String get nodeSection => 'NODE';

  @override
  String get enableNodeTitle => 'Enable Node';

  @override
  String get enableNodeSubtitle => 'Provide device capabilities to the gateway';

  @override
  String get nodeConfiguration => 'Node Configuration';

  @override
  String get nodeConfigSubtitle => 'Connection, pairing, and capabilities';

  @override
  String get systemInfo => 'SYSTEM INFO';

  @override
  String get architecture => 'Architecture';

  @override
  String get prootPath => 'PRoot path';

  @override
  String get rootfs => 'Rootfs';

  @override
  String get installed => 'Installed';

  @override
  String get notInstalled => 'Not installed';

  @override
  String get maintenance => 'MAINTENANCE';

  @override
  String get exportSnapshot => 'Export Snapshot';

  @override
  String get exportSnapshotSubtitle => 'Backup config to Downloads';

  @override
  String get importSnapshot => 'Import Snapshot';

  @override
  String get importSnapshotSubtitle => 'Restore config from backup';

  @override
  String get rerunSetup => 'Re-run setup';

  @override
  String get rerunSetupSubtitle => 'Reinstall or repair the environment';

  @override
  String get about => 'ABOUT';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get checkUpdatesSubtitle => 'Check GitHub for a newer release';

  @override
  String get developer => 'Developer';

  @override
  String get github => 'GitHub';

  @override
  String get contact => 'Contact';

  @override
  String get license => 'License';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get currentVersion => 'Current';

  @override
  String get latestVersion => 'Latest';

  @override
  String get alreadyLatest => 'You\'re on the latest version';

  @override
  String get checkUpdateFailed => 'Could not check for updates';

  @override
  String get snapshotSaved => 'Snapshot saved to';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get noSnapshotFound => 'No snapshot found at';

  @override
  String get snapshotRestored =>
      'Snapshot restored successfully. Restart the gateway to apply.';

  @override
  String get importFailed => 'Import failed';

  @override
  String get setupOpenClaw => 'Setup OpenClaw';

  @override
  String get setupRunning =>
      'Setting up the environment. This may take several minutes.';

  @override
  String get setupDescription =>
      'This will download Ubuntu, Node.js, and OpenClaw into a self-contained environment.';

  @override
  String get downloadRootfs => 'Download Ubuntu rootfs';

  @override
  String get extractRootfs => 'Extract rootfs';

  @override
  String get installNode => 'Install Node.js';

  @override
  String get installOpenClaw => 'Install OpenClaw';

  @override
  String get configureBionicBypass => 'Configure Bionic Bypass';

  @override
  String get setupComplete => 'Setup complete!';

  @override
  String get configureApiKeys => 'Configure API Keys';

  @override
  String get beginSetup => 'Begin Setup';

  @override
  String get retrySetup => 'Retry Setup';

  @override
  String get storageRequired =>
      'Requires ~500MB of storage and an internet connection';

  @override
  String get optionalPackages => 'OPTIONAL PACKAGES';

  @override
  String get gatewayLogs => 'Gateway Logs';

  @override
  String get filterLogs => 'Filter logs...';

  @override
  String get noLogsYet => 'No logs yet. Start the gateway.';

  @override
  String get noMatchingLogs => 'No matching logs.';

  @override
  String get copyAllLogs => 'Copy all logs';

  @override
  String get autoScrollOn => 'Auto-scroll on';

  @override
  String get autoScrollOff => 'Auto-scroll off';

  @override
  String get activeModel => 'Active Model';

  @override
  String get selectProvider =>
      'Select a provider to configure its API key and model.';

  @override
  String get active => 'Active';

  @override
  String get configured => 'Configured';

  @override
  String get apiKey => 'API Key';

  @override
  String get model => 'Model';

  @override
  String get customModel => 'Custom...';

  @override
  String get customModelHint => 'e.g. meta/llama-3.3-70b-instruct';

  @override
  String get customModelLabel => 'Custom model name';

  @override
  String get saveAndActivate => 'Save & Activate';

  @override
  String get removeConfiguration => 'Remove Configuration';

  @override
  String get apiKeyEmpty => 'API key cannot be empty';

  @override
  String get modelEmpty => 'Model name cannot be empty';

  @override
  String get configuredAndActivated => 'configured and activated';

  @override
  String get saveFailed => 'Failed to save';

  @override
  String get removeFailed => 'Failed to remove';

  @override
  String get removeProvider => 'Remove';

  @override
  String get removeProviderContent =>
      'This will delete the API key and deactivate the model.';

  @override
  String get startingTerminal => 'Starting terminal...';

  @override
  String get failedToStartTerminal => 'Failed to start terminal';

  @override
  String get openClawOnboarding => 'OpenClaw Onboarding';

  @override
  String get startingOnboarding => 'Starting onboarding...';

  @override
  String get failedToStartOnboarding => 'Failed to start onboarding';

  @override
  String get goToDashboard => 'Go to Dashboard';

  @override
  String get cliProxyManagement => 'CLIProxy Management';

  @override
  String get cliProxyNotRunning => 'CLIProxy service is not running';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get refresh => 'Refresh';

  @override
  String get reconnectProxy => 'Reconnect';

  @override
  String get installedBadge => 'Installed';
}
