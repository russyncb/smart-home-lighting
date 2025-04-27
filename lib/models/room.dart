// lib/models/room.dart
enum RoomType { indoor, outdoor }

class Room {
  final String id;
  final String name;
  final RoomType type;
  final List<Light> lights;

  Room({
    required this.id,
    required this.name,
    required this.type,
    required this.lights,
  });

  factory Room.fromMap(Map<String, dynamic> map, String id) {
    return Room(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] == 'indoor' ? RoomType.indoor : RoomType.outdoor,
      lights: (map['lights'] as List?)
              ?.map((light) => Light.fromMap(light))
              .toList() ??
          [],
    );
  }
}

class Light {
  final String id;
  final String name;
  final bool isOn;
  final int brightness;
  final bool hasSchedule;
  final String? onTime;
  final String? offTime;
  final bool hasMotionSensor;
  final bool motionSensorActive;

  Light({
    required this.id,
    required this.name,
    required this.isOn,
    required this.brightness,
    this.hasSchedule = false,
    this.onTime,
    this.offTime,
    this.hasMotionSensor = false,
    this.motionSensorActive = false,
  });

  factory Light.fromMap(Map<String, dynamic> map) {
    return Light(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      isOn: map['isOn'] ?? false,
      brightness: map['brightness'] ?? 100,
      hasSchedule: map['hasSchedule'] ?? false,
      onTime: map['onTime'],
      offTime: map['offTime'],
      hasMotionSensor: map['hasMotionSensor'] ?? false,
      motionSensorActive: map['motionSensorActive'] ?? false,
    );
  }
}