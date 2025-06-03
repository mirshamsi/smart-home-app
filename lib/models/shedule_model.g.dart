// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shedule_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduleModelAdapter extends TypeAdapter<ScheduleModel> {
  @override
  final int typeId = 3;

  @override
  ScheduleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduleModel(
      onTime: fields[0] as TimeOfDay?,
      offTime: fields[1] as TimeOfDay?,
      onTriggered: fields[2] as bool,
      offTriggered: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.onTime)
      ..writeByte(1)
      ..write(obj.offTime)
      ..writeByte(2)
      ..write(obj.onTriggered)
      ..writeByte(3)
      ..write(obj.offTriggered);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
