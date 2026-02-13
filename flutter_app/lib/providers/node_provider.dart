import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/gateway_state.dart';
import '../models/node_state.dart';
import '../services/capabilities/camera_capability.dart';
import '../services/capabilities/canvas_capability.dart';
import '../services/capabilities/flash_capability.dart';
import '../services/capabilities/location_capability.dart';
import '../services/capabilities/screen_capability.dart';
import '../services/capabilities/sensor_capability.dart';
import '../services/capabilities/vibration_capability.dart';
import '../services/native_bridge.dart';
import '../services/node_service.dart';
import '../services/preferences_service.dart';


class NodeProvider extends ChangeNotifier with WidgetsBindingObserver {
  final NodeService _nodeService = NodeService();
  StreamSubscription? _subscription;
  NodeState _state = const NodeState();
  GatewayState? _lastGatewayState;
  Timer? _watchdog;

  // Capabilities
  final _cameraCapability = CameraCapability();
  final _canvasCapability = CanvasCapability();
  final _flashCapability = FlashCapability();
  final _locationCapability = LocationCapability();
  final _screenCapability = ScreenCapability();
  final _sensorCapability = SensorCapability();
  final _vibrationCapability = VibrationCapability();

  NodeState get state => _state;

  NodeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _nodeService.stateStream.listen((state) {
      _state = state;
      notifyListeners();
    });
    _registerCapabilities();
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      // App came back to foreground — reconnect if the connection dropped
      if (!_state.isPaired && !_state.isDisabled && !_state.isConnecting) {
        _checkAutoConnect();
      }
    }
  }

  void _registerCapabilities() {
    _nodeService.registerCapability(
      _cameraCapability.name,
      _cameraCapability.commands.map((c) => '${_cameraCapability.name}.$c').toList(),
      (cmd, params) => _cameraCapability.handleWithPermission(cmd, params),
    );
    _nodeService.registerCapability(
      _canvasCapability.name,
      _canvasCapability.commands.map((c) => '${_canvasCapability.name}.$c').toList(),
      (cmd, params) => _canvasCapability.handle(cmd, params),
    );
    _nodeService.registerCapability(
      _locationCapability.name,
      _locationCapability.commands.map((c) => '${_locationCapability.name}.$c').toList(),
      (cmd, params) => _locationCapability.handleWithPermission(cmd, params),
    );
    _nodeService.registerCapability(
      _screenCapability.name,
      _screenCapability.commands.map((c) => '${_screenCapability.name}.$c').toList(),
      (cmd, params) => _screenCapability.handle(cmd, params),
    );
    _nodeService.registerCapability(
      _flashCapability.name,
      _flashCapability.commands.map((c) => '${_flashCapability.name}.$c').toList(),
      (cmd, params) => _flashCapability.handleWithPermission(cmd, params),
    );
    _nodeService.registerCapability(
      _vibrationCapability.name,
      _vibrationCapability.commands.map((c) => '${_vibrationCapability.name}.$c').toList(),
      (cmd, params) => _vibrationCapability.handle(cmd, params),
    );
    _nodeService.registerCapability(
      _sensorCapability.name,
      _sensorCapability.commands.map((c) => '${_sensorCapability.name}.$c').toList(),
      (cmd, params) => _sensorCapability.handleWithPermission(cmd, params),
    );
  }

  Future<void> _init() async {
    await _nodeService.init();
    final prefs = PreferencesService();
    await prefs.init();
    if (prefs.nodeEnabled) {
      await _requestNodePermissions();
      await _requestBatteryOptimization();
      await NativeBridge.startNodeService();
      await _nodeService.connect();
      _startWatchdog();
    }
  }

  void onGatewayStateChanged(GatewayState gatewayState) {
    final wasRunning = _lastGatewayState?.isRunning ?? false;
    final isRunning = gatewayState.isRunning;
    _lastGatewayState = gatewayState;

    if (!wasRunning && isRunning && _state.isDisabled) {
      // Gateway just started - auto-enable node if previously enabled
      _checkAutoConnect();
    } else if (wasRunning && !isRunning && !_state.isDisabled) {
      // Gateway stopped - disconnect node and stop foreground service
      _stopWatchdog();
      _nodeService.disconnect();
      NativeBridge.stopNodeService();
    }
  }

  Future<void> _checkAutoConnect() async {
    final prefs = PreferencesService();
    await prefs.init();
    if (prefs.nodeEnabled) {
      await _requestNodePermissions();
      await _nodeService.connect();
      _startWatchdog();
    }
  }

  /// Request runtime permissions proactively so they are granted before
  /// the gateway sends invoke requests (which would otherwise be blocked).
  Future<void> _requestNodePermissions() async {
    await [
      Permission.camera,
      Permission.location,
      Permission.sensors,
    ].request();
  }

  /// Prompt user to disable battery optimization so Android doesn't kill
  /// the app process while the node is connected in the background.
  Future<void> _requestBatteryOptimization() async {
    try {
      final optimized = await NativeBridge.isBatteryOptimized();
      if (optimized) {
        await NativeBridge.requestBatteryOptimization();
      }
    } catch (_) {}
  }

  /// Periodic watchdog that detects stale/dropped connections and forces
  /// reconnect. Runs every 45s. Handles two cases:
  /// 1. Node should be connected but isn't (dropped in background)
  /// 2. Node appears paired but WebSocket is stale (no data for 90s+)
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_state.isDisabled) return;

      if (!_state.isPaired && !_state.isConnecting) {
        // Connection dropped — reconnect
        _nodeService.connect();
      } else if (_state.isPaired && _nodeService.isConnectionStale) {
        // Connection appears alive but no data received — force reconnect
        _nodeService.disconnect().then((_) => _nodeService.connect());
      }
    });
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  Future<void> enable() async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.nodeEnabled = true;
    await _requestNodePermissions();
    await _requestBatteryOptimization();
    await NativeBridge.startNodeService();
    await _nodeService.connect();
    _startWatchdog();
  }

  Future<void> disable() async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.nodeEnabled = false;
    _stopWatchdog();
    await _nodeService.disable();
    await NativeBridge.stopNodeService();
  }

  Future<void> connectRemote(String host, int port, {String? token}) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.nodeGatewayHost = host;
    prefs.nodeGatewayPort = port;
    prefs.nodeGatewayToken = token;
    prefs.nodeEnabled = true;
    // Clear cached token so it re-reads on next connect
    _nodeService.clearCachedToken();
    await _requestNodePermissions();
    await _requestBatteryOptimization();
    await NativeBridge.startNodeService();
    await _nodeService.connect(host: host, port: port);
    _startWatchdog();
  }

  Future<void> reconnect() async {
    await _nodeService.disconnect();
    await _nodeService.connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopWatchdog();
    _subscription?.cancel();
    _nodeService.dispose();
    _cameraCapability.dispose();
    _flashCapability.dispose();
    NativeBridge.stopNodeService();
    super.dispose();
  }
}
