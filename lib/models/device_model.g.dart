// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeviceModelAdapter extends TypeAdapter<DeviceModel> {
  @override
  final int typeId = 0;

  @override
  DeviceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeviceModel(
      deviceId: fields[0] as String,
      name: fields[1] as String,
      image: fields[2] as String,
      poleCount: fields[3] as String,
      deviceInfo: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DeviceModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.image)
      ..writeByte(3)
      ..write(obj.poleCount)
      ..writeByte(4)
      ..write(obj.deviceInfo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ButtonStateModelAdapter extends TypeAdapter<ButtonStateModel> {
  @override
  final int typeId = 1;

  @override
  ButtonStateModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ButtonStateModel(
      deviceId: fields[0] as String,
      states: (fields[1] as Map).cast<int, bool>(),
    );
  }

  @override
  void write(BinaryWriter writer, ButtonStateModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.states);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ButtonStateModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PacketNumberModelAdapter extends TypeAdapter<PacketNumberModel> {
  @override
  final int typeId = 2;

  @override
  PacketNumberModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PacketNumberModel(
      deviceId: fields[0] as String,
      packetNumbers: (fields[1] as Map).cast<int, int>(),
    );
  }

  @override
  void write(BinaryWriter writer, PacketNumberModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.packetNumbers);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PacketNumberModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
