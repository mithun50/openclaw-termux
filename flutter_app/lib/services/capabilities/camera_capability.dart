import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class CameraCapability extends CapabilityHandler {
  List<CameraDescription>? _cameras;
  
  // Record the camera file generated during this session (unique ID+path)
  // Ensure that only files created by oneself are deleted during deletion to avoid accidentally deleting user albums
  /**Fixed since March 22, 2026
  submitter：wuchenxiuwu */
  final List<Map<String, String>> _cameraFiles = [];

  @override
  String get name => 'camera';

  @override
  List<String> get commands => ['snap', 'clip', 'list'];

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

  /// Create a fresh controller for each operation. The caller MUST dispose it
  /// when done so the camera hardware is released immediately.
  Future<CameraController> _createController({String? facing}) async {
    _cameras ??= await availableCameras();
    if (_cameras!.isEmpty) throw Exception('No camera available');

    final direction = facing == 'front'
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final target = _cameras!.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => _cameras!.first,
    );

    final controller = CameraController(target, ResolutionPreset.medium);
    await controller.initialize();
    return controller;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'camera.snap':
        return _snap(params);
      case 'camera.clip':
        return _clip(params);
      case 'camera.list':
        return _list();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown camera command: $command',
        });
    }
  }

  Future<NodeFrame> _list() async {
    try {
      _cameras ??= await availableCameras();
      final cameraList = _cameras!.map((c) => {
        'id': c.name,
        'facing': c.lensDirection == CameraLensDirection.front ? 'front' : 'back',
      }).toList();
      return NodeFrame.response('', payload: {
        'cameras': cameraList,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    }
  }

  // Generate a unique ID (timestamp+random number)
  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000000);
    return '${now}_$random';
  }

  Future<NodeFrame> _snap(Map<String, dynamic> params) async {
    CameraController? controller;
    String? fileId;
    try {
      final facing = params['facing'] as String?;
      controller = await _createController(facing: facing);

      await Future.delayed(const Duration(milliseconds: 500));

      final file = await controller.takePicture();
      final path = file.path;

      // Record the files generated this time in the inventory
      fileId = _generateId();
      _cameraFiles.add({'id': fileId, 'path': path});

      final bytes = await File(path).readAsBytes();
      final b64 = base64Encode(bytes);

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();

      // Only delete files when they are on the list to prevent accidental deletion of the album
      final index = _cameraFiles.indexWhere((item) => item['id'] == fileId && item['path'] == path);
      if (index != -1) {
        try {
          await File(path).delete();
          _cameraFiles.removeAt(index);
        } catch (_) {
          // Keep tracking entry so dispose() can retry cleanup later.
        }
      }

      return NodeFrame.response('', payload: {
        'base64': b64,
        'format': 'jpg',
        'width': width,
        'height': height,
      });
    } catch (e) {
      //Clean up records in the inventory when errors occur to avoid residue
      if (fileId != null) {
        _cameraFiles.removeWhere((item) => item['id'] == fileId);
      }
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    } finally {
      await controller?.dispose();
    }
  }

  Future<NodeFrame> _clip(Map<String, dynamic> params) async {
    CameraController? controller;
    String? fileId;
    try {
      final durationMs = params['durationMs'] as int? ?? 5000;
      final facing = params['facing'] as String?;
      controller = await _createController(facing: facing);
      await controller.startVideoRecording();
      await Future.delayed(Duration(milliseconds: durationMs));
      final file = await controller.stopVideoRecording();
      final path = file.path;

      //Record the files generated this time in the inventory
      fileId = _generateId();
      _cameraFiles.add({'id': fileId, 'path': path});

      final bytes = await File(path).readAsBytes();
      final b64 = base64Encode(bytes);

      //Only delete files when they are on the list to prevent accidental deletion of user albums
      final index = _cameraFiles.indexWhere((item) => item['id'] == fileId && item['path'] == path);
      if (index != -1) {
        _cameraFiles.removeAt(index);
        await File(path).delete().catchError((_) => File(path));
      }

      return NodeFrame.response('', payload: {
        'base64': b64,
        'format': 'mp4',
        'durationMs': durationMs,
        'hasAudio': false,
      });
    } catch (e) {
      //Clean up records in the inventory when errors occur to avoid residue
      if (fileId != null) {
        _cameraFiles.removeWhere((item) => item['id'] == fileId);
      }
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    } finally {
      await controller?.dispose();
    }
  }

  //Clean up all undeleted temporary files when the application exits
  void dispose() {
    for (final item in _cameraFiles) {
      final path = item['path'];
      if (path != null) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
    }
    _cameraFiles.clear();
  }
}
