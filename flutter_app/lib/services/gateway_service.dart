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
  Timer? _initialDelayTimer;
  StreamSubscription? _logSubscription;
  final _stateController = StreamController<GatewayState>.broadcast();
  GatewayState _state = const GatewayState();
  DateTime? _startingAt;
  bool _startInProgress = false;
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

    // Repair corrupted config before gateway start (#88).
    // This fixes the "Invalid input: expected object, received string" crash loop.
    await _repairConfigFile();

    final alreadyRunning = await NativeBridge.isGatewayRunning();
    if (alreadyRunning) {
      // Write allowCommands config so the next gateway restart picks it up,
      // and in case the running gateway supports config hot-reload.
      await _writeNodeAllowConfig();
      // Prefer token from config file over stale SharedPreferences value (#74, #82).
      final configToken = await _readTokenFromConfig();
      final effectiveUrl = configToken != null
          ? 'http://localhost:18789/#token=$configToken'
          : savedUrl;
      if (configToken != null) prefs.dashboardUrl = effectiveUrl;
      _startingAt = DateTime.now();
      _updateState(_state.copyWith(
        status: GatewayStatus.starting,
        dashboardUrl: effectiveUrl,
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
      final sanitizedLog = log.replaceAll(AppConstants.ansiEscape, '');
      final logs = [..._state.logs, sanitizedLog];
      if (logs.length > 500) {
        logs.removeRange(0, logs.length - 500);
      }
      String? dashboardUrl;
      final cleanLog = _cleanForUrl(sanitizedLog);
      final urlMatch = _tokenUrlRegex.firstMatch(cleanLog);
      if (urlMatch != null) {
        dashboardUrl = urlMatch.group(0);
        final prefs = PreferencesService();
        prefs.init().then((_) => prefs.dashboardUrl = dashboardUrl);
        NativeBridge.showUrlNotification(dashboardUrl!, title: 'Dashboard Ready');
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
      'battery.status',
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
if (!c.gateway.mode) c.gateway.mode = "local";
if (!c.gateway.nodes) c.gateway.nodes = {};
c.gateway.nodes.denyCommands = [];
c.gateway.nodes.allowCommands = $allowJson;
// Fix config corruption: models entries must be objects, not strings (#83, #88)
if (c.models && c.models.providers) {
  for (const [pid, prov] of Object.entries(c.models.providers)) {
    if (prov && Array.isArray(prov.models)) {
      prov.models = prov.models.map(m => typeof m === "string" ? { id: m } : m);
    }
  }
}
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
        // Ensure gateway.mode=local so the gateway starts without --allow-unconfigured (#93, #90)
        gw.putIfAbsent('mode', () => 'local');
        gw.putIfAbsent('nodes', () => <String, dynamic>{});
        final nodes = gw['nodes'] as Map<String, dynamic>;
        nodes['denyCommands'] = <String>[];
        nodes['allowCommands'] = allowCommands;
        // Fix config corruption: models entries must be objects, not strings (#83, #88)
        _repairModelEntries(config);
        configFile.parent.createSync(recursive: true);
        configFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(config),
        );
      } catch (_) {}
    }
  }

  /// Repair openclaw.json on disk — fixes corrupted model entries and ensures
  /// gateway.mode=local is set. Called on init() before any gateway start (#88).
  Future<void> _repairConfigFile() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final configFile = File('$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json');
      if (!configFile.existsSync()) return;
      final content = configFile.readAsStringSync();
      if (content.isEmpty) return;

      Map<String, dynamic> config;
      try {
        config = Map<String, dynamic>.from(jsonDecode(content) as Map);
      } catch (_) {
        return; // Unparseable — _writeNodeAllowConfig will recreate it
      }

      bool modified = false;

      // Ensure gateway.mode=local (#93, #90)
      config.putIfAbsent('gateway', () => <String, dynamic>{});
      final gw = config['gateway'] as Map<String, dynamic>;
      if (!gw.containsKey('mode')) {
        gw['mode'] = 'local';
        modified = true;
      }

      // Fix model entries: strings → objects (#83, #88)
      final models = config['models'] as Map<String, dynamic>?;
      if (models != null) {
        final providers = models['providers'] as Map<String, dynamic>?;
        if (providers != null) {
          for (final entry in providers.values) {
            if (entry is Map<String, dynamic>) {
              final modelsList = entry['models'];
              if (modelsList is List) {
                for (int i = 0; i < modelsList.length; i++) {
                  if (modelsList[i] is String) {
                    modelsList[i] = {'id': modelsList[i]};
                    modified = true;
                  }
                }
              }
            }
          }
        }
      }

      if (modified) {
        configFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(config),
        );
      }
    } catch (_) {}
  }

  /// Fix corrupted model entries: convert bare strings to {id: string} objects (#83, #88).
  static void _repairModelEntries(Map<String, dynamic> config) {
    final models = config['models'] as Map<String, dynamic>?;
    if (models == null) return;
    final providers = models['providers'] as Map<String, dynamic>?;
    if (providers == null) return;
    for (final entry in providers.values) {
      if (entry is Map<String, dynamic>) {
        final modelsList = entry['models'];
        if (modelsList is List) {
          entry['models'] = modelsList.map((m) {
            if (m is String) return {'id': m};
            return m;
          }).toList();
        }
      }
    }
  }

  /// Read the actual gateway auth token from openclaw.json config file (#74, #82).
  /// This is the source of truth — more reliable than regex-scraping stdout.
  Future<String?> _readTokenFromConfig() async {
    try {
      final raw = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json');
      if (raw == null) return null;
      final config = jsonDecode(raw) as Map<String, dynamic>;
      final token = config['gateway']?['auth']?['token'];
      if (token is String && token.isNotEmpty) return token;
    } catch (_) {}
    return null;
  }

  /// Escape a string for use as a single-quoted shell argument.
  static String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }

  Future<void> start() async {
    // Prevent concurrent start() calls from racing
    if (_startInProgress) return;
    _startInProgress = true;

    // Clear any stale token from a previous session (#74, #82).
    // The fresh token will be captured from gateway stdout once it starts.
    final prefs = PreferencesService();
    await prefs.init();
    prefs.dashboardUrl = null;

    _updateState(_state.copyWith(
      status: GatewayStatus.starting,
      clearError: true,
      clearDashboardUrl: true,
      logs: [..._state.logs, _ts('[INFO] Starting gateway...')],
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
      _startingAt = DateTime.now();
      await NativeBridge.startGateway();
      _subscribeLogs();
      _startHealthCheck();
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to start: $e',
        logs: [..._state.logs, _ts('[ERROR] Failed to start: $e')],
      ));
    } finally {
      _startInProgress = false;
    }
  }

  Future<void> stop() async {
    _cancelAllTimers();
    _logSubscription?.cancel();
    _startingAt = null;

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

  /// Cancel both the initial delay timer and periodic health timer.
  void _cancelAllTimers() {
    _initialDelayTimer?.cancel();
    _initialDelayTimer = null;
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  void _startHealthCheck() {
    _cancelAllTimers();
    // Delay the first health check by 30s — Node.js inside proot needs time to start.
    // Use a Timer (not Future.delayed) so it can be cancelled on stop().
    _initialDelayTimer = Timer(const Duration(seconds: 30), () {
      _initialDelayTimer = null;
      if (_state.status == GatewayStatus.stopped) return;
      _checkHealth();
      _healthTimer = Timer.periodic(
        const Duration(milliseconds: AppConstants.healthCheckIntervalMs),
        (_) => _checkHealth(),
      );
    });
  }

  Future<void> _checkHealth() async {
    try {
      final response = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode < 500 && _state.status != GatewayStatus.running) {
        // Read the actual token from openclaw.json — source of truth (#74, #82).
        // This ensures the displayed token always matches the gateway's config,
        // even if the stdout regex didn't capture it.
        String? configUrl = _state.dashboardUrl;
        try {
          final token = await _readTokenFromConfig();
          if (token != null) {
            configUrl = 'http://localhost:18789/#token=$token';
            final prefs = PreferencesService();
            await prefs.init();
            prefs.dashboardUrl = configUrl;
          }
        } catch (_) {}

        _updateState(_state.copyWith(
          status: GatewayStatus.running,
          startedAt: DateTime.now(),
          dashboardUrl: configUrl,
          logs: [..._state.logs, _ts('[INFO] Gateway is healthy')],
        ));
      }
    } catch (_) {
      // Still starting or temporarily unreachable
      final isRunning = await NativeBridge.isGatewayRunning();
      if (!isRunning && _state.status != GatewayStatus.stopped) {
        // Grace period: if we're still within 120s of startup, don't declare dead.
        // proot + Node.js can take a long time on first boot.
        if (_startingAt != null &&
            _state.status == GatewayStatus.starting &&
            DateTime.now().difference(_startingAt!).inSeconds < 120) {
          _updateState(_state.copyWith(
            logs: [..._state.logs, _ts('[INFO] Starting, waiting for gateway...')],
          ));
          return;
        }
        _updateState(_state.copyWith(
          status: GatewayStatus.stopped,
          logs: [..._state.logs, _ts('[WARN] Gateway process not running')],
        ));
        _cancelAllTimers();
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
    _cancelAllTimers();
    _logSubscription?.cancel();
    _stateController.close();
  }
}
