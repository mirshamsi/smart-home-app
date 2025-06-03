import 'package:hive/hive.dart';

part 'device.g.dart';

@HiveType(typeId: 0)
class Device extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  bool status;

  @HiveField(3)
  final int relayCount; // تعداد پل‌ها (1پل، 2پل، 3پل، 4پل)

  Device({
    required this.id,
    required this.name,
    this.status = false,
    required this.relayCount,
  });
}
