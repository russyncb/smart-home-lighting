// lib/screens/room_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:illumi_home/models/room.dart';
import 'package:illumi_home/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  
  const RoomDetailScreen({
    super.key,
    required this.room,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  late Room _room;
  StreamSubscription? _roomSubscription;
  
  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _subscribeToRoomUpdates();
  }
  
  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToRoomUpdates() {
    // Subscribe to real-time updates for this specific room
    _roomSubscription?.cancel();
    _roomSubscription = _firestore
        .collection('rooms')
        .doc(_room.id)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _room = Room.fromMap(snapshot.data()!, snapshot.id);
          });
        }
      },
      onError: (e) {
        print('Error in room subscription: $e');
      },
    );
  }
  
  Future<void> _toggleLight(String lightId, bool newState) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Toggle light in Firestore
      await _databaseService.toggleLight(
        _room.id, 
        lightId, 
        newState
      );
      
      // No need to update state manually, as we're listening to Firestore changes
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling light: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _adjustBrightness(String lightId, double brightness) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Update brightness in Firestore
      await _databaseService.adjustBrightness(
        _room.id, 
        lightId, 
        brightness.toInt()
      );
      
      // No need to update state manually, as we're listening to Firestore changes
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adjusting brightness: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _toggleMotionSensor(String lightId, bool active) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Update motion sensor status in Firestore
      await _databaseService.toggleMotionSensor(
        _room.id, 
        lightId, 
        active
      );
      
      // No need to update state manually, as we're listening to Firestore changes
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling motion sensor: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _room.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _room.lights.length,
                itemBuilder: (context, index) {
                  final light = _room.lights[index];
                  return Card(
                    color: const Color(0xFF1E293B).withOpacity(0.5),
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade800),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: light.isOn
                                          ? Colors.amber.withOpacity(0.3)
                                          : Colors.grey.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.lightbulb,
                                      color: light.isOn ? Colors.amber : Colors.grey.shade500,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        light.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        light.isOn ? 'On' : 'Off',
                                        style: TextStyle(
                                          color: light.isOn ? Colors.amber : Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: light.isOn,
                                onChanged: (value) => _toggleLight(light.id, value),
                                activeColor: Colors.amber,
                                inactiveTrackColor: Colors.grey.shade700,
                              ),
                            ],
                          ),
                          
                          // Brightness slider
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.brightness_low,
                                color: Colors.white70,
                                size: 20,
                              ),
                              Expanded(
                                child: Slider(
                                  value: light.brightness.toDouble(),
                                  min: 1,
                                  max: 100,
                                  divisions: 10,
                                  activeColor: Colors.amber,
                                  inactiveColor: Colors.grey.shade700,
                                  label: '${light.brightness}%',
                                  onChanged: light.isOn
                                      ? (value) => _adjustBrightness(light.id, value)
                                      : null,
                                ),
                              ),
                              const Icon(
                                Icons.brightness_high,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ],
                          ),
                          
                          // Show schedule settings if applicable
                          if (light.hasSchedule) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.grey),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Scheduled: On at ${light.onTime}, Off at ${light.offTime}',
                                  style: TextStyle(
                                    color: Colors.grey.shade300,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          // Show motion sensor settings if applicable
                          if (light.hasMotionSensor) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.grey),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.sensors,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Motion Sensor',
                                      style: TextStyle(
                                        color: Colors.grey.shade300,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: light.motionSensorActive,
                                  onChanged: (value) => _toggleMotionSensor(light.id, value),
                                  activeColor: Colors.amber,
                                  inactiveTrackColor: Colors.grey.shade700,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}