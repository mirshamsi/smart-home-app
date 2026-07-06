import 'package:hive/hive.dart';

part 'temperature_humidity_model.g.dart';

@HiveType(typeId: 4)
class TemperatureHumidityModel extends HiveObject {
  @HiveField(0)
  final String deviceId;

  @HiveField(1)
  final double temperature;

  @HiveField(2)
  final double humidity;

  @HiveField(3)
  final DateTime lastUpdate;

  TemperatureHumidityModel({
    required this.deviceId,
    required this.temperature,
    required this.humidity,
    required this.lastUpdate,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'temperature': temperature,
      'humidity': humidity,
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }

  factory TemperatureHumidityModel.fromJson(Map<String, dynamic> json) {
    return TemperatureHumidityModel(
      deviceId: json['deviceId'],
      temperature: json['temperature'],
      humidity: json['humidity'],
      lastUpdate: DateTime.parse(json['lastUpdate']),
    );
  }
}
