import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:topaz/models/device_model.dart';

class DeviceProvider with ChangeNotifier {
  Map<String, List<DeviceModel>> _devicesByItem = {};
  Map<String, Map<int, String>> _buttonStates = {};
  Map<String, Map<int, int>> _lastPacketNumbers = {};

  List<Map<String, String>> getDevices(String itemName) =>
      _devicesByItem[itemName]?.map((device) => device.toMap()).toList() ?? [];

  Map<int, String> getButtonStates(String deviceId) =>
      _buttonStates[deviceId] ?? {};

  int getTotalDevices() =>
      _devicesByItem.values.fold(0, (sum, list) => sum + list.length);

  void syncStateFromMessage(String message, String deviceId) {
    try {
      RegExp regex = RegExp(r"#(\d+)A(\d+)B(\d+)C(\d+)D([^E]+)E(\d+)F");
      Match? match = regex.firstMatch(message);

      if (match != null && match.group(5) == deviceId) {
        String stateString = match.group(1)!;
        updateButtonStatesFromString(deviceId, stateString);
      }
    } catch (e) {
      debugPrint("Error parsing message: $e");
    }
  }

  void updateButtonStatesFromString(String deviceId, String stateString) {
    _buttonStates[deviceId] ??= {};
    for (int i = 0; i < stateString.length; i++) {
      int relayNumber = i + 1;
      String state =
          stateString[stateString.length -
              1 -
              i]; // Reverse to match poles (1st digit = relay 1)
      _buttonStates[deviceId]![relayNumber] = state; // Store "0" or "1"
    }
    _saveButtonStatesToHive(deviceId);
    notifyListeners();
  }

  void addDevice(Map<String, String> device, String itemName) {
    final deviceModel = DeviceModel.fromMap(device);
    if (!_devicesByItem.containsKey(itemName)) {
      _devicesByItem[itemName] = [];
    }

    // بررسی تکراری نبودن دستگاه
    bool deviceExists = _devicesByItem[itemName]!.any(
      (d) => d.deviceId == deviceModel.deviceId,
    );

    if (!deviceExists) {
      _devicesByItem[itemName]!.add(deviceModel);
      _saveDevicesToHive(itemName);
      debugPrint(
        "Device added: ${deviceModel.name} with ID ${deviceModel.deviceId}",
      );
      notifyListeners();
    } else {
      debugPrint("Device with ID ${deviceModel.deviceId} already exists");
    }
  }

  bool addDeviceManually(String deviceId, String deviceInfo, String itemName) {
    // بررسی تکراری نبودن Device ID
    bool deviceExists =
        _devicesByItem[itemName]?.any(
          (device) => device.deviceId == deviceId,
        ) ??
        false;

    if (deviceExists) {
      debugPrint("Device with ID $deviceId already exists");
      return false;
    }

    // تعیین اطلاعات دستگاه بر اساس deviceInfo
    Map<String, String> deviceData = _createDeviceData(deviceId, deviceInfo);

    // افزودن دستگاه
    addDevice(deviceData, itemName);
    return true;
  }

  Map<String, String> _createDeviceData(String deviceId, String deviceInfo) {
    String deviceName;
    String deviceImage;
    Map<String, String> deviceData;

    // سنسورها و دستگاه‌های ویژه
    if (["12", "13", "14", "11", "5", "9", "7"].contains(deviceInfo)) {
      switch (deviceInfo) {
        case "12":
          deviceName = "تشخیص حرکت";
          deviceImage = "assets/motion-sensor.png";
          break;
        case "13":
          deviceName = "سنسور دود";
          deviceImage = "assets/smoke-sensor.png";
          break;
        case "14":
          deviceName = "سنسور در و پنجره";
          deviceImage = "assets/door-window-sensor.png";
          break;
        case "11":
          deviceName = "سنسور دما و رطوبت";
          deviceImage = "assets/temp-humidity-sensor.jpg";
          break;
        case "5":
          deviceName = "سر لامپی";
          deviceImage = "assets/lamp-head.png";
          break;
        case "9":
          deviceName = "هاب IR";
          deviceImage = "assets/unknown-device.png";
          break;
        case "7":
          deviceName = "هاب اصلی";
          deviceImage = "assets/unknown-device.png";
          break;
        default:
          deviceName = "دستگاه ناشناخته";
          deviceImage = "assets/unknown-device.png";
          break;
      }
      deviceData = {
        "name": deviceName,
        "deviceId": deviceId,
        "image": deviceImage,
        "deviceInfo": deviceInfo,
      };
    } else {
      // کلیدهای لمسی
      int poleCount = 0;
      switch (deviceInfo) {
        case "66":
          deviceName = "کلید لمسی 6 پل";
          deviceImage = "assets/6-pol.png";
          poleCount = 6;
          break;
        case "64":
          deviceName = "کلید لمسی 4 پل";
          deviceImage = "assets/4-pol.png";
          poleCount = 4;
          break;
        case "63":
          deviceName = "کلید لمسی 3 پل";
          deviceImage = "assets/3-pol.png";
          poleCount = 3;
          break;
        case "62":
          deviceName = "کلید لمسی 2 پل";
          deviceImage = "assets/2-pol.png";
          poleCount = 2;
          break;
        case "61":
          deviceName = "کلید لمسی 1 پل";
          deviceImage = "assets/1-pol.png";
          poleCount = 1;
          break;
        default:
          deviceName = "دستگاه ناشناخته";
          deviceImage = "assets/1-pol.png";
          poleCount = 1;
          break;
      }
      deviceData = {
        "name": deviceName,
        "deviceId": deviceId,
        "image": deviceImage,
        "poleCount": poleCount.toString(),
        "deviceInfo": deviceInfo,
      };
    }

    return deviceData;
  }

  Future<void> _deleteButtonStatesFromHive(String deviceId) async {
    final box = await Hive.openBox<ButtonStateModel>('buttonStates');
    await box.delete('relayStatus_$deviceId');
  }

  Future<void> _deletePacketNumbersFromHive(String deviceId) async {
    final box = await Hive.openBox<PacketNumberModel>('packetNumbers');
    await box.delete('packetNumbers_$deviceId');
  }

  void removeDevice(String deviceId, String itemName) {
    if (_devicesByItem.containsKey(itemName)) {
      _devicesByItem[itemName]!.removeWhere(
        (device) => device.deviceId == deviceId,
      );
      _buttonStates.remove(deviceId);
      _lastPacketNumbers.remove(deviceId);

      // Remove from Hive
      _saveDevicesToHive(itemName);
      _deleteButtonStatesFromHive(deviceId);
      _deletePacketNumbersFromHive(deviceId);

      notifyListeners();
    }
  }

  void updateButtonState(String deviceId, int relayNumber, String state) {
    _buttonStates[deviceId] ??= {};
    _buttonStates[deviceId]![relayNumber] = state; // Store "0" or "1"
    _saveButtonStatesToHive(deviceId);
    notifyListeners();
  }

  int getLastPacketNumber(String deviceId, int relayNumber) {
    _lastPacketNumbers[deviceId] ??= {};
    return _lastPacketNumbers[deviceId]![relayNumber] ?? 0;
  }

  void updateLastPacketNumber(
    String deviceId,
    int relayNumber,
    int packetNumber,
  ) {
    _lastPacketNumbers[deviceId] ??= {};
    _lastPacketNumbers[deviceId]![relayNumber] = packetNumber;
    _savePacketNumbersToHive(deviceId);
    notifyListeners();
  }

  Future<void> loadDevicesFromHive(String itemName) async {
    final box = await Hive.openBox<List>('devices');
    final devices = box
        .get('devices_$itemName', defaultValue: [])
        ?.cast<DeviceModel>();
    _devicesByItem[itemName] = devices ?? [];
    notifyListeners();
  }

  Future<void> loadButtonStatesFromHive(String deviceId) async {
    final box = await Hive.openBox<ButtonStateModel>('buttonStates');
    final buttonState = box.get('relayStatus_$deviceId');
    if (buttonState != null) {
      _buttonStates[deviceId] = buttonState.states;
      notifyListeners();
    }
  }

  Future<void> loadPacketNumbersFromHive(String deviceId) async {
    final box = await Hive.openBox<PacketNumberModel>('packetNumbers');
    final packetNumbers = box.get('packetNumbers_$deviceId');
    if (packetNumbers != null) {
      _lastPacketNumbers[deviceId] = packetNumbers.packetNumbers;
      notifyListeners();
    }
  }

  Future<void> _saveDevicesToHive(String itemName) async {
    final box = await Hive.openBox<List>('devices');
    await box.put('devices_$itemName', _devicesByItem[itemName]!);
  }

  Future<void> _saveButtonStatesToHive(String deviceId) async {
    final box = await Hive.openBox<ButtonStateModel>('buttonStates');
    await box.put(
      'relayStatus_$deviceId',
      ButtonStateModel(deviceId: deviceId, states: _buttonStates[deviceId]!),
    );
  }

  Future<void> _savePacketNumbersToHive(String deviceId) async {
    final box = await Hive.openBox<PacketNumberModel>('packetNumbers');
    await box.put(
      'packetNumbers_$deviceId',
      PacketNumberModel(
        deviceId: deviceId,
        packetNumbers: _lastPacketNumbers[deviceId]!,
      ),
    );
  }

  Map<String, String> getDeviceById(String deviceId, String itemName) {
    final devices = _devicesByItem[itemName] ?? [];
    return devices
        .firstWhere(
          (device) => device.deviceId == deviceId,
          orElse: () => DeviceModel(
            deviceId: '',
            name: '',
            image: '',
            poleCount: '0',
            deviceInfo: '',
          ),
        )
        .toMap();
  }

  bool deviceExists(String deviceId, String itemName) {
    return _devicesByItem[itemName]?.any(
          (device) => device.deviceId == deviceId,
        ) ??
        false;
  }

  int getDeviceCountForItem(String itemName) {
    return _devicesByItem[itemName]?.length ?? 0;
  }

  void clearAllDevices(String itemName) {
    if (_devicesByItem.containsKey(itemName)) {
      
      for (var device in _devicesByItem[itemName]!) {
        _buttonStates.remove(device.deviceId);
        _lastPacketNumbers.remove(device.deviceId);
        _deleteButtonStatesFromHive(device.deviceId);
        _deletePacketNumbersFromHive(device.deviceId);
      }
      
      _devicesByItem[itemName]!.clear();
      _saveDevicesToHive(itemName);
      debugPrint("Cleared all devices for $itemName");
      notifyListeners();
    }
  }
}

class ButtonStateModel {
  final String deviceId;
  final Map<int, String> states;

  ButtonStateModel({required this.deviceId, required this.states});

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'states': states.map((key, value) => MapEntry(key.toString(), value)),
    };
  }

  factory ButtonStateModel.fromJson(Map<String, dynamic> json) {
    return ButtonStateModel(
      deviceId: json['deviceId'],
      states: (json['states'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(int.parse(key), value.toString()),
      ),
    );
  }
}

class PacketNumberModel {
  final String deviceId;
  final Map<int, int> packetNumbers;

  PacketNumberModel({required this.deviceId, required this.packetNumbers});

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'packetNumbers': packetNumbers.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    };
  }

  factory PacketNumberModel.fromJson(Map<String, dynamic> json) {
    return PacketNumberModel(
      deviceId: json['deviceId'],
      packetNumbers: (json['packetNumbers'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(int.parse(key), value as int),
      ),
    );
  }
}
