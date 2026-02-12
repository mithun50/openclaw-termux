import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class FlashCapability extends CapabilityHandler {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _torchOn = false;

  @override
  String get name => 'flash';

  @override
  List<String> get commands => ['on', 'off', 'toggle', 'status'];

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
    // Use back camera for flash/torch
    final backCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );
    _controller = CameraController(backCamera, ResolutionPreset.low);
    await _controller!.initialize();
    return _controller!;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'flash.on':
        return _setTorch(true);
      case 'flash.off':
        return _setTorch(false);
      case 'flash.toggle':
        return _setTorch(!_torchOn);
      case 'flash.status':
        return NodeFrame.response('', payload: {'on': _torchOn});
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown flash command: $command',
        });
    }
  }

  Future<NodeFrame> _setTorch(bool on) async {
    try {
      final controller = await _getController();
      await controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      _torchOn = on;
      return NodeFrame.response('', payload: {'on': _torchOn});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FLASH_ERROR',
        'message': '$e',
      });
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
