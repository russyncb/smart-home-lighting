// lib/widgets/room_card.dart
import 'package:flutter/material.dart';
import 'package:illumi_home/models/room.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

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
      onLongPress: onLongPress,
      child: Container(
        // Set a specific max height to avoid overflow
        constraints: const BoxConstraints(
          minHeight: 150,
          maxHeight: 200,
        ),
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
          mainAxisSize: MainAxisSize.min, // Use minimum space needed
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room header with icon and lights count
            Padding(
              padding: const EdgeInsets.all(12), // Slightly reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40, // Slightly smaller
                        height: 40, // Slightly smaller
                        decoration: BoxDecoration(
                          color: roomColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getRoomIcon(room.name),
                            style: const TextStyle(fontSize: 20), // Slightly smaller
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Slightly smaller
                        decoration: BoxDecoration(
                          color: activeLights > 0
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(height: 8), // Reduced spacing
                  Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16, // Slightly smaller
                    ),
                    // Add overflow handling
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  Text(
                    activeLights == 0
                        ? 'All lights off'
                        : activeLights == room.lights.length
                            ? 'All lights on'
                            : '$activeLights light${activeLights == 1 ? '' : 's'} on',
                    style: TextStyle(
                      color: activeLights > 0 ? Colors.amber.shade400 : Colors.grey.shade500,
                      fontSize: 12, // Slightly smaller
                    ),
                    // Add overflow handling
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            
            // Light indicators - Flexible container that can adapt
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, // Allow horizontal scrolling if many lights
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var light in room.lights)
                        Container(
                          width: 20, // Slightly smaller
                          height: 20, // Slightly smaller
                          margin: const EdgeInsets.only(right: 6), // Slightly smaller
                          decoration: BoxDecoration(
                            color: light.isOn ? Colors.amber : Colors.grey.shade800,
                            shape: BoxShape.circle,
                            boxShadow: light.isOn
                                ? [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.4),
                                      blurRadius: 6, // Slightly smaller
                                      spreadRadius: 1, // Slightly smaller
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.lightbulb,
                            color: light.isOn ? Colors.white : Colors.grey.shade600,
                            size: 12, // Slightly smaller
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom gradient bar
            Container(
              height: 4, // Slightly smaller
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