import 'dart:async';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants.dart';
import '../models/node_frame.dart';

class NodeWsService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _frameController = StreamController<NodeFrame>.broadcast();
  final _pendingRequests = <String, Completer<NodeFrame>>{};

  bool _connected = false;
  bool _shouldReconnect = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _url;
  DateTime? _lastActivity;

  Stream<NodeFrame> get frameStream => _frameController.stream;
  bool get isConnected => _connected;

  /// Returns true if the WebSocket hasn't received any data for over 90s,
  /// indicating the connection is likely stale.
  bool get isStale =>
      _connected &&
      _lastActivity != null &&
      DateTime.now().difference(_lastActivity!).inSeconds > 90;

  Future<void> connect(String host, int port) async {
    _url = 'ws://$host:$port';
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_url == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url!));
      await _channel!.ready;
      _connected = true;
      _reconnectAttempt = 0;
      _lastActivity = DateTime.now();

      _startPing();

      _subscription = _channel!.stream.listen(
        (data) {
          _lastActivity = DateTime.now();
          try {
            final frame = NodeFrame.decode(data as String);
            // Match pending request/response
            if (frame.isResponse && frame.id != null) {
              final completer = _pendingRequests.remove(frame.id);
              if (completer != null) {
                completer.complete(frame);
                return;
              }
            }
            _frameController.add(frame);
          } catch (_) {}
        },
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connected && _channel != null) {
        try {
          _channel!.sink.add('ping');
        } catch (_) {
          _handleDisconnect();
        }
      }
    });
  }

  void _handleDisconnect() {
    _connected = false;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel = null;

    // Fail all pending requests
    for (final completer in _pendingRequests.values) {
      completer.completeError('WebSocket disconnected');
    }
    _pendingRequests.clear();

    _frameController.add(NodeFrame.event('_disconnected'));

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delayMs = min(
      (AppConstants.wsReconnectBaseMs *
              pow(AppConstants.wsReconnectMultiplier, _reconnectAttempt))
          .round(),
      AppConstants.wsReconnectCapMs,
    );
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_shouldReconnect) {
        await _doConnect();
      }
    });
  }

  /// Send a request frame and wait for the matching response.
  Future<NodeFrame> sendRequest(NodeFrame request, {Duration? timeout}) async {
    if (!_connected || _channel == null) {
      throw StateError('WebSocket not connected');
    }
    final completer = Completer<NodeFrame>();
    _pendingRequests[request.id!] = completer;
    _channel!.sink.add(request.encode());

    final effectiveTimeout = timeout ?? const Duration(seconds: 15);
    return completer.future.timeout(effectiveTimeout, onTimeout: () {
      _pendingRequests.remove(request.id);
      throw TimeoutException('Request timed out', effectiveTimeout);
    });
  }

  /// Send a frame without waiting for response.
  void send(NodeFrame frame) {
    if (_connected && _channel != null) {
      _channel!.sink.add(frame.encode());
    }
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _connected = false;
    await _channel?.sink.close();
    _channel = null;

    for (final completer in _pendingRequests.values) {
      completer.completeError('Disconnected');
    }
    _pendingRequests.clear();
  }

  void dispose() {
    disconnect();
    _frameController.close();
  }
}
