import '../../models/node_frame.dart';
import 'capability_handler.dart';

/// Canvas capability stub.
/// WebView-based canvas is not implemented on this platform.
/// Returns honest NOT_IMPLEMENTED errors so the gateway/AI knows
/// canvas commands are unavailable rather than faking success.
class CanvasCapability extends CapabilityHandler {
  @override
  String get name => 'canvas';

  @override
  List<String> get commands => ['navigate', 'eval', 'snapshot'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    return NodeFrame.response('', error: {
      'code': 'NOT_IMPLEMENTED',
      'message':
          'Canvas capability is not available on this device. '
          'Command "$command" requires a WebView context which is not supported.',
    });
  }
}
