import 'dart:async';
import 'dart:convert';
import '../constants.dart';
import '../models/node_frame.dart';
import '../models/node_state.dart';
import 'native_bridge.dart';
import 'node_identity_service.dart';
import 'node_ws_service.dart';
import 'preferences_service.dart';

class NodeService {
  final NodeIdentityService _identity = NodeIdentityService();
  final NodeWsService _ws = NodeWsService();
  final _stateController = StreamController<NodeState>.broadcast();
  StreamSubscription? _frameSubscription;

  NodeState _state = const NodeState();
  final Map<String, Future<NodeFrame> Function(String, Map<String, dynamic>)>
      _capabilityHandlers = {};
  String? _gatewayAuthToken;

  Stream<NodeState> get stateStream => _stateController.stream;
  NodeState get state => _state;

  void _updateState(NodeState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  void _log(String message) {
    final logs = [..._state.logs, message];
    if (logs.length > 500) {
      logs.removeRange(0, logs.length - 500);
    }
    _updateState(_state.copyWith(logs: logs));
  }

  void registerCapability(
      String name,
      List<String> commands,
      Future<NodeFrame> Function(String command, Map<String, dynamic> params)
          handler) {
    for (final cmd in commands) {
      _capabilityHandlers['$name.$cmd'] = handler;
    }
  }

  Future<void> init() async {
    await _identity.init();
    _updateState(_state.copyWith(deviceId: _identity.deviceId));
    _log('[NODE] Device ID: ${_identity.deviceId.substring(0, 12)}...');
  }

  Future<void> connect({String? host, int? port}) async {
    final prefs = PreferencesService();
    await prefs.init();

    final targetHost = host ?? prefs.nodeGatewayHost ?? AppConstants.gatewayHost;
    final targetPort = port ?? prefs.nodeGatewayPort ?? AppConstants.gatewayPort;

    _updateState(_state.copyWith(
      status: NodeStatus.connecting,
      clearError: true,
      gatewayHost: targetHost,
      gatewayPort: targetPort,
    ));
    _log('[NODE] Connecting to $targetHost:$targetPort...');

    _frameSubscription?.cancel();
    _frameSubscription = _ws.frameStream.listen(_onFrame);

    try {
      await _ws.connect(targetHost, targetPort);
      _log('[NODE] WebSocket connected, awaiting challenge...');
    } catch (e) {
      _updateState(_state.copyWith(
        status: NodeStatus.error,
        errorMessage: 'Connection failed: $e',
      ));
      _log('[NODE] Connection failed: $e');
    }
  }

  void _onFrame(NodeFrame frame) {
    if (frame.isEvent) {
      _handleEvent(frame);
    } else if (frame.isRequest) {
      _handleInvoke(frame);
    }
  }

  Future<void> _handleEvent(NodeFrame frame) async {
    switch (frame.event) {
      case '_disconnected':
        if (_state.status != NodeStatus.disabled) {
          _updateState(_state.copyWith(
            status: NodeStatus.disconnected,
            clearConnectedAt: true,
          ));
          _log('[NODE] Disconnected, will retry...');
        }
        break;

      case 'connect.challenge':
        _updateState(_state.copyWith(status: NodeStatus.challenging));
        final nonce = frame.payload?['nonce'] as String?;
        if (nonce == null) {
          _log('[NODE] Challenge missing nonce');
          return;
        }
        _log('[NODE] Challenge received, signing...');
        try {
          await _sendConnect(nonce);
        } catch (e) {
          _log('[NODE] Challenge/connect error: $e');
          _updateState(_state.copyWith(
            status: NodeStatus.error,
            errorMessage: '$e',
          ));
        }
        break;
    }
  }

  /// Read the gateway auth token from the local openclaw config.
  Future<String?> _readGatewayToken() async {
    try {
      final raw = await NativeBridge.runInProot(
        'cat /root/.openclaw/openclaw.json',
        timeout: 5,
      );
      final config = jsonDecode(raw) as Map<String, dynamic>;
      final gateway = config['gateway'] as Map<String, dynamic>?;
      final auth = gateway?['auth'] as Map<String, dynamic>?;
      return auth?['token'] as String?;
    } catch (e) {
      _log('[NODE] Could not read gateway token: $e');
      return null;
    }
  }

  /// Build and send the `connect` request per Gateway Protocol v3.
  Future<void> _sendConnect(String nonce) async {
    final prefs = PreferencesService();
    await prefs.init();
    final deviceToken = prefs.nodeDeviceToken;

    // For local connections, read the gateway auth token from config
    final isLocal = _state.gatewayHost == '127.0.0.1' ||
        _state.gatewayHost == 'localhost';
    if (isLocal && _gatewayAuthToken == null) {
      _gatewayAuthToken = await _readGatewayToken();
    }

    // Use device token if available, otherwise gateway auth token
    final authToken = deviceToken ?? _gatewayAuthToken;

    const clientId = 'node-host';
    const clientMode = 'node';
    const role = AppConstants.nodeRole;
    const scopes = <String>['node.device'];
    final signedAtMs = DateTime.now().millisecondsSinceEpoch;

    // Build the structured payload the gateway verifies:
    // "v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce"
    final authPayload = _identity.buildAuthPayload(
      clientId: clientId,
      clientMode: clientMode,
      role: role,
      scopes: scopes,
      signedAtMs: signedAtMs,
      token: authToken,
      nonce: nonce,
    );
    final signature = await _identity.signPayload(authPayload);

    final connectFrame = NodeFrame.request('connect', {
      'minProtocol': 3,
      'maxProtocol': 3,
      'client': {
        'id': clientId,
        'version': AppConstants.version,
        'platform': 'android',
        'mode': clientMode,
      },
      'role': role,
      'scopes': scopes,
      if (authToken != null) 'auth': {'token': authToken},
      'device': {
        'id': _identity.deviceId,
        'publicKey': _identity.publicKeyBase64Url,
        'signature': signature,
        'nonce': nonce,
        'signedAt': signedAtMs,
      },
    });

    final response = await _ws.sendRequest(connectFrame);

    if (response.isOk) {
      // hello-ok
      final authPayload = response.payload?['auth'] as Map<String, dynamic>?;
      final deviceToken = authPayload?['deviceToken'] as String?;
      if (deviceToken != null) {
        prefs.nodeDeviceToken = deviceToken;
      }
      _onConnected(response);
    } else if (response.isError) {
      final errPayload = response.payload ?? response.error ?? {};
      final code = errPayload['code'] as String? ?? '';
      final message = errPayload['message'] as String? ?? 'Connect failed';

      if (code == 'TOKEN_INVALID' || code == 'NOT_PAIRED' ||
          code == 'DEVICE_NOT_PAIRED') {
        _log('[NODE] Not paired, requesting pairing...');
        await _requestPairing();
      } else {
        _updateState(_state.copyWith(
          status: NodeStatus.error,
          errorMessage: message,
        ));
        _log('[NODE] Connect error: $code - $message');
      }
    }
  }

  void _onConnected(NodeFrame frame) {
    _updateState(_state.copyWith(
      status: NodeStatus.paired,
      connectedAt: DateTime.now(),
      clearPairingCode: true,
    ));
    _log('[NODE] Paired and connected');

    // Send capabilities advertisement
    final capabilities = _capabilityHandlers.keys.toList();
    _ws.send(NodeFrame.event('node.capabilities', {
      'deviceId': _identity.deviceId,
      'capabilities': capabilities,
    }));
  }

  Future<void> _requestPairing() async {
    _updateState(_state.copyWith(status: NodeStatus.pairing));
    _log('[NODE] Requesting pairing...');

    try {
      final pairReq = NodeFrame.request('node.pair.request', {
        'deviceId': _identity.deviceId,
      });
      final response = await _ws.sendRequest(
        pairReq,
        timeout: const Duration(milliseconds: AppConstants.pairingTimeoutMs),
      );

      if (response.isError) {
        final errPayload = response.payload ?? response.error ?? {};
        _updateState(_state.copyWith(
          status: NodeStatus.error,
          errorMessage: errPayload['message'] as String? ?? 'Pairing failed',
        ));
        _log('[NODE] Pairing error: $errPayload');
        return;
      }

      final respPayload = response.payload ?? {};
      final code = respPayload['code'] as String?;
      final token = respPayload['token'] as String? ??
          (respPayload['auth'] as Map?)?['deviceToken'] as String?;

      if (token != null) {
        final prefs = PreferencesService();
        await prefs.init();
        prefs.nodeDeviceToken = token;
        _log('[NODE] Pairing approved, token received');
        await Future.delayed(const Duration(milliseconds: 500));
        await _ws.disconnect();
        await connect();
        return;
      }

      if (code != null) {
        _updateState(_state.copyWith(pairingCode: code));
        _log('[NODE] Pairing code: $code');

        // Auto-approve if connecting to localhost
        final isLocal = _state.gatewayHost == '127.0.0.1' ||
            _state.gatewayHost == 'localhost';
        if (isLocal) {
          _log('[NODE] Local gateway detected, auto-approving...');
          try {
            await NativeBridge.runInProot('openclaw nodes approve $code');
            _log('[NODE] Auto-approve command sent');
            await Future.delayed(const Duration(milliseconds: 500));
            await _ws.disconnect();
            await connect();
          } catch (e) {
            _log('[NODE] Auto-approve failed: $e (user must approve manually)');
          }
        }
      }
    } catch (e) {
      _updateState(_state.copyWith(
        status: NodeStatus.error,
        errorMessage: 'Pairing timeout: $e',
      ));
      _log('[NODE] Pairing failed: $e');
    }
  }

  Future<void> _handleInvoke(NodeFrame frame) async {
    final method = frame.method;
    if (method == null || frame.id == null) return;

    _log('[NODE] Invoke: $method');
    final handler = _capabilityHandlers[method];
    if (handler == null) {
      _ws.send(NodeFrame.response(frame.id!, error: {
        'code': 'NOT_SUPPORTED',
        'message': 'Capability $method not available',
      }));
      return;
    }

    try {
      final result = await handler(method, frame.params ?? {});
      if (result.isError) {
        _ws.send(NodeFrame.response(frame.id!, error: result.error));
      } else {
        _ws.send(NodeFrame.response(frame.id!, payload: result.payload));
      }
    } catch (e) {
      _ws.send(NodeFrame.response(frame.id!, error: {
        'code': 'INVOKE_ERROR',
        'message': '$e',
      }));
    }
  }

  Future<void> disconnect() async {
    _frameSubscription?.cancel();
    await _ws.disconnect();
    _updateState(_state.copyWith(
      status: NodeStatus.disconnected,
      clearConnectedAt: true,
      clearPairingCode: true,
    ));
    _log('[NODE] Disconnected');
  }

  Future<void> disable() async {
    await disconnect();
    _updateState(NodeState(
      status: NodeStatus.disabled,
      logs: _state.logs,
      deviceId: _state.deviceId,
    ));
    _log('[NODE] Node disabled');
  }

  void dispose() {
    _frameSubscription?.cancel();
    _ws.dispose();
    _stateController.close();
  }
}
