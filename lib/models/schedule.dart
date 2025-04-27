// lib/models/schedule.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Schedule {
  final String id;
  final String name;
  final String time; // stored as HH:MM in 24-hour format
  final List<String> days; // ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] or ['Every day']
  final bool isActive;
  final String action; // 'on' or 'off'
  final List<ScheduleTarget> targets;

  Schedule({
    required this.id,
    required this.name,
    required this.time,
    required this.days,
    required this.isActive,
    required this.action,
    required this.targets,
  });

  factory Schedule.fromMap(Map<String, dynamic> map, String id) {
    return Schedule(
      id: id,
      name: map['name'] ?? '',
      time: map['time'] ?? '00:00',
      days: List<String>.from(map['days'] ?? []),
      isActive: map['isActive'] ?? false,
      action: map['action'] ?? 'on',
      targets: (map['targets'] as List?)
              ?.map((target) => ScheduleTarget.fromMap(target))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'time': time,
      'days': days,
      'isActive': isActive,
      'action': action,
      'targets': targets.map((t) => t.toMap()).toList(),
    };
  }

  // Check if this schedule should run today
  bool shouldRunToday(DateTime now) {
    if (days.contains('Every day')) {
      return true;
    }
    
    String today = _weekdayName(now.weekday);
    return days.contains(today);
  }

  // Convert datetime weekday to string name
  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  // Format time for display (12-hour format)
  String get formattedTime {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return time;
      
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      String period = hour >= 12 ? 'PM' : 'AM';
      
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      
      return '$hour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time;
    }
  }

  // Get formatted days for display
  String get formattedDays {
    if (days.contains('Every day')) {
      return 'Every day';
    } else {
      return days.join(', ');
    }
  }

  // Return a copy of this schedule with modified properties
  Schedule copyWith({
    String? name,
    String? time,
    List<String>? days,
    bool? isActive,
    String? action,
    List<ScheduleTarget>? targets,
  }) {
    return Schedule(
      id: id,
      name: name ?? this.name,
      time: time ?? this.time,
      days: days ?? this.days,
      isActive: isActive ?? this.isActive,
      action: action ?? this.action,
      targets: targets ?? this.targets,
    );
  }
}

class ScheduleTarget {
  final String roomId;
  final String? roomName; // Optional for display
  final String lightId;
  final String? lightName; // Optional for display
  final bool? allLightsInRoom; // If true, target all lights in room

  ScheduleTarget({
    required this.roomId,
    this.roomName,
    required this.lightId,
    this.lightName,
    this.allLightsInRoom = false,
  });

  factory ScheduleTarget.fromMap(Map<String, dynamic> map) {
    return ScheduleTarget(
      roomId: map['roomId'] ?? '',
      roomName: map['roomName'],
      lightId: map['lightId'] ?? '',
      lightName: map['lightName'],
      allLightsInRoom: map['allLightsInRoom'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'lightId': lightId,
      'lightName': lightName,
      'allLightsInRoom': allLightsInRoom,
    };
  }
}