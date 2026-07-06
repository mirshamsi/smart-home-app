// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motion_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MotionModelAdapter extends TypeAdapter<MotionModel> {
  @override
  final int typeId = 5;

  @override
  MotionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MotionModel(
      deviceId: fields[0] as String,
      relayMode: fields[1] as String,
      lastDetection: fields[2] as DateTime,
      isActive: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MotionModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.relayMode)
      ..writeByte(2)
      ..write(obj.lastDetection)
      ..writeByte(3)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MotionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
