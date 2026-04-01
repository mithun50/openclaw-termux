import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../providers/node_provider.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../services/update_service.dart';
import '../utils/responsive.dart';
import 'node_screen.dart';
import 'setup_wizard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();
  bool _autoStart = false;
  bool _nodeEnabled = false;
  bool _batteryOptimized = true;
  String _arch = '';
  String _prootPath = '';
  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _goInstalled = false;
  bool _brewInstalled = false;
  bool _sshInstalled = false;
  bool _storageGranted = false;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _prefs.init();
    _autoStart = _prefs.autoStartGateway;
    _nodeEnabled = _prefs.nodeEnabled;

    try {
      final arch = await NativeBridge.getArch();
      final prootPath = await NativeBridge.getProotPath();
      final status = await NativeBridge.getBootstrapStatus();
      final batteryOptimized = await NativeBridge.isBatteryOptimized();

      final storageGranted = await NativeBridge.hasStoragePermission();

      // Check optional package statuses
      final filesDir = await NativeBridge.getFilesDir();
      final rootfs = '$filesDir/rootfs/ubuntu';
      final goInstalled = File('$rootfs/usr/bin/go').existsSync();
      final brewInstalled =
          File('$rootfs/home/linuxbrew/.linuxbrew/bin/brew').existsSync();
      final sshInstalled = File('$rootfs/usr/bin/ssh').existsSync();

      setState(() {
        _batteryOptimized = batteryOptimized;
        _storageGranted = storageGranted;
        _arch = arch;
        _prootPath = prootPath;
        _status = status;
        _goInstalled = goInstalled;
        _brewInstalled = brewInstalled;
        _sshInstalled = sshInstalled;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.settings)),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Responsive.constrain(
              ListView(
                children: [
                  _sectionHeader(theme, AppStrings.general.toUpperCase()),
                  SwitchListTile(
                    title: Text(AppStrings.autoStartGateway),
                    subtitle: Text(AppStrings.autoStartSubtitle),
                    value: _autoStart,
                    onChanged: (value) {
                      setState(() => _autoStart = value);
                      _prefs.autoStartGateway = value;
                    },
                  ),
                  ListTile(
                    title: Text(AppStrings.batteryOptimization),
                    subtitle: Text(_batteryOptimized
                        ? AppStrings.batteryOptimized
                        : AppStrings.batteryUnrestricted),
                    leading: const Icon(Icons.battery_alert),
                    trailing: _batteryOptimized
                        ? const Icon(Icons.warning, color: AppColors.statusAmber)
                        : const Icon(Icons.check_circle, color: AppColors.statusGreen),
                    onTap: () async {
                      await NativeBridge.requestBatteryOptimization();
                      final optimized = await NativeBridge.isBatteryOptimized();
                      setState(() => _batteryOptimized = optimized);
                    },
                  ),
                  ListTile(
                    title: Text(AppStrings.setupStorage),
                    subtitle: Text(_storageGranted
                        ? AppStrings.storageGranted
                        : AppStrings.storageNotGranted),
                    leading: const Icon(Icons.sd_storage),
                    trailing: _storageGranted
                        ? const Icon(Icons.warning_amber, color: AppColors.statusAmber)
                        : const Icon(Icons.warning, color: AppColors.statusAmber),
                    onTap: () async {
                      await NativeBridge.requestStoragePermission();
                      final granted = await NativeBridge.hasStoragePermission();
                      setState(() => _storageGranted = granted);
                    },
                  ),
                  const Divider(),
                  _sectionHeader(theme, AppStrings.nodeSection.toUpperCase()),
                  SwitchListTile(
                    title: Text(AppStrings.enableNodeTitle),
                    subtitle: Text(AppStrings.enableNodeSubtitle),
                    value: _nodeEnabled,
                    onChanged: (value) {
                      setState(() => _nodeEnabled = value);
                      _prefs.nodeEnabled = value;
                      final nodeProvider = context.read<NodeProvider>();
                      if (value) {
                        nodeProvider.enable();
                      } else {
                        nodeProvider.disable();
                      }
                    },
                  ),
                  ListTile(
                    title: Text(AppStrings.nodeConfiguration),
                    subtitle: Text(AppStrings.nodeConfigSubtitle),
                    leading: const Icon(Icons.devices),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NodeScreen()),
                    ),
                  ),
                  const Divider(),
                  _sectionHeader(theme, AppStrings.systemInfo.toUpperCase()),
                  ListTile(
                    title: Text(AppStrings.architecture),
                    subtitle: Text(_arch),
                    leading: const Icon(Icons.memory),
                  ),
                  ListTile(
                    title: Text(AppStrings.prootPath),
                    subtitle: Text(_prootPath),
                    leading: const Icon(Icons.folder),
                  ),
                  ListTile(
                    title: Text(AppStrings.rootfs),
                    subtitle: Text(_status['rootfsExists'] == true
                        ? AppStrings.installed
                        : AppStrings.notInstalled),
                    leading: const Icon(Icons.storage),
                  ),
                  ListTile(
                    title: const Text('Node.js'),
                    subtitle: Text(_status['nodeInstalled'] == true
                        ? AppStrings.installed
                        : AppStrings.notInstalled),
                    leading: const Icon(Icons.code),
                  ),
                  ListTile(
                    title: const Text('OpenClaw'),
                    subtitle: Text(_status['openclawInstalled'] == true
                        ? AppStrings.installed
                        : AppStrings.notInstalled),
                    leading: const Icon(Icons.cloud),
                  ),
                  ListTile(
                    title: const Text('Go (Golang)'),
                    subtitle: Text(_goInstalled ? AppStrings.installed : AppStrings.notInstalled),
                    leading: const Icon(Icons.integration_instructions),
                  ),
                  ListTile(
                    title: const Text('Homebrew'),
                    subtitle: Text(_brewInstalled ? AppStrings.installed : AppStrings.notInstalled),
                    leading: const Icon(Icons.science),
                  ),
                  ListTile(
                    title: const Text('OpenSSH'),
                    subtitle: Text(_sshInstalled ? AppStrings.installed : AppStrings.notInstalled),
                    leading: const Icon(Icons.vpn_key),
                  ),
                  const Divider(),
                  _sectionHeader(theme, AppStrings.maintenance.toUpperCase()),
                  ListTile(
                    title: Text(AppStrings.exportSnapshot),
                    subtitle: Text(AppStrings.exportSnapshotSubtitle),
                    leading: const Icon(Icons.upload_file),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exportSnapshot,
                  ),
                  ListTile(
                    title: Text(AppStrings.importSnapshot),
                    subtitle: Text(AppStrings.importSnapshotSubtitle),
                    leading: const Icon(Icons.download),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _importSnapshot,
                  ),
                  ListTile(
                    title: Text(AppStrings.rerunSetup),
                    subtitle: Text(AppStrings.rerunSetupSubtitle),
                    leading: const Icon(Icons.build),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const SetupWizardScreen(),
                      ),
                    ),
                  ),
                  const Divider(),
                  _sectionHeader(theme, AppStrings.about.toUpperCase()),
                  const ListTile(
                    title: Text('OpenClaw'),
                    subtitle: Text(
                      'AI Gateway for Android\nVersion ${AppConstants.version}',
                    ),
                    leading: Icon(Icons.info_outline),
                    isThreeLine: true,
                  ),
                  ListTile(
                    title: Text(AppStrings.checkForUpdates),
                    subtitle: Text(AppStrings.checkUpdatesSubtitle),
                    leading: _checkingUpdate
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update),
                    onTap: _checkingUpdate ? null : _checkForUpdates,
                  ),
                  ListTile(
                    title: Text(AppStrings.developer),
                    subtitle: const Text(AppConstants.authorName),
                    leading: const Icon(Icons.person),
                  ),
                  ListTile(
                    title: Text(AppStrings.github),
                    subtitle: const Text('mithun50/openclaw-termux'),
                    leading: const Icon(Icons.code),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => launchUrl(
                      Uri.parse(AppConstants.githubUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  ListTile(
                    title: Text(AppStrings.contact),
                    subtitle: const Text(AppConstants.authorEmail),
                    leading: const Icon(Icons.email),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => launchUrl(
                      Uri.parse('mailto:${AppConstants.authorEmail}'),
                    ),
                  ),
                  ListTile(
                    title: Text(AppStrings.license),
                    subtitle: const Text(AppConstants.license),
                    leading: const Icon(Icons.description),
                  ),
                ],
              ),
            ),
    );
  }

  Future<String> _getSnapshotPath() async {
    final hasPermission = await NativeBridge.hasStoragePermission();
    if (hasPermission) {
      final sdcard = await NativeBridge.getExternalStoragePath();
      final downloadDir = Directory('$sdcard/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return '$sdcard/Download/openclaw-snapshot.json';
    }
    // Fallback to app-private directory
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/openclaw-snapshot.json';
  }

  Future<void> _exportSnapshot() async {
    try {
      final openclawJson = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json');
      final snapshot = {
        'version': AppConstants.version,
        'timestamp': DateTime.now().toIso8601String(),
        'openclawConfig': openclawJson,
        'dashboardUrl': _prefs.dashboardUrl,
        'autoStart': _prefs.autoStartGateway,
        'nodeEnabled': _prefs.nodeEnabled,
        'nodeDeviceToken': _prefs.nodeDeviceToken,
        'nodeGatewayHost': _prefs.nodeGatewayHost,
        'nodeGatewayPort': _prefs.nodeGatewayPort,
        'nodeGatewayToken': _prefs.nodeGatewayToken,
      };

      final path = await _getSnapshotPath();
      final file = File(path);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.snapshotSaved}: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.exportFailed}: $e')),
      );
    }
  }

  Future<void> _importSnapshot() async {
    try {
      final path = await _getSnapshotPath();
      final file = File(path);

      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.noSnapshotFound}: $path')),
        );
        return;
      }

      final content = await file.readAsString();
      final snapshot = jsonDecode(content) as Map<String, dynamic>;

      // Restore openclaw.json into rootfs
      final openclawConfig = snapshot['openclawConfig'] as String?;
      if (openclawConfig != null) {
        await NativeBridge.writeRootfsFile('root/.openclaw/openclaw.json', openclawConfig);
      }

      // Restore preferences
      if (snapshot['dashboardUrl'] != null) {
        _prefs.dashboardUrl = snapshot['dashboardUrl'] as String;
      }
      if (snapshot['autoStart'] != null) {
        _prefs.autoStartGateway = snapshot['autoStart'] as bool;
      }
      if (snapshot['nodeEnabled'] != null) {
        _prefs.nodeEnabled = snapshot['nodeEnabled'] as bool;
      }
      if (snapshot['nodeDeviceToken'] != null) {
        _prefs.nodeDeviceToken = snapshot['nodeDeviceToken'] as String;
      }
      if (snapshot['nodeGatewayHost'] != null) {
        _prefs.nodeGatewayHost = snapshot['nodeGatewayHost'] as String;
      }
      if (snapshot['nodeGatewayPort'] != null) {
        _prefs.nodeGatewayPort = snapshot['nodeGatewayPort'] as int;
      }
      if (snapshot['nodeGatewayToken'] != null) {
        _prefs.nodeGatewayToken = snapshot['nodeGatewayToken'] as String;
      }

      // Refresh UI
      await _loadSettings();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.snapshotRestored)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.importFailed}: $e')),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      final result = await UpdateService.check();
      if (!mounted) return;
      if (result.available) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppStrings.updateAvailable),
            content: Text(
              '${AppStrings.currentVersion}: ${AppConstants.version}\n'
              '${AppStrings.latestVersion}: ${result.latest}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppStrings.later),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  launchUrl(
                    Uri.parse(result.url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Text(AppStrings.download),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.alreadyLatest)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.checkUpdateFailed)),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
