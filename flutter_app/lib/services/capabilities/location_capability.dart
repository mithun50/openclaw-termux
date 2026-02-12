import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class LocationCapability extends CapabilityHandler {
  @override
  String get name => 'location';

  @override
  List<String> get commands => ['get'];

  @override
  List<Permission> get requiredPermissions => [Permission.location];

  @override
  Future<bool> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Future<bool> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'location.get':
        return _getLocation(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown location command: $command',
        });
    }
  }

  Future<NodeFrame> _getLocation(Map<String, dynamic> params) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return NodeFrame.response('', error: {
          'code': 'LOCATION_DISABLED',
          'message': 'Location services are disabled',
        });
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return NodeFrame.response('', payload: {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'timestamp': position.timestamp.toIso8601String(),
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'LOCATION_ERROR',
        'message': '$e',
      });
    }
  }
}
