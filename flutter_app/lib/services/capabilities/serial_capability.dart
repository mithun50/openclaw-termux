import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usb_serial/usb_serial.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class SerialCapability extends CapabilityHandler {
  /// Nordic UART Service UUIDs
  static const _nusServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const _nusTxCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
  static const _nusRxCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  final Map<String, _SerialConnection> _connections = {};

  @override
  String get name => 'serial';

  @override
  List<String> get commands => ['list', 'connect', 'disconnect', 'write', 'read'];

  @override
  List<Permission> get requiredPermissions => [
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
  ];

  @override
  Future<bool> checkPermission() async {
    return await Permission.bluetoothConnect.isGranted &&
        await Permission.bluetoothScan.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'serial.list':
        return _list();
      case 'serial.connect':
        return _connect(params);
      case 'serial.disconnect':
        return _disconnect(params);
      case 'serial.write':
        return _write(params);
      case 'serial.read':
        return _read(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown serial command: $command',
        });
    }
  }

  Future<NodeFrame> _list() async {
    final devices = <Map<String, dynamic>>[];

    // List USB devices
    try {
      final usbDevices = await UsbSerial.listDevices();
      for (final d in usbDevices) {
        devices.add({
          'id': 'usb:${d.deviceId}',
          'type': 'usb',
          'name': d.productName ?? 'USB Device',
          'vendorId': d.vid,
          'productId': d.pid,
        });
      }
    } catch (_) {}

    // List BLE devices (quick scan)
    try {
      final bleDevices = <BluetoothDevice>[];
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (!bleDevices.any((d) => d.remoteId == r.device.remoteId)) {
            bleDevices.add(r.device);
          }
        }
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
      await Future.delayed(const Duration(seconds: 3));
      subscription.cancel();
      await FlutterBluePlus.stopScan();

      for (final d in bleDevices) {
        devices.add({
          'id': 'ble:${d.remoteId}',
          'type': 'ble',
          'name': d.platformName.isNotEmpty ? d.platformName : 'BLE Device',
        });
      }
    } catch (_) {}

    return NodeFrame.response('', payload: {'devices': devices});
  }

  Future<NodeFrame> _connect(Map<String, dynamic> params) async {
    final deviceId = params['deviceId'] as String?;
    if (deviceId == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'deviceId is required',
      });
    }

    if (_connections.containsKey(deviceId)) {
      return NodeFrame.response('', payload: {
        'status': 'already_connected',
        'deviceId': deviceId,
      });
    }

    try {
      if (deviceId.startsWith('usb:')) {
        final usbId = int.tryParse(deviceId.substring(4));
        final usbDevices = await UsbSerial.listDevices();
        final device = usbDevices.firstWhere(
          (d) => d.deviceId == usbId,
          orElse: () => throw Exception('USB device not found'),
        );
        final port = await device.create();
        if (port == null) throw Exception('Failed to create USB port');
        final opened = await port.open();
        if (!opened) throw Exception('Failed to open USB port');

        final baudRate = params['baudRate'] as int? ?? 115200;
        await port.setDTR(true);
        await port.setRTS(true);
        await port.setPortParameters(
          baudRate,
          UsbPort.DATABITS_8,
          UsbPort.STOPBITS_1,
          UsbPort.PARITY_NONE,
        );

        _connections[deviceId] = _SerialConnection.usb(port);
        return NodeFrame.response('', payload: {
          'status': 'connected',
          'deviceId': deviceId,
          'type': 'usb',
          'baudRate': baudRate,
        });
      } else if (deviceId.startsWith('ble:')) {
        final remoteId = deviceId.substring(4);
        final device = BluetoothDevice.fromId(remoteId);
        await device.connect(timeout: const Duration(seconds: 10));
        final services = await device.discoverServices();

        BluetoothCharacteristic? txChar;
        BluetoothCharacteristic? rxChar;

        for (final service in services) {
          if (service.uuid.toString().toLowerCase() == _nusServiceUuid) {
            for (final c in service.characteristics) {
              final uuid = c.uuid.toString().toLowerCase();
              if (uuid == _nusTxCharUuid) txChar = c;
              if (uuid == _nusRxCharUuid) rxChar = c;
            }
          }
        }

        if (txChar != null) {
          await txChar.setNotifyValue(true);
        }

        _connections[deviceId] = _SerialConnection.ble(device, txChar, rxChar);
        return NodeFrame.response('', payload: {
          'status': 'connected',
          'deviceId': deviceId,
          'type': 'ble',
          'hasNus': txChar != null && rxChar != null,
        });
      }

      return NodeFrame.response('', error: {
        'code': 'INVALID_DEVICE_ID',
        'message': 'deviceId must start with usb: or ble:',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CONNECT_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _disconnect(Map<String, dynamic> params) async {
    final deviceId = params['deviceId'] as String?;
    if (deviceId == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'deviceId is required',
      });
    }

    final conn = _connections.remove(deviceId);
    if (conn == null) {
      return NodeFrame.response('', payload: {
        'status': 'not_connected',
        'deviceId': deviceId,
      });
    }

    try {
      await conn.close();
    } catch (_) {}

    return NodeFrame.response('', payload: {
      'status': 'disconnected',
      'deviceId': deviceId,
    });
  }

  Future<NodeFrame> _write(Map<String, dynamic> params) async {
    final deviceId = params['deviceId'] as String?;
    final data = params['data'] as String?;
    if (deviceId == null || data == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'deviceId and data are required',
      });
    }

    final conn = _connections[deviceId];
    if (conn == null) {
      return NodeFrame.response('', error: {
        'code': 'NOT_CONNECTED',
        'message': 'Device not connected: $deviceId',
      });
    }

    try {
      final bytes = utf8.encode(data);
      await conn.write(Uint8List.fromList(bytes));
      return NodeFrame.response('', payload: {
        'status': 'written',
        'deviceId': deviceId,
        'bytesWritten': bytes.length,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'WRITE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _read(Map<String, dynamic> params) async {
    final deviceId = params['deviceId'] as String?;
    if (deviceId == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'deviceId is required',
      });
    }

    final conn = _connections[deviceId];
    if (conn == null) {
      return NodeFrame.response('', error: {
        'code': 'NOT_CONNECTED',
        'message': 'Device not connected: $deviceId',
      });
    }

    try {
      final timeoutMs = params['timeoutMs'] as int? ?? 2000;
      final data = await conn.read(Duration(milliseconds: timeoutMs));
      return NodeFrame.response('', payload: {
        'deviceId': deviceId,
        'data': data != null ? utf8.decode(data, allowMalformed: true) : null,
        'bytesRead': data?.length ?? 0,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'READ_ERROR',
        'message': '$e',
      });
    }
  }

  void dispose() {
    for (final conn in _connections.values) {
      try { conn.close(); } catch (_) {}
    }
    _connections.clear();
  }
}

class _SerialConnection {
  final UsbPort? usbPort;
  final BluetoothDevice? bleDevice;
  final BluetoothCharacteristic? bleTxChar;
  final BluetoothCharacteristic? bleRxChar;
  final List<int> _bleBuffer = [];
  StreamSubscription? _bleSubscription;

  _SerialConnection.usb(this.usbPort)
      : bleDevice = null,
        bleTxChar = null,
        bleRxChar = null;

  _SerialConnection.ble(this.bleDevice, this.bleTxChar, this.bleRxChar)
      : usbPort = null {
    if (bleTxChar != null) {
      _bleSubscription = bleTxChar!.onValueReceived.listen((data) {
        _bleBuffer.addAll(data);
      });
    }
  }

  Future<void> write(Uint8List data) async {
    if (usbPort != null) {
      await usbPort!.write(data);
    } else if (bleRxChar != null) {
      // BLE has MTU limits, send in chunks
      const mtu = 20;
      for (var i = 0; i < data.length; i += mtu) {
        final end = (i + mtu < data.length) ? i + mtu : data.length;
        await bleRxChar!.write(data.sublist(i, end), withoutResponse: true);
      }
    } else {
      throw Exception('No writable channel');
    }
  }

  Future<Uint8List?> read(Duration timeout) async {
    if (usbPort != null) {
      // Read from USB input stream with timeout
      final completer = Completer<Uint8List?>();
      StreamSubscription? sub;
      Timer? timer;
      sub = usbPort!.inputStream?.listen((data) {
        timer?.cancel();
        sub?.cancel();
        completer.complete(Uint8List.fromList(data));
      });
      timer = Timer(timeout, () {
        sub?.cancel();
        completer.complete(null);
      });
      return completer.future;
    } else if (bleTxChar != null) {
      // Return buffered BLE data or wait
      if (_bleBuffer.isNotEmpty) {
        final data = Uint8List.fromList(_bleBuffer);
        _bleBuffer.clear();
        return data;
      }
      // Wait for data with timeout
      final completer = Completer<Uint8List?>();
      late StreamSubscription sub;
      Timer? timer;
      sub = bleTxChar!.onValueReceived.listen((data) {
        timer?.cancel();
        sub.cancel();
        completer.complete(Uint8List.fromList(data));
      });
      timer = Timer(timeout, () {
        sub.cancel();
        completer.complete(null);
      });
      return completer.future;
    }
    return null;
  }

  Future<void> close() async {
    _bleSubscription?.cancel();
    if (usbPort != null) {
      await usbPort!.close();
    }
    if (bleDevice != null) {
      await bleDevice!.disconnect();
    }
  }
}
