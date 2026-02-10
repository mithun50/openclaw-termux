import 'dart:async';
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

  Stream<GatewayState> get stateStream => _stateController.stream;
  GatewayState get state => _state;

  void _updateState(GatewayState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  /// Check if the gateway is already running (e.g. after app restart)
  /// and sync the UI state accordingly.
  Future<void> init() async {
    final prefs = PreferencesService();
    await prefs.init();
    final savedUrl = prefs.dashboardUrl;

    final alreadyRunning = await NativeBridge.isGatewayRunning();
    if (alreadyRunning) {
      _updateState(_state.copyWith(
        status: GatewayStatus.starting,
        dashboardUrl: savedUrl,
        logs: [..._state.logs, '[INFO] Gateway process detected, reconnecting...'],
      ));

      // Subscribe to log stream from the running service
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

      // Run a health check to confirm it's actually responding
      _startHealthCheck();
    }
  }

  Future<void> start() async {
    // Load saved token URL from preferences
    final prefs = PreferencesService();
    await prefs.init();
    final savedUrl = prefs.dashboardUrl;

    _updateState(_state.copyWith(
      status: GatewayStatus.starting,
      logs: [..._state.logs, '[INFO] Starting gateway...'],
      dashboardUrl: savedUrl,
    ));

    try {
      await NativeBridge.startGateway();

      _logSubscription = NativeBridge.gatewayLogStream.listen((log) {
        final logs = [..._state.logs, log];
        // Keep last 500 lines
        if (logs.length > 500) {
          logs.removeRange(0, logs.length - 500);
        }
        // Parse log for token URL — strip ANSI, box-drawing, whitespace
        String? dashboardUrl;
        final cleanLog = _cleanForUrl(log);
        final urlMatch = _tokenUrlRegex.firstMatch(cleanLog);
        if (urlMatch != null) {
          dashboardUrl = urlMatch.group(0);
          // Persist clean URL for next startup
          final prefs = PreferencesService();
          prefs.init().then((_) => prefs.dashboardUrl = dashboardUrl);
        }
        _updateState(_state.copyWith(logs: logs, dashboardUrl: dashboardUrl));
      });

      _startHealthCheck();
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to start: $e',
        logs: [..._state.logs, '[ERROR] Failed to start: $e'],
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
        logs: [..._state.logs, '[INFO] Gateway stopped'],
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
          logs: [..._state.logs, '[INFO] Gateway is healthy'],
        ));
      }
    } catch (_) {
      // Still starting or temporarily unreachable
      final isRunning = await NativeBridge.isGatewayRunning();
      if (!isRunning && _state.status != GatewayStatus.stopped) {
        _updateState(_state.copyWith(
          status: GatewayStatus.stopped,
          logs: [..._state.logs, '[WARN] Gateway process not running'],
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
