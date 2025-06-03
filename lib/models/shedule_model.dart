import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'shedule_model.g.dart';

@HiveType(typeId: 3)
class ScheduleModel {
  @HiveField(0)
  TimeOfDay? onTime;

  @HiveField(1)
  TimeOfDay? offTime;

  @HiveField(2)
  bool onTriggered;

  @HiveField(3)
  bool offTriggered;

  ScheduleModel({
    this.onTime,
    this.offTime,
    this.onTriggered = false,
    this.offTriggered = false,
  });

  Map<String, dynamic> toJson() => {
    'onTime': onTime != null ? '${onTime!.hour}:${onTime!.minute}' : null,
    'offTime': offTime != null ? '${offTime!.hour}:${offTime!.minute}' : null,
    'onTriggered': onTriggered,
    'offTriggered': offTriggered,
  };

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      onTime:
          json['onTime'] != null
              ? TimeOfDay(
                hour: int.parse(json['onTime'].split(':')[0]),
                minute: int.parse(json['onTime'].split(':')[1]),
              )
              : null,
      offTime:
          json['offTime'] != null
              ? TimeOfDay(
                hour: int.parse(json['offTime'].split(':')[0]),
                minute: int.parse(json['offTime'].split(':')[1]),
              )
              : null,
      onTriggered: json['onTriggered'] ?? false,
      offTriggered: json['offTriggered'] ?? false,
    );
  }
}
