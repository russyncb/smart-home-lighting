// lib/widgets/room_card.dart
import 'package:flutter/material.dart';
import 'package:illumi_home/models/room.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  final VoidCallback? onLongPress; // New callback for long press

  const RoomCard({
    Key? key,
    required this.room,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);

  String _getRoomIcon(String roomName) {
    final name = roomName.toLowerCase();
    if (name.contains('kitchen')) return '🍳';
    if (name.contains('bedroom')) return '🛏️';
    if (name.contains('dining')) return '🍽️';
    if (name.contains('entrance')) return '🚪';
    if (name.contains('back')) return '🏡';
    if (name.contains('left')) return '🌳';
    if (name.contains('right')) return '🌲';
    return '💡';
  }

  Color _getRoomColor(String roomName) {
    final name = roomName.toLowerCase();
    if (name.contains('kitchen')) return Colors.green;
    if (name.contains('bedroom')) return Colors.purple;
    if (name.contains('dining')) return Colors.orange;
    if (name.contains('entrance')) return Colors.blue;
    if (name.contains('back')) return Colors.teal;
    if (name.contains('left')) return Colors.indigo;
    if (name.contains('right')) return Colors.amber;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final activeLights = room.lights.where((light) => light.isOn).length;
    final roomColor = _getRoomColor(room.name);
    
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress, // Added support for long press
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room header with icon and lights count
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: roomColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getRoomIcon(room.name),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: activeLights > 0
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$activeLights/${room.lights.length}',
                          style: TextStyle(
                            color: activeLights > 0 ? Colors.amber : Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activeLights == 0
                        ? 'All lights off'
                        : activeLights == room.lights.length
                            ? 'All lights on'
                            : '$activeLights light${activeLights == 1 ? '' : 's'} on',
                    style: TextStyle(
                      color: activeLights > 0 ? Colors.amber.shade400 : Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Light indicators
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  ...room.lights.map((light) {
                    return Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: light.isOn ? Colors.amber : Colors.grey.shade800,
                        shape: BoxShape.circle,
                        boxShadow: light.isOn
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.lightbulb,
                        color: light.isOn ? Colors.white : Colors.grey.shade600,
                        size: 14,
                      ),
                    );
                  }),
                ],
              ),
            ),
            
            // Bottom gradient bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    roomColor.withOpacity(activeLights > 0 ? 0.7 : 0.3),
                    roomColor.withOpacity(activeLights > 0 ? 1.0 : 0.5),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}