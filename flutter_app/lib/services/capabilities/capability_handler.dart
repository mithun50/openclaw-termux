import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';

abstract class CapabilityHandler {
  String get name;
  List<String> get commands;

  Future<NodeFrame> handle(String command, Map<String, dynamic> params);
  Future<bool> checkPermission();
  Future<bool> requestPermission();

  /// Override to return the Permission(s) this capability needs.
  /// Used by handleWithPermission to detect permanently denied state.
  List<Permission> get requiredPermissions => [];

  /// Ensures permission is granted before handling. Returns error frame if denied.
  Future<NodeFrame> handleWithPermission(
      String command, Map<String, dynamic> params) async {
    if (!await checkPermission()) {
      // Check if any permission is permanently denied
      for (final perm in requiredPermissions) {
        if (await perm.isPermanentlyDenied) {
          return NodeFrame.response('', error: {
            'code': 'PERMISSION_PERMANENTLY_DENIED',
            'message':
                '$name permission permanently denied. Enable it in Android Settings > Apps > OpenClaw > Permissions.',
          });
        }
      }

      final granted = await requestPermission();
      if (!granted) {
        return NodeFrame.response('', error: {
          'code': 'PERMISSION_DENIED',
          'message': '$name permission not granted',
        });
      }
    }
    return handle(command, params);
  }
}
