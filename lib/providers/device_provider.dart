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
        String stateString = match.group(1)!; // e.g., "1001" for 4-pole
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
    if (!_devicesByItem[itemName]!.any(
      (d) => d.deviceId == deviceModel.deviceId,
    )) {
      _devicesByItem[itemName]!.add(deviceModel);
      _saveDevicesToHive(itemName);
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
