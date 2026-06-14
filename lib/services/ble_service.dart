import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Holds the latest sensor snapshot from the ESP32.
class Esp32SensorData {
  final double temp;
  final double hum;
  final int soil;

  const Esp32SensorData({
    required this.temp,
    required this.hum,
    required this.soil,
  });

  factory Esp32SensorData.fromJson(Map<String, dynamic> json) {
    return Esp32SensorData(
      temp: (json['temp'] as num).toDouble(),
      hum: (json['hum'] as num).toDouble(),
      soil: (json['soil'] as num).toInt(),
    );
  }
}

enum BleStatus { idle, scanning, connecting, connected, error }

class BleService {
  static const _deviceName = 'Farm_Condition_Sensor';
  static const _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const _characteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  // ── Public streams ──────────────────────────────────────────────────────────
  final _dataController = StreamController<Esp32SensorData>.broadcast();
  final _statusController = StreamController<BleStatus>.broadcast();

  Stream<Esp32SensorData> get dataStream => _dataController.stream;
  Stream<BleStatus> get statusStream => _statusController.stream;

  BleStatus _status = BleStatus.idle;
  BleStatus get status => _status;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _char;
  StreamSubscription? _notifySub;
  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;

  // ── Connect ─────────────────────────────────────────────────────────────────
  Future<void> connect() async {
    if (_status == BleStatus.scanning || _status == BleStatus.connecting) return;

    _emit(BleStatus.scanning);

    try {
      // Make sure BT is on
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint("BLE Error: Bluetooth adapter is not ON (state: $adapterState)");
        _emit(BleStatus.error);
        return;
      }

      // 1. Check devices already connected to our app
      final connected = FlutterBluePlus.connectedDevices;
      for (var dev in connected) {
        final name = dev.platformName.isNotEmpty ? dev.platformName : dev.advName;
        if (name == _deviceName) {
          debugPrint("BLE: Found already connected device matching $_deviceName");
          await _connectToDevice(dev);
          return;
        }
      }

      // 2. Check devices connected to the system (OS level)
      try {
        final systemDevs = await FlutterBluePlus.systemDevices([Guid(_serviceUuid)]);
        for (var dev in systemDevs) {
          final name = dev.platformName.isNotEmpty ? dev.platformName : dev.advName;
          if (name == _deviceName) {
            debugPrint("BLE: Found system connected device matching $_deviceName");
            await _connectToDevice(dev);
            return;
          }
        }
      } catch (e) {
        debugPrint("BLE Warning: Failed to retrieve system connected devices: $e");
      }

      // 3. Scan for the device
      debugPrint("BLE: Starting scan for $_deviceName...");
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      _scanSub = FlutterBluePlus.onScanResults.listen((results) async {
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;

          final hasService = r.advertisementData.serviceUuids.any(
            (uuid) => uuid.toString().toLowerCase() == _serviceUuid.toLowerCase(),
          );

          if (name == _deviceName || hasService) {
            debugPrint("BLE: Found matching device: $name (${r.device.remoteId})");
            await FlutterBluePlus.stopScan();
            await _scanSub?.cancel();
            await _connectToDevice(r.device);
            break;
          }
        }
      });

      // Wait for scanning to stop (either timeout or manually stopped)
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      if (_status == BleStatus.scanning) {
        debugPrint("BLE Scan timed out without finding $_deviceName");
        _emit(BleStatus.error);
      }
    } catch (e) {
      debugPrint("BLE Connection Error: $e");
      _emit(BleStatus.error);
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _emit(BleStatus.connecting);
    _device = device;

    try {
      debugPrint("BLE: Connecting to device ${device.remoteId}...");
      await device.connect(timeout: const Duration(seconds: 10));

      _connSub = device.connectionState.listen((state) {
        debugPrint("BLE Connection State: $state");
        if (state == BluetoothConnectionState.disconnected) {
          _emit(BleStatus.idle);
          _notifySub?.cancel();
        }
      });

      debugPrint("BLE: Discovering services...");
      final services = await device.discoverServices();
      final targetServiceUuid = Guid(_serviceUuid);
      final targetCharUuid = Guid(_characteristicUuid);

      for (final svc in services) {
        if (svc.uuid == targetServiceUuid) {
          for (final char in svc.characteristics) {
            if (char.uuid == targetCharUuid) {
              _char = char;
              debugPrint("BLE: Found characteristic $targetCharUuid, subscribing to notifications...");
              await char.setNotifyValue(true);
              _notifySub = char.onValueReceived.listen(_onData);
              _emit(BleStatus.connected);
              return;
            }
          }
        }
      }
      debugPrint("BLE Error: Target service/characteristic not found on device");
      _emit(BleStatus.error);
    } catch (e) {
      debugPrint("BLE Exception in _connectToDevice: $e");
      _emit(BleStatus.error);
    }
  }

  void _onData(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final data = Esp32SensorData.fromJson(json);
      _dataController.add(data);
    } catch (_) {
      // Malformed packet – ignore
    }
  }

  // ── Disconnect ───────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _scanSub?.cancel();
    await _connSub?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _char = null;
    _emit(BleStatus.idle);
  }

  void _emit(BleStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _statusController.close();
  }
}
