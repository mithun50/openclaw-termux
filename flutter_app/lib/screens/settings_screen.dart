import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/node_provider.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../services/update_service.dart';
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
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionHeader(theme, 'GENERAL'),
                SwitchListTile(
                  title: const Text('Auto-start gateway'),
                  subtitle: const Text('Start the gateway when the app opens'),
                  value: _autoStart,
                  onChanged: (value) {
                    setState(() => _autoStart = value);
                    _prefs.autoStartGateway = value;
                  },
                ),
                ListTile(
                  title: const Text('Battery Optimization'),
                  subtitle: Text(_batteryOptimized
                      ? 'Optimized (may kill background sessions)'
                      : 'Unrestricted (recommended)'),
                  leading: const Icon(Icons.battery_alert),
                  trailing: _batteryOptimized
                      ? const Icon(Icons.warning, color: AppColors.statusAmber)
                      : const Icon(Icons.check_circle, color: AppColors.statusGreen),
                  onTap: () async {
                    await NativeBridge.requestBatteryOptimization();
                    // Refresh status after returning from settings
                    final optimized = await NativeBridge.isBatteryOptimized();
                    setState(() => _batteryOptimized = optimized);
                  },
                ),
                ListTile(
                  title: const Text('Setup Storage'),
                  subtitle: Text(_storageGranted
                      ? 'Granted — /sdcard accessible in proot'
                      : 'Allow access to shared storage'),
                  leading: const Icon(Icons.sd_storage),
                  trailing: _storageGranted
                      ? const Icon(Icons.check_circle, color: AppColors.statusGreen)
                      : const Icon(Icons.warning, color: AppColors.statusAmber),
                  onTap: () async {
                    await NativeBridge.requestStoragePermission();
                    // Refresh after returning from permission screen
                    final granted = await NativeBridge.hasStoragePermission();
                    setState(() => _storageGranted = granted);
                  },
                ),
                const Divider(),
                _sectionHeader(theme, 'NODE'),
                SwitchListTile(
                  title: const Text('Enable Node'),
                  subtitle: const Text('Provide device capabilities to the gateway'),
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
                  title: const Text('Node Configuration'),
                  subtitle: const Text('Connection, pairing, and capabilities'),
                  leading: const Icon(Icons.devices),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NodeScreen()),
                  ),
                ),
                const Divider(),
                _sectionHeader(theme, 'SYSTEM INFO'),
                ListTile(
                  title: const Text('Architecture'),
                  subtitle: Text(_arch),
                  leading: const Icon(Icons.memory),
                ),
                ListTile(
                  title: const Text('PRoot path'),
                  subtitle: Text(_prootPath),
                  leading: const Icon(Icons.folder),
                ),
                ListTile(
                  title: const Text('Rootfs'),
                  subtitle: Text(_status['rootfsExists'] == true
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.storage),
                ),
                ListTile(
                  title: const Text('Node.js'),
                  subtitle: Text(_status['nodeInstalled'] == true
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.code),
                ),
                ListTile(
                  title: const Text('OpenClaw'),
                  subtitle: Text(_status['openclawInstalled'] == true
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.cloud),
                ),
                ListTile(
                  title: const Text('Go (Golang)'),
                  subtitle: Text(_goInstalled
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.integration_instructions),
                ),
                ListTile(
                  title: const Text('Homebrew'),
                  subtitle: Text(_brewInstalled
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.science),
                ),
                ListTile(
                  title: const Text('OpenSSH'),
                  subtitle: Text(_sshInstalled
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.vpn_key),
                ),
                const Divider(),
                _sectionHeader(theme, 'MAINTENANCE'),
                ListTile(
                  title: const Text('Export Snapshot'),
                  subtitle: const Text('Backup config to Downloads'),
                  leading: const Icon(Icons.upload_file),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportSnapshot,
                ),
                ListTile(
                  title: const Text('Import Snapshot'),
                  subtitle: const Text('Restore config from backup'),
                  leading: const Icon(Icons.download),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _importSnapshot,
                ),
                ListTile(
                  title: const Text('Re-run setup'),
                  subtitle: const Text('Reinstall or repair the environment'),
                  leading: const Icon(Icons.build),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const SetupWizardScreen(),
                    ),
                  ),
                ),
                const Divider(),
                _sectionHeader(theme, 'ABOUT'),
                const ListTile(
                  title: Text('OpenClaw'),
                  subtitle: Text(
                    'AI Gateway for Android\nVersion ${AppConstants.version}',
                  ),
                  leading: Icon(Icons.info_outline),
                  isThreeLine: true,
                ),
                ListTile(
                  title: const Text('Check for Updates'),
                  subtitle: const Text('Check GitHub for a newer release'),
                  leading: _checkingUpdate
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update),
                  onTap: _checkingUpdate ? null : _checkForUpdates,
                ),
                const ListTile(
                  title: Text('Developer'),
                  subtitle: Text(AppConstants.authorName),
                  leading: Icon(Icons.person),
                ),
                ListTile(
                  title: const Text('GitHub'),
                  subtitle: const Text('mithun50/openclaw-termux'),
                  leading: const Icon(Icons.code),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.githubUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('Contact'),
                  subtitle: const Text(AppConstants.authorEmail),
                  leading: const Icon(Icons.email),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('mailto:${AppConstants.authorEmail}'),
                  ),
                ),
                const ListTile(
                  title: Text('License'),
                  subtitle: Text(AppConstants.license),
                  leading: Icon(Icons.description),
                ),
                const Divider(),
                _sectionHeader(theme, AppConstants.orgName.toUpperCase()),
                ListTile(
                  title: const Text('Instagram'),
                  subtitle: const Text('@nexgenxplorer_nxg'),
                  leading: const Icon(Icons.camera_alt),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.instagramUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('YouTube'),
                  subtitle: const Text('@nexgenxplorer'),
                  leading: const Icon(Icons.play_circle_fill),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.youtubeUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('Play Store'),
                  subtitle: const Text('NextGenX Apps'),
                  leading: const Icon(Icons.shop),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.playStoreUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('Email'),
                  subtitle: const Text(AppConstants.orgEmail),
                  leading: const Icon(Icons.email_outlined),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('mailto:${AppConstants.orgEmail}'),
                  ),
                ),
              ],
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
        SnackBar(content: Text('Snapshot saved to $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
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
          SnackBar(content: Text('No snapshot found at $path')),
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
        const SnackBar(content: Text('Snapshot restored successfully. Restart the gateway to apply.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
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
            title: const Text('Update Available'),
            content: Text(
              'A new version is available.\n\n'
              'Current: ${AppConstants.version}\n'
              'Latest: ${result.latest}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  launchUrl(
                    Uri.parse(result.url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('Download'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're on the latest version")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check for updates')),
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
