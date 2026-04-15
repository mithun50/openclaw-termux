import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import 'setup_wizard_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'Loading...';
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  String _shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

  String _openclawInstallCommand(String nodeRun, String npmCli) {
    if (AppConstants.openclawTgzUrl.isEmpty) {
      return '$nodeRun $npmCli install -g ${AppConstants.openclawNpmPackage}';
    }
    final tgz = _shellQuote(AppConstants.openclawTgzUrl);
    return '$nodeRun $npmCli install -g $tgz || '
        '$nodeRun $npmCli install -g ${AppConstants.openclawNpmPackage}';
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _checkAndRoute();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRoute() async {
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      setState(() => _status = 'Checking setup status...');

      // Ensure directories and resolv.conf exist on every app open.
      // Android may clear the files directory during update or reinstall (#40).
      try { await NativeBridge.setupDirs(); } catch (_) {}
      try { await NativeBridge.writeResolv(); } catch (_) {}

      // Direct Dart fallback: create resolv.conf if native calls failed (#40).
      try {
        final filesDir = await NativeBridge.getFilesDir();
        const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
        final configDir = '$filesDir/config';
        final resolvFile = File('$configDir/resolv.conf');
        if (!resolvFile.existsSync()) {
          Directory(configDir).createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
        // Also write into rootfs /etc/ so DNS works even if bind-mount fails
        final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}

      final prefs = PreferencesService();
      await prefs.init();

      // Auto-export snapshot when app version changes (#55)
      try {
        final oldVersion = prefs.lastAppVersion;
        if (oldVersion != null && oldVersion != AppConstants.version) {
          final hasPermission = await NativeBridge.hasStoragePermission();
          if (hasPermission) {
            final sdcard = await NativeBridge.getExternalStoragePath();
            final downloadDir = Directory('$sdcard/Download');
            if (!await downloadDir.exists()) {
              await downloadDir.create(recursive: true);
            }
            final snapshotPath = '$sdcard/Download/openclaw-snapshot-$oldVersion.json';
            final openclawJson = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json');
            final snapshot = {
              'version': oldVersion,
              'timestamp': DateTime.now().toIso8601String(),
              'openclawConfig': openclawJson,
              'dashboardUrl': prefs.dashboardUrl,
              'autoStart': prefs.autoStartGateway,
              'nodeEnabled': prefs.nodeEnabled,
              'nodeDeviceToken': prefs.nodeDeviceToken,
              'nodeGatewayHost': prefs.nodeGatewayHost,
              'nodeGatewayPort': prefs.nodeGatewayPort,
              'nodeGatewayToken': prefs.nodeGatewayToken,
            };
            await File(snapshotPath).writeAsString(
              const JsonEncoder.withIndent('  ').convert(snapshot),
            );
          }
        }
        prefs.lastAppVersion = AppConstants.version;
      } catch (_) {}

      bool setupComplete;
      try {
        setupComplete = await NativeBridge.isBootstrapComplete();
      } catch (_) {
        setupComplete = false;
      }

      // Auto-repair: if the rootfs and bash exist but other components are
      // missing, try to repair them instead of forcing full re-setup (#70, #73, #97).
      if (!setupComplete) {
        try {
          final status = await NativeBridge.getBootstrapStatus();
          final rootfsOk = status['rootfsExists'] == true;
          final bashOk = status['binBashExists'] == true;
          final nodeOk = status['nodeInstalled'] == true;
          final openclawOk = status['openclawInstalled'] == true;
          final bypassOk = status['bypassInstalled'] == true;

          // Core rootfs must exist — can't repair without it
          if (rootfsOk && bashOk) {
            // Regenerate bionic bypass if missing
            if (!bypassOk) {
              setState(() => _status = 'Repairing bionic bypass...');
              await NativeBridge.installBionicBypass();
            }

            // Reinstall node if binary is missing (#97)
            if (!nodeOk) {
              setState(() => _status = 'Reinstalling Node.js...');
              try {
                final arch = await NativeBridge.getArch();
                final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
                final filesDir = await NativeBridge.getFilesDir();
                final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';
                final dio = Dio();
                await dio.download(nodeTarUrl, nodeTarPath);
                await NativeBridge.extractNodeTarball(nodeTarPath);
              } catch (_) {}
            }

            // Reinstall openclaw if package.json is missing (#97)
            if (!openclawOk && nodeOk) {
              setState(() => _status = 'Reinstalling OpenClaw...');
              try {
                const wrapper = '/root/.openclaw/node-wrapper.js';
                const nodeRun = 'node $wrapper';
                const npmCli = '/usr/local/lib/node_modules/npm/bin/npm-cli.js';
                await NativeBridge.runInProot(
                  _openclawInstallCommand(nodeRun, npmCli),
                  timeout: 1800,
                );
                await NativeBridge.createBinWrappers('openclaw');
              } catch (_) {}
            }

            setupComplete = await NativeBridge.isBootstrapComplete();
          }
        } catch (_) {}
      }

      if (!mounted) return;

      if (setupComplete) {
        prefs.setupComplete = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/ic_launcher.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'OpenClaw',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI Gateway for Android',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'by ${AppConstants.authorName} | ${AppConstants.orgName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _status,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
