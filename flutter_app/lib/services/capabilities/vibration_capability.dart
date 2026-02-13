import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class VibrationCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'haptic';

  @override
  List<String> get commands => ['vibrate'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'haptic.vibrate':
        return _vibrate(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown haptic command: $command',
        });
    }
  }

  Future<NodeFrame> _vibrate(Map<String, dynamic> params) async {
    try {
      final durationMs = params['durationMs'] as int? ?? 200;
      final pattern = params['pattern'] as List<dynamic>?;

      if (pattern != null) {
        // Vibrate with pattern: [wait, vibrate, wait, vibrate, ...]
        for (final segment in pattern) {
          final ms = (segment as num).toInt();
          await Future.delayed(Duration(milliseconds: ms));
          await HapticFeedback.heavyImpact();
        }
      } else {
        // Simple vibrate using platform channel
        await _channel.invokeMethod('vibrate', {'durationMs': durationMs});
      }
      return NodeFrame.response('', payload: {'status': 'vibrated'});
    } catch (e) {
      // Fallback to HapticFeedback
      try {
        await HapticFeedback.heavyImpact();
        return NodeFrame.response('', payload: {'status': 'vibrated_fallback'});
      } catch (e2) {
        return NodeFrame.response('', error: {
          'code': 'HAPTIC_ERROR',
          'message': '$e2',
        });
      }
    }
  }
}
