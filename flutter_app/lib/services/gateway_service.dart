import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/gateway_state.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';

class GatewayService {
  Timer? _healthTimer;
  StreamSubscription? _logSubscription;
  final _stateController = StreamController<GatewayState>.broadcast();
  GatewayState _state = const GatewayState();
  static final _tokenUrlRegex = RegExp(r'https?://(?:localhost|127\.0\.0\.1):18789/#token=[0-9a-f]+');
  static final _boxDrawing = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');

  /// Strip ANSI, box-drawing chars, and whitespace to reconstruct URLs
  /// split by terminal line wrapping or TUI borders.
  static String _cleanForUrl(String text) {
    return text
        .replaceAll(AppConstants.ansiEscape, '')
        .replaceAll(_boxDrawing, '')
        .replaceAll(RegExp(r'\s+'), '');
  }

  static String _ts(String msg) => '${DateTime.now().toUtc().toIso8601String()} $msg';

  Stream<GatewayState> get stateStream => _stateController.stream;
  GatewayState get state => _state;

  void _updateState(GatewayState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  /// Check if the gateway is already running (e.g. after app restart)
  /// and sync the UI state accordingly.  If not running but auto-start
  /// is enabled, start it automatically.
  Future<void> init() async {
    final prefs = PreferencesService();
    await prefs.init();
    final savedUrl = prefs.dashboardUrl;

    // Always ensure directories and resolv.conf exist on app open.
    // Android may clear the files directory during an app update (#40).
    try { await NativeBridge.setupDirs(); } catch (_) {}
    try { await NativeBridge.writeResolv(); } catch (_) {}
    // Dart dart:io fallback if native calls failed (#40).
    try {
      final filesDir = await NativeBridge.getFilesDir();
      const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
      final resolvFile = File('$filesDir/config/resolv.conf');
      if (!resolvFile.existsSync()) {
        Directory('$filesDir/config').createSync(recursive: true);
        resolvFile.writeAsStringSync(resolvContent);
      }
      // Also write into rootfs /etc/ so DNS works even if bind-mount fails
      final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
      if (!rootfsResolv.existsSync()) {
        rootfsResolv.parent.createSync(recursive: true);
        rootfsResolv.writeAsStringSync(resolvContent);
      }
    } catch (_) {}

    final alreadyRunning = await NativeBridge.isGatewayRunning();
    if (alreadyRunning) {
      // Write allowCommands config so the next gateway restart picks it up,
      // and in case the running gateway supports config hot-reload.
      await _writeNodeAllowConfig();
      _updateState(_state.copyWith(
        status: GatewayStatus.starting,
        dashboardUrl: savedUrl,
        logs: [..._state.logs, _ts('[INFO] Gateway process detected, reconnecting...')],
      ));

      _subscribeLogs();
      _startHealthCheck();
    } else if (prefs.autoStartGateway) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, _ts('[INFO] Auto-starting gateway...')],
      ));
      await start();
    }
  }

  void _subscribeLogs() {
    _logSubscription?.cancel();
    _logSubscription = NativeBridge.gatewayLogStream.listen((log) {
      final logs = [..._state.logs, log];
      if (logs.length > 500) {
        logs.removeRange(0, logs.length - 500);
      }
      String? dashboardUrl;
      final cleanLog = _cleanForUrl(log);
      final urlMatch = _tokenUrlRegex.firstMatch(cleanLog);
      if (urlMatch != null) {
        dashboardUrl = urlMatch.group(0);
        final prefs = PreferencesService();
        prefs.init().then((_) => prefs.dashboardUrl = dashboardUrl);
      }
      _updateState(_state.copyWith(logs: logs, dashboardUrl: dashboardUrl));
    });
  }

  /// Patch /root/.openclaw/openclaw.json to clear denyCommands and set
  /// allowCommands for all node capabilities. This is the config file the
  /// gateway actually reads (not a separate gateway.json).
  Future<void> _writeNodeAllowConfig() async {
    const allowCommands = [
      'camera.snap', 'camera.clip', 'camera.list',
      'canvas.navigate', 'canvas.eval', 'canvas.snapshot',
      'flash.on', 'flash.off', 'flash.toggle', 'flash.status',
      'location.get',
      'screen.record',
      'sensor.read', 'sensor.list',
      'haptic.vibrate',
      'serial.list', 'serial.connect', 'serial.disconnect', 'serial.write', 'serial.read',
    ];
    // Use a Node.js one-liner to safely merge into existing openclaw.json
    // without clobbering other settings (API keys, onboarding config, etc.)
    final allowJson = jsonEncode(allowCommands);
    final script = '''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (!c.gateway) c.gateway = {};
if (!c.gateway.nodes) c.gateway.nodes = {};
c.gateway.nodes.denyCommands = [];
c.gateway.nodes.allowCommands = $allowJson;
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    var prootOk = false;
    try {
      await NativeBridge.runInProot(
        'node -e ${_shellEscape(script)}',
        timeout: 15,
      );
      prootOk = true;
    } catch (_) {}

    // Direct file I/O fallback (#56): if proot/node isn't ready, write the
    // config directly on the Android filesystem so the gateway still picks
    // up allowCommands on next start.
    if (!prootOk) {
      try {
        final filesDir = await NativeBridge.getFilesDir();
        final configFile = File('$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json');
        Map<String, dynamic> config = {};
        if (configFile.existsSync()) {
          try {
            config = Map<String, dynamic>.from(
                jsonDecode(configFile.readAsStringSync()) as Map);
          } catch (_) {}
        }
        config.putIfAbsent('gateway', () => <String, dynamic>{});
        final gw = config['gateway'] as Map<String, dynamic>;
        gw.putIfAbsent('nodes', () => <String, dynamic>{});
        final nodes = gw['nodes'] as Map<String, dynamic>;
        nodes['denyCommands'] = <String>[];
        nodes['allowCommands'] = allowCommands;
        configFile.parent.createSync(recursive: true);
        configFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(config),
        );
      } catch (_) {}
    }
  }

  /// Escape a string for use as a single-quoted shell argument.
  static String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }

  Future<void> start() async {
    final prefs = PreferencesService();
    await prefs.init();
    final savedUrl = prefs.dashboardUrl;

    _updateState(_state.copyWith(
      status: GatewayStatus.starting,
      clearError: true,
      logs: [..._state.logs, _ts('[INFO] Starting gateway...')],
      dashboardUrl: savedUrl,
    ));

    try {
      // Ensure directories exist — Android may have cleared them (#40).
      // Non-fatal: the GatewayService foreground service also creates them.
      try { await NativeBridge.setupDirs(); } catch (_) {}
      try { await NativeBridge.writeResolv(); } catch (_) {}
      // Dart dart:io fallback if native calls failed (#40).
      try {
        final filesDir = await NativeBridge.getFilesDir();
        const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
        final resolvFile = File('$filesDir/config/resolv.conf');
        if (!resolvFile.existsSync()) {
          Directory('$filesDir/config').createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
        // Also write into rootfs /etc/ so DNS works even if bind-mount fails
        final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}
      await _writeNodeAllowConfig();
      await NativeBridge.startGateway();
      _subscribeLogs();
      _startHealthCheck();
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to start: $e',
        logs: [..._state.logs, _ts('[ERROR] Failed to start: $e')],
      ));
    }
  }

  Future<void> stop() async {
    _healthTimer?.cancel();
    _logSubscription?.cancel();

    try {
      await NativeBridge.stopGateway();
      _updateState(GatewayState(
        status: GatewayStatus.stopped,
        logs: [..._state.logs, _ts('[INFO] Gateway stopped')],
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to stop: $e',
      ));
    }
  }

  void _startHealthCheck() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.healthCheckIntervalMs),
      (_) => _checkHealth(),
    );
  }

  Future<void> _checkHealth() async {
    try {
      final response = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode < 500 && _state.status != GatewayStatus.running) {
        _updateState(_state.copyWith(
          status: GatewayStatus.running,
          startedAt: DateTime.now(),
          logs: [..._state.logs, _ts('[INFO] Gateway is healthy')],
        ));
      }
    } catch (_) {
      // Still starting or temporarily unreachable
      final isRunning = await NativeBridge.isGatewayRunning();
      if (!isRunning && _state.status != GatewayStatus.stopped) {
        _updateState(_state.copyWith(
          status: GatewayStatus.stopped,
          logs: [..._state.logs, _ts('[WARN] Gateway process not running')],
        ));
        _healthTimer?.cancel();
      }
    }
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _healthTimer?.cancel();
    _logSubscription?.cancel();
    _stateController.close();
  }
}
