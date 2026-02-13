import 'dart:convert';
import 'dart:io';
import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class ScreenCapability extends CapabilityHandler {
  @override
  String get name => 'screen';

  @override
  List<String> get commands => ['record'];

  @override
  Future<bool> checkPermission() async {
    // Screen recording always requires user consent each time (Play Store requirement).
    // Permission is requested per-invocation via the MediaProjection consent dialog.
    return true;
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'screen.record':
        return _record(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown screen command: $command',
        });
    }
  }

  Future<NodeFrame> _record(Map<String, dynamic> params) async {
    try {
      final durationMs = params['durationMs'] as int? ?? 5000;

      // This triggers the mandatory user consent dialog every time
      final filePath = await NativeBridge.requestScreenCapture(durationMs);

      if (filePath == null || filePath.isEmpty) {
        return NodeFrame.response('', error: {
          'code': 'SCREEN_DENIED',
          'message': 'User denied screen recording',
        });
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return NodeFrame.response('', error: {
          'code': 'SCREEN_ERROR',
          'message': 'Recording file not found',
        });
      }

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      await file.delete().catchError((_) => file);

      return NodeFrame.response('', payload: {
        'base64': b64,
        'format': 'mp4',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SCREEN_ERROR',
        'message': '$e',
      });
    }
  }
}
