import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class BatteryCapability extends CapabilityHandler {
  @override
  String get name => 'battery';

  @override
  List<String> get commands => ['status'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'battery.status':
        return _status();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown battery command: $command',
        });
    }
  }

  Future<NodeFrame> _status() async {
    try {
      final data = await NativeBridge.getBatteryStatus();
      return NodeFrame.response('', payload: Map<String, dynamic>.from(data));
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'BATTERY_ERROR',
        'message': '$e',
      });
    }
  }
}
