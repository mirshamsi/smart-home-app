import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  final String rawMessage;

  @HiveField(1)
  final bool status; // روشن/خاموش

  @HiveField(2)
  final int relayNumber; // شماره رله

  @HiveField(3)
  final String deviceName; // نام دستگاه (مثلاً کلید 6، 4پل)

  @HiveField(4)
  final String sourceId; // آی‌دی مبدا

  @HiveField(5)
  final String destinationId; // آی‌دی مقصد

  @HiveField(6)
  final String packetNumber; // شماره بسته

  @HiveField(7)
  final DateTime timestamp;

  Message({
    required this.rawMessage,
    required this.status,
    required this.relayNumber,
    required this.deviceName,
    required this.sourceId,
    required this.destinationId,
    required this.packetNumber,
    required this.timestamp,
  });
}