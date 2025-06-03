// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 1;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      rawMessage: fields[0] as String,
      status: fields[1] as bool,
      relayNumber: fields[2] as int,
      deviceName: fields[3] as String,
      sourceId: fields[4] as String,
      destinationId: fields[5] as String,
      packetNumber: fields[6] as String,
      timestamp: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.rawMessage)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.relayNumber)
      ..writeByte(3)
      ..write(obj.deviceName)
      ..writeByte(4)
      ..write(obj.sourceId)
      ..writeByte(5)
      ..write(obj.destinationId)
      ..writeByte(6)
      ..write(obj.packetNumber)
      ..writeByte(7)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
