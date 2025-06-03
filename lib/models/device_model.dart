import 'package:hive/hive.dart';

part 'device_model.g.dart';

@HiveType(typeId: 0)
class DeviceModel {
  @HiveField(0)
  final String deviceId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String image;

  @HiveField(3)
  final String poleCount;

  @HiveField(4)
  final String deviceInfo;

  DeviceModel({
    required this.deviceId,
    required this.name,
    required this.image,
    required this.poleCount,
    required this.deviceInfo,
  });

  Map<String, String> toMap() {
    return {
      'deviceId': deviceId,
      'name': name,
      'image': image,
      'poleCount': poleCount,
      'deviceInfo': deviceInfo,
    };
  }

  factory DeviceModel.fromMap(Map<String, String> map) {
    return DeviceModel(
      deviceId: map['deviceId'] ?? '',
      name: map['name'] ?? '',
      image: map['image'] ?? '',
      poleCount: map['poleCount'] ?? '0',
      deviceInfo: map['deviceInfo'] ?? '',
    );
  }
}

@HiveType(typeId: 1)
class ButtonStateModel {
  @HiveField(0)
  final String deviceId;

  @HiveField(1)
  final Map<int, bool> states;

  ButtonStateModel({required this.deviceId, required this.states});
}

@HiveType(typeId: 2)
class PacketNumberModel {
  @HiveField(0)
  final String deviceId;

  @HiveField(1)
  final Map<int, int> packetNumbers;

  PacketNumberModel({required this.deviceId, required this.packetNumbers});
}
