// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'temperature_humidity_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemperatureHumidityModelAdapter
    extends TypeAdapter<TemperatureHumidityModel> {
  @override
  final int typeId = 4;

  @override
  TemperatureHumidityModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemperatureHumidityModel(
      deviceId: fields[0] as String,
      temperature: fields[1] as double,
      humidity: fields[2] as double,
      lastUpdate: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TemperatureHumidityModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.temperature)
      ..writeByte(2)
      ..write(obj.humidity)
      ..writeByte(3)
      ..write(obj.lastUpdate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperatureHumidityModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
