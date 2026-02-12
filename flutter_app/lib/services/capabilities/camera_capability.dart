import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class CameraCapability extends CapabilityHandler {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  @override
  String get name => 'camera';

  @override
  List<String> get commands => ['snap', 'clip'];

  @override
  List<Permission> get requiredPermissions => [Permission.camera];

  @override
  Future<bool> checkPermission() async {
    return await Permission.camera.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<CameraController> _getController() async {
    if (_controller != null && _controller!.value.isInitialized) {
      return _controller!;
    }
    _cameras ??= await availableCameras();
    if (_cameras!.isEmpty) throw Exception('No camera available');
    _controller = CameraController(_cameras!.first, ResolutionPreset.medium);
    await _controller!.initialize();
    return _controller!;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'camera.snap':
        return _snap(params);
      case 'camera.clip':
        return _clip(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown camera command: $command',
        });
    }
  }

  Future<NodeFrame> _snap(Map<String, dynamic> params) async {
    try {
      final controller = await _getController();
      final file = await controller.takePicture();
      final bytes = await File(file.path).readAsBytes();
      final b64 = base64Encode(bytes);
      // Clean up temp file
      await File(file.path).delete().catchError((_) => File(file.path));
      return NodeFrame.response('', payload: {
        'image': b64,
        'format': 'jpg',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _clip(Map<String, dynamic> params) async {
    try {
      final durationMs = params['durationMs'] as int? ?? 5000;
      final controller = await _getController();
      await controller.startVideoRecording();
      await Future.delayed(Duration(milliseconds: durationMs));
      final file = await controller.stopVideoRecording();
      final bytes = await File(file.path).readAsBytes();
      final b64 = base64Encode(bytes);
      await File(file.path).delete().catchError((_) => File(file.path));
      return NodeFrame.response('', payload: {
        'video': b64,
        'format': 'mp4',
        'durationMs': durationMs,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
