import 'package:hive/hive.dart';

part 'motion_model.g.dart';

@HiveType(typeId: 5)
class MotionModel extends HiveObject {
  @HiveField(0)
  final String deviceId;

  @HiveField(1)
  final String relayMode;

  @HiveField(2)
  final DateTime lastDetection;

  @HiveField(3)
  final bool isActive;

  MotionModel({
    required this.deviceId,
    required this.relayMode,
    required this.lastDetection,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'relayMode': relayMode,
      'lastDetection': lastDetection.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory MotionModel.fromJson(Map<String, dynamic> json) {
    return MotionModel(
      deviceId: json['deviceId'],
      relayMode: json['relayMode'],
      lastDetection: DateTime.parse(json['lastDetection']),
      isActive: json['isActive'] ?? true,
    );
  }

  // برای نمایش زمان به صورت خوانا
  String getFormattedTime() {
    // final now = DateTime.now();
    // final difference = now.difference(lastDetection);

    // if (difference.inSeconds < 60) {
    //   return 'لحظاتی پیش';
    // } else if (difference.inMinutes < 60) {
    //   return '${difference.inMinutes} دقیقه پیش';
    // } else if (difference.inHours < 24) {
    //   return '${difference.inHours} ساعت پیش';
    // } else {
    //   return '${difference.inDays} روز پیش';
    // }

    final date = lastDetection;
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    return '$year/$month/$day - $hour:$minute:$second';
  }
}
