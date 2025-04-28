// lib/services/database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:illumi_home/models/room.dart';
import 'package:illumi_home/models/schedule.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get real-time stream of rooms with improved debugging
  Stream<List<Room>> getRoomsStream() {
    return _firestore
        .collection('rooms')
        .snapshots()
        .map((snapshot) {
          print("Firebase update received: ${snapshot.docs.length} rooms");
          return snapshot.docs
              .map((doc) {
                final room = Room.fromMap(doc.data(), doc.id);
                // Debug log to track light states
                final activeLights = room.lights.where((l) => l.isOn).length;
                print("Room ${room.name}: $activeLights of ${room.lights.length} lights active");
                return room;
              })
              .toList();
        });
  }

  // Get schedules stream
  Stream<List<Schedule>> getSchedulesStream() {
    return _firestore
        .collection('schedules')
        .snapshots()
        .map((snapshot) {
          print("Firebase update received: ${snapshot.docs.length} schedules");
          return snapshot.docs
              .map((doc) => Schedule.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // Get rooms once (for non-real-time uses)
  Future<List<Room>> getRooms() async {
    try {
      final snapshot = await _firestore.collection('rooms').get();
      return snapshot.docs
          .map((doc) => Room.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting rooms: $e');
      return _getMockRooms();
    }
  }

  // Get a single room by ID
  Future<Room?> getRoom(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (doc.exists) {
        return Room.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting room: $e');
      return null;
    }
  }

  // Add a new room
  Future<void> addRoom(Map<String, dynamic> roomData) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Add user ID and timestamp
      roomData['createdBy'] = user.uid;
      roomData['createdAt'] = FieldValue.serverTimestamp();
      
      // Add room to Firestore
      final docRef = await _firestore.collection('rooms').add(roomData);
      
      // Log this action
      await logActivity(
        user.uid,
        user.phoneNumber ?? user.email ?? 'Unknown',
        'add_room',
        docRef.id,
        'new_room',
        details: {
          'roomName': roomData['name'],
          'roomType': roomData['type'],
        },
      );
      
      print('Room added successfully with ID: ${docRef.id}');
    } catch (e) {
      print('Error adding room: $e');
      throw e;
    }
  }

  // Delete a room
  Future<void> deleteRoom(String roomId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Get room info for logging before deletion
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      String roomName = "Unknown";
      String roomType = "Unknown";
      
      if (roomDoc.exists) {
        final data = roomDoc.data();
        roomName = data?['name'] ?? "Unknown";
        roomType = data?['type'] ?? "Unknown";
      }
      
      // Check for any schedules that reference this room and update them
      final scheduleSnapshot = await _firestore.collection('schedules').get();
      for (final doc in scheduleSnapshot.docs) {
        final schedule = Schedule.fromMap(doc.data(), doc.id);
        // Check if any targets reference this room
        final hasTargets = schedule.targets.any((target) => target.roomId == roomId);
        
        if (hasTargets) {
          // Remove targets for this room
          final updatedTargets = schedule.targets.where((target) => target.roomId != roomId).toList();
          
          if (updatedTargets.isEmpty) {
            // If no targets left, delete the schedule
            await _firestore.collection('schedules').doc(doc.id).delete();
          } else {
            // Update the schedule with remaining targets
            await _firestore.collection('schedules').doc(doc.id).update({
              'targets': updatedTargets.map((t) => t.toMap()).toList(),
            });
          }
        }
      }
      
      // Delete the room
      await _firestore.collection('rooms').doc(roomId).delete();
      
      // Log this action
      await logActivity(
        user.uid,
        user.phoneNumber ?? user.email ?? 'Unknown',
        'delete_room',
        roomId,
        'deleted_room',
        details: {
          'roomName': roomName,
          'roomType': roomType,
        },
      );
      
      print('Room deleted successfully: $roomId');
    } catch (e) {
      print('Error deleting room: $e');
      throw e;
    }
  }

  // Setup initial rooms (called once for the entire system)
  Future<void> setupRooms() async {
    try {
      // Check current user - required for setting up rooms
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Get existing rooms to avoid duplicates
      final existingRooms = await _firestore.collection('rooms').get();
      
      // If rooms already exist, don't create more
      if (existingRooms.docs.isNotEmpty) {
        print('Rooms already exist, skipping setup');
        return;
      }
      
      // Create rooms for the system
      final List<Map<String, dynamic>> rooms = [
        {
          'name': 'Bedroom',
          'type': 'indoor',
          'lights': [
            {'id': '1', 'name': 'Ceiling Light', 'isOn': false, 'brightness': 100},
            {'id': '2', 'name': 'Bedside Lamp', 'isOn': false, 'brightness': 70},
          ],
        },
        {
          'name': 'Kitchen',
          'type': 'indoor',
          'lights': [
            {'id': '3', 'name': 'Main Light', 'isOn': false, 'brightness': 100},
            {'id': '4', 'name': 'Counter Light', 'isOn': false, 'brightness': 80},
          ],
        },
        {
          'name': 'Dining Room',
          'type': 'indoor',
          'lights': [
            {'id': '5', 'name': 'Chandelier', 'isOn': false, 'brightness': 100},
          ],
        },
        {
          'name': 'Main Entrance',
          'type': 'outdoor',
          'lights': [
            {
              'id': '6', 
              'name': 'Porch Light', 
              'isOn': true, 
              'brightness': 100,
              'hasSchedule': true,
              'onTime': '18:00',
              'offTime': '05:30'
            },
          ],
        },
        {
          'name': 'Back of House',
          'type': 'outdoor',
          'lights': [
            {
              'id': '7', 
              'name': 'Deck Light', 
              'isOn': false, 
              'brightness': 100,
              'hasSchedule': true,
              'onTime': '18:00',
              'offTime': '05:30'
            },
          ],
        },
        {
          'name': 'Left Side',
          'type': 'outdoor',
          'lights': [
            {
              'id': '8', 
              'name': 'Floodlight', 
              'isOn': false, 
              'brightness': 100,
              'hasMotionSensor': true,
              'motionSensorActive': true
            },
          ],
        },
        {
          'name': 'Right Side',
          'type': 'outdoor',
          'lights': [
            {
              'id': '9', 
              'name': 'Motion Light', 
              'isOn': false, 
              'brightness': 100,
              'hasMotionSensor': true,
              'motionSensorActive': true
            },
          ],
        },
      ];
      
      // Add each room to Firestore
      final roomIds = <String>[];
      for (final room in rooms) {
        // Add user ID to distinguish who created these rooms
        room['createdBy'] = user.uid;
        room['createdAt'] = FieldValue.serverTimestamp();
        
        final docRef = await _firestore.collection('rooms').add(room);
        roomIds.add(docRef.id);
      }
      
      // Create some default schedules
      final List<Map<String, dynamic>> schedules = [
        {
          'name': 'Morning Routine',
          'time': '06:30',
          'days': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          'isActive': true,
          'action': 'on',
          'targets': [
            {
              'roomId': roomIds[0], // Bedroom
              'roomName': 'Bedroom',
              'lightId': '1',
              'lightName': 'Ceiling Light',
              'allLightsInRoom': false,
            },
            {
              'roomId': roomIds[1], // Kitchen
              'roomName': 'Kitchen',
              'lightId': '3',
              'lightName': 'Main Light',
              'allLightsInRoom': false,
            },
          ],
        },
        {
          'name': 'Evening Outdoor Lights',
          'time': '18:00',
          'days': ['Every day'],
          'isActive': true,
          'action': 'on',
          'targets': [
            {
              'roomId': roomIds[3], // Main Entrance
              'roomName': 'Main Entrance',
              'lightId': '6',
              'lightName': 'Porch Light',
              'allLightsInRoom': false,
            },
            {
              'roomId': roomIds[4], // Back of House
              'roomName': 'Back of House',
              'lightId': '7',
              'lightName': 'Deck Light',
              'allLightsInRoom': false,
            },
          ],
        },
        {
          'name': 'Night Mode',
          'time': '22:30',
          'days': ['Every day'],
          'isActive': true,
          'action': 'off',
          'targets': [
            {
              'roomId': 'all_indoor',
              'roomName': 'All Indoor Rooms',
              'lightId': 'all',
              'lightName': 'All Lights',
              'allLightsInRoom': true,
            },
          ],
        },
      ];
      
      // Add each schedule to Firestore
      for (final schedule in schedules) {
        // Add user ID to distinguish who created these schedules
        schedule['createdBy'] = user.uid;
        schedule['createdAt'] = FieldValue.serverTimestamp();
        
        await _firestore.collection('schedules').add(schedule);
      }
      
      // Log this action
      await logActivity(
        user.uid,
        user.phoneNumber ?? user.email ?? 'Unknown',
        'setup_rooms',
        'system',
        'system',
        details: {
          'roomCount': rooms.length,
          'scheduleCount': schedules.length,
        },
      );
      
      print('System rooms and schedules created successfully');
    } catch (e) {
      print('Error setting up rooms: $e');
      throw e;
    }
  }

  // Toggle light on/off with improved implementation
  Future<void> toggleLight(String roomId, String lightId, bool newState, {String source = 'manual'}) async {
    try {
      // Get the current user for logging
      final user = FirebaseAuth.instance.currentUser;
      
      // Using transactions for better data consistency
      await _firestore.runTransaction((transaction) async {
        // Get the room document
        final roomDoc = await transaction.get(_firestore.collection('rooms').doc(roomId));
        
        if (!roomDoc.exists) {
          throw Exception('Room not found');
        }
        
        final roomData = roomDoc.data() as Map<String, dynamic>;
        
        // Get and update the lights array
        final lights = List<Map<String, dynamic>>.from(roomData['lights']);
        String lightName = 'Unknown';
        
        for (int i = 0; i < lights.length; i++) {
          if (lights[i]['id'] == lightId) {
            lights[i]['isOn'] = newState;
            lightName = lights[i]['name'];
            break;
          }
        }
        
        // Update the Firestore document within the transaction
        transaction.update(_firestore.collection('rooms').doc(roomId), {
          'lights': lights,
        });
        
        // Return the light name for logging (transaction must return a value)
        return lightName;
      }).then((lightName) async {
        // Log the activity if user is logged in
        if (user != null) {
          await logActivity(
            user.uid,
            user.phoneNumber ?? user.email ?? 'Unknown',
            'toggle_light',
            roomId,
            lightId,
            details: {
              'lightName': lightName,
              'newState': newState,
              'source': source, // Added source parameter
            },
          );
        }
        
        print('Light ${newState ? 'turned on' : 'turned off'} successfully via ${source}');
      });
    } catch (e) {
      print('Error toggling light: $e');
      throw e;
    }
  }

  // Special method to toggle all lights in selected rooms (for schedules)
  Future<void> executeScheduleAction(List<ScheduleTarget> targets, String action) async {
    try {
      // Get the current user for logging
      final user = FirebaseAuth.instance.currentUser;
      
      for (final target in targets) {
        if (target.roomId == 'all_indoor' || target.roomId == 'all_outdoor' || target.roomId == 'all') {
          // Handle special case for all rooms
          await _toggleAllLights(target.roomId, action == 'on');
          continue;
        }
        
        if (target.allLightsInRoom == true) {
          // Toggle all lights in this room
          final roomDoc = await _firestore.collection('rooms').doc(target.roomId).get();
          if (!roomDoc.exists) continue;
          
          final roomData = roomDoc.data() as Map<String, dynamic>;
          final lights = List<Map<String, dynamic>>.from(roomData['lights']);
          
          for (int i = 0; i < lights.length; i++) {
            lights[i]['isOn'] = action == 'on';
          }
          
          await _firestore.collection('rooms').doc(target.roomId).update({
            'lights': lights,
          });
          
          // Log this bulk action
          if (user != null) {
            await logActivity(
              user.uid,
              user.phoneNumber ?? user.email ?? 'Unknown',
              'schedule_${action}',
              target.roomId,
              'all',
              details: {
                'roomName': target.roomName ?? 'Unknown room',
                'scheduledAction': action,
              },
            );
          }
        } else {
          // Toggle just this specific light
          final roomDoc = await _firestore.collection('rooms').doc(target.roomId).get();
          if (!roomDoc.exists) continue;
          
          final roomData = roomDoc.data() as Map<String, dynamic>;
          final lights = List<Map<String, dynamic>>.from(roomData['lights']);
          String lightName = 'Unknown';
          
          for (int i = 0; i < lights.length; i++) {
            if (lights[i]['id'] == target.lightId) {
              lights[i]['isOn'] = action == 'on';
              lightName = lights[i]['name'];
              break;
            }
          }
          
          await _firestore.collection('rooms').doc(target.roomId).update({
            'lights': lights,
          });
          
          // Log the activity
          if (user != null) {
            await logActivity(
              user.uid,
              user.phoneNumber ?? user.email ?? 'Unknown',
              'schedule_${action}',
              target.roomId,
              target.lightId,
              details: {
                'lightName': lightName,
                'roomName': target.roomName ?? 'Unknown room',
                'scheduledAction': action,
              },
            );
          }
        }
      }
      
      print('Schedule executed successfully: ${action} lights');
    } catch (e) {
      print('Error executing schedule: $e');
      throw e;
    }
  }

  // Helper to toggle all lights in a category
  Future<void> _toggleAllLights(String category, bool newState) async {
    try {
      final snapshot = await _firestore.collection('rooms').get();
      final user = FirebaseAuth.instance.currentUser;
      
      for (final doc in snapshot.docs) {
        final roomData = doc.data();
        final roomType = roomData['type'] as String? ?? '';
        
        // Filter by category
        if (category == 'all' || 
            (category == 'all_indoor' && roomType == 'indoor') ||
            (category == 'all_outdoor' && roomType == 'outdoor')) {
          
          final lights = List<Map<String, dynamic>>.from(roomData['lights'] ?? []);
          
          for (int i = 0; i < lights.length; i++) {
            lights[i]['isOn'] = newState;
          }
          
          await _firestore.collection('rooms').doc(doc.id).update({
            'lights': lights,
          });
          
          // Log this bulk action
          if (user != null) {
            await logActivity(
              user.uid,
              user.phoneNumber ?? user.email ?? 'Unknown',
              'toggle_all_lights',
              doc.id,
              'all',
              details: {
                'roomName': roomData['name'] ?? 'Unknown room',
                'newState': newState,
                'category': category,
                'source': 'voice_command',
              },
            );
          }
        }
      }
    } catch (e) {
      print('Error toggling all lights: $e');
      throw e;
    }
  }

  // Toggle all lights (wrapper for voice command function)
  Future<void> toggleAllLights(bool newState) async {
    await _toggleAllLights('all', newState);
  }

  // Toggle all lights by type (wrapper for voice command function)
  Future<void> toggleAllLightsByType(String type, bool newState) async {
    String category = 'all';
    if (type == 'indoor') {
      category = 'all_indoor';
    } else if (type == 'outdoor') {
      category = 'all_outdoor';
    }
    await _toggleAllLights(category, newState);
  }

  // Toggle all lights in a specific room
  Future<void> toggleAllLightsInRoom(String roomId, bool newState) async {
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final user = FirebaseAuth.instance.currentUser;
      
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      
      final roomData = roomDoc.data() as Map<String, dynamic>;
      final lights = List<Map<String, dynamic>>.from(roomData['lights']);
      
      for (int i = 0; i < lights.length; i++) {
        lights[i]['isOn'] = newState;
      }
      
      await _firestore.collection('rooms').doc(roomId).update({
        'lights': lights,
      });
      
      // Log this bulk action
      if (user != null) {
        await logActivity(
          user.uid,
          user.phoneNumber ?? user.email ?? 'Unknown',
          'toggle_room_lights',
          roomId,
          'all',
          details: {
            'roomName': roomData['name'] ?? 'Unknown room',
            'newState': newState,
            'source': 'voice_command',
          },
        );
      }
      
      print('All lights in room ${roomData['name']} ${newState ? 'turned on' : 'turned off'} successfully');
    } catch (e) {
      print('Error toggling room lights: $e');
      throw e;
    }
  }

  // Adjust light brightness
  Future<void> adjustBrightness(String roomId, String lightId, int brightness, {String source = 'manual'}) async {
    try {
      // Get the current user for logging
      final user = FirebaseAuth.instance.currentUser;
      
      // Using transactions for data consistency
      await _firestore.runTransaction((transaction) async {
        // Get the room document
        final roomDoc = await transaction.get(_firestore.collection('rooms').doc(roomId));
        
        if (!roomDoc.exists) {
          throw Exception('Room not found');
        }
        
        final roomData = roomDoc.data() as Map<String, dynamic>;
        
        // Get and update the lights array
        final lights = List<Map<String, dynamic>>.from(roomData['lights']);
        String lightName = 'Unknown';
        
        for (int i = 0; i < lights.length; i++) {
          if (lights[i]['id'] == lightId) {
            lights[i]['brightness'] = brightness;
            lightName = lights[i]['name'];
            break;
          }
        }
        
        // Update the Firestore document within the transaction
        transaction.update(_firestore.collection('rooms').doc(roomId), {
          'lights': lights,
        });
        
        // Return the light name for logging
        return lightName;
      }).then((lightName) async {
        // Log the activity if user is logged in
        if (user != null) {
          await logActivity(
            user.uid,
            user.phoneNumber ?? user.email ?? 'Unknown',
            'adjust_brightness',
            roomId,
            lightId,
            details: {
              'lightName': lightName,
              'brightness': brightness,
              'source': source,
            },
          );
        }
        
        print('Light brightness adjusted successfully via $source');
      });
    } catch (e) {
      print('Error adjusting light brightness: $e');
      throw e;
    }
  }

  // Toggle motion sensor
  Future<void> toggleMotionSensor(String roomId, String lightId, bool active) async {
    try {
      // Get the current user for logging
      final user = FirebaseAuth.instance.currentUser;
      
      // Using transactions for data consistency
      await _firestore.runTransaction((transaction) async {
        // Get the room document
        final roomDoc = await transaction.get(_firestore.collection('rooms').doc(roomId));
        
        if (!roomDoc.exists) {
          throw Exception('Room not found');
        }
        
        final roomData = roomDoc.data() as Map<String, dynamic>;
        
        // Get and update the lights array
        final lights = List<Map<String, dynamic>>.from(roomData['lights']);
        String lightName = 'Unknown';
        
        for (int i = 0; i < lights.length; i++) {
          if (lights[i]['id'] == lightId) {
            lights[i]['motionSensorActive'] = active;
            lightName = lights[i]['name'];
            break;
          }
        }
        
        // Update the Firestore document within the transaction
        transaction.update(_firestore.collection('rooms').doc(roomId), {
          'lights': lights,
        });
        
        // Return the light name for logging
        return lightName;
      }).then((lightName) async {
        // Log the activity if user is logged in
        if (user != null) {
          await logActivity(
            user.uid,
            user.phoneNumber ?? user.email ?? 'Unknown',
            'toggle_motion_sensor',
            roomId,
            lightId,
            details: {
              'lightName': lightName,
              'enabled': active,
            },
          );
        }
        
        print('Motion sensor ${active ? 'activated' : 'deactivated'} successfully');
      });
    } catch (e) {
      print('Error toggling motion sensor: $e');
      throw e;
    }
  }

  // SCHEDULE METHODS
  
  // Add a new schedule
  Future<void> addSchedule(Map<String, dynamic> scheduleData) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Add user ID and timestamp
      scheduleData['createdBy'] = user.uid;
      scheduleData['createdAt'] = FieldValue.serverTimestamp();
      
      // Add schedule to Firestore
      final docRef = await _firestore.collection('schedules').add(scheduleData);
      
      // Log this action
      await logActivity(
        user.uid,
        user.phoneNumber ?? user.email ?? 'Unknown',
        'add_schedule',
        'system',
        'schedule',
        details: {
          'scheduleName': scheduleData['name'],
          'scheduleId': docRef.id,
        },
      );
      
      print('Schedule added successfully with ID: ${docRef.id}');
    } catch (e) {
      print('Error adding schedule: $e');
      throw e;
    }
  }
  
  // Update an existing schedule
  Future<void> updateSchedule(String scheduleId, Map<String, dynamic> scheduleData) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Add updated timestamp
      scheduleData['updatedAt'] = FieldValue.serverTimestamp();
      
      // Update schedule in Firestore
      await _firestore.collection('schedules').doc(scheduleId).update(scheduleData);
      
      // Log this action
      await logActivity(
        user.uid,
        user.phoneNumber ?? user.email ?? 'Unknown',
        'update_schedule',
        'system',
        'schedule',
        details: {
          'scheduleName': scheduleData['name'],
          'scheduleId': scheduleId,
        },
      );
      
      print('Schedule updated successfully: $scheduleId');
    } catch (e) {
      print('Error updating schedule: $e');
      throw e;
    }
  }
  
  // Toggle schedule active status
  Future<void> toggleSchedule(String scheduleId, bool isActive) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Update schedule in Firestore
      await _firestore.collection('schedules').doc(scheduleId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Log this action
      await logActivity(
        user.uid,
        user.phoneNumber ?? user.email ?? 'Unknown',
        'toggle_schedule',
        'system',
        'schedule',
        details: {
          'scheduleId': scheduleId,
          'isActive': isActive,
        },
      );
      
      print('Schedule ${isActive ? 'activated' : 'deactivated'} successfully: $scheduleId');
    } catch (e) {
      print('Error toggling schedule: $e');
      throw e;
    }
  }
  
  // Delete a schedule
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Get schedule info for logging before deletion
      final scheduleDoc = await _firestore.collection('schedules').doc(scheduleId).get();
      String scheduleName = "Unknown";
      
      if (scheduleDoc.exists) {
        final data = scheduleDoc.data();
        scheduleName = data?['name'] ?? "Unknown";
      }
      
      // Delete the schedule
      await _firestore.collection('schedules').doc(scheduleId).delete();
      
      // Log this action
      await logActivity(
        user.uid,
        user.phoneNumber ?? user.email ?? 'Unknown',
        'delete_schedule',
        'system',
        'schedule',
        details: {
          'scheduleId': scheduleId,
          'scheduleName': scheduleName,
        },
      );
      
      print('Schedule deleted successfully: $scheduleId');
    } catch (e) {
      print('Error deleting schedule: $e');
      throw e;
    }
  }

  // Log user activity
  Future<void> logActivity(String userId, String identifier, String action, String roomId, String lightId, {Map<String, dynamic>? details}) async {
    try {
      await _firestore.collection('activity_logs').add({
        'userId': userId,
        'phoneNumber': FirebaseAuth.instance.currentUser?.phoneNumber,
        'email': FirebaseAuth.instance.currentUser?.email,
        'identifier': identifier,
        'action': action,
        'roomId': roomId,
        'lightId': lightId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging activity: $e');
    }
  }

  // Fallback mock data in case Firestore is not set up
  List<Room> _getMockRooms() {
    return [
      Room(
        id: '1',
        name: 'Bedroom',
        type: RoomType.indoor,
        lights: [
          Light(id: '1', name: 'Ceiling Light', isOn: false, brightness: 100),
          Light(id: '2', name: 'Bedside Lamp', isOn: false, brightness: 70),
        ],
      ),
      Room(
        id: '2',
        name: 'Kitchen',
        type: RoomType.indoor,
        lights: [
          Light(id: '3', name: 'Main Light', isOn: false, brightness: 100),
          Light(id: '4', name: 'Counter Light', isOn: false, brightness: 80),
        ],
      ),
      Room(
        id: '3',
        name: 'Dining Room',
        type: RoomType.indoor,
        lights: [
          Light(id: '5', name: 'Chandelier', isOn: false, brightness: 100),
        ],
      ),
      Room(
        id: '4',
        name: 'Main Entrance',
        type: RoomType.outdoor,
        lights: [
          Light(
            id: '6', 
            name: 'Porch Light', 
            isOn: true, 
            brightness: 100,
            hasSchedule: true,
            onTime: '18:00',
            offTime: '05:30'
          ),
        ],
      ),
      Room(
        id: '5',
        name: 'Back of House',
        type: RoomType.outdoor,
        lights: [
          Light(
            id: '7', 
            name: 'Deck Light', 
            isOn: false, 
            brightness: 100,
            hasSchedule: true,
            onTime: '18:00',
            offTime: '05:30'
          ),
        ],
      ),
      Room(
        id: '6',
        name: 'Left Side',
        type: RoomType.outdoor,
        lights: [
          Light(
            id: '8', 
            name: 'Floodlight', 
            isOn: false, 
            brightness: 100,
            hasMotionSensor: true,
            motionSensorActive: true
          ),
        ],
      ),
      Room(
        id: '7',
        name: 'Right Side',
        type: RoomType.outdoor,
        lights: [
          Light(
            id: '9', 
            name: 'Motion Light', 
            isOn: false, 
            brightness: 100,
            hasMotionSensor: true,
            motionSensorActive: true
          ),
        ],
      ),
    ];
  }
}