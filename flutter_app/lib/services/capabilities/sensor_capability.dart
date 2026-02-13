import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class SensorCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'sensor';

  @override
  List<String> get commands => ['read', 'list'];

  @override
  List<Permission> get requiredPermissions => [Permission.sensors];

  @override
  Future<bool> checkPermission() async {
    return await Permission.sensors.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.sensors.request();
    return status.isGranted;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'sensor.read':
        return _read(params);
      case 'sensor.list':
        return _list();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown sensor command: $command',
        });
    }
  }

  Future<NodeFrame> _list() async {
    return NodeFrame.response('', payload: {
      'sensors': [
        'accelerometer',
        'gyroscope',
        'magnetometer',
        'barometer',
      ],
    });
  }

  Future<NodeFrame> _read(Map<String, dynamic> params) async {
    final sensor = params['sensor'] as String? ?? 'accelerometer';

    try {
      final data = await _channel.invokeMethod('readSensor', {'sensor': sensor});
      if (data != null) {
        return NodeFrame.response('', payload: Map<String, dynamic>.from(data as Map));
      }
      return NodeFrame.response('', payload: {
        'sensor': sensor,
        'status': 'no_data',
        'message': 'Sensor data not available. Sensor reading requires native integration.',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SENSOR_ERROR',
        'message': '$e',
      });
    }
  }
}
