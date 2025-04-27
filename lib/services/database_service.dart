// lib/services/database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:illumi_home/models/room.dart';

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
      for (final room in rooms) {
        // Add user ID to distinguish who created these rooms
        room['createdBy'] = user.uid;
        room['createdAt'] = FieldValue.serverTimestamp();
        
        await _firestore.collection('rooms').add(room);
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
        },
      );
      
      print('System rooms created successfully: ${rooms.length} rooms');
    } catch (e) {
      print('Error setting up rooms: $e');
      throw e;
    }
  }

  // Toggle light on/off with improved implementation
  Future<void> toggleLight(String roomId, String lightId, bool newState) async {
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
            },
          );
        }
        
        print('Light ${newState ? 'turned on' : 'turned off'} successfully');
      });
    } catch (e) {
      print('Error toggling light: $e');
      throw e;
    }
  }

  // Adjust light brightness
  Future<void> adjustBrightness(String roomId, String lightId, int brightness) async {
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
            },
          );
        }
        
        print('Light brightness adjusted successfully');
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