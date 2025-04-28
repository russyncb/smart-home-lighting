// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:illumi_home/models/room.dart';
import 'package:illumi_home/services/database_service.dart';
import 'package:illumi_home/services/schedule_service.dart';
import 'package:illumi_home/screens/schedule_list_screen.dart';
import 'package:illumi_home/widgets/room_card.dart';
import 'package:flutter/services.dart';
import 'package:illumi_home/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:illumi_home/services/voice_command_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final ScheduleService _scheduleService = ScheduleService();
  List<Room> _rooms = [];
  bool _isLoading = true;
  StreamSubscription? _roomsSubscription;
  int _selectedIndex = 0;
  bool _isVoiceListening = false;
  late AnimationController _animationController;
  late VoiceCommandService _voiceCommandService;
  String? _voiceFeedbackMessage;
  Timer? _feedbackTimer;
  
  final List<Widget> _screens = [];
  
  @override
  void initState() {
    super.initState();
    _subscribeToRooms();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Initialize voice command service
    _voiceCommandService = VoiceCommandService(
      onListeningStatusChanged: (isListening) {
        setState(() {
          _isVoiceListening = isListening;
          if (isListening) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
        });
      },
      onFeedbackMessage: (message) {
        setState(() {
          _voiceFeedbackMessage = message;
        });
        
        // Clear the feedback message after 5 seconds
        _feedbackTimer?.cancel();
        _feedbackTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _voiceFeedbackMessage = null;
            });
          }
        });
      },
    );
    _voiceCommandService.initialize();
    
    // Start the schedule service
    _scheduleService.startScheduleService();
  }
  
  @override
  void dispose() {
    _roomsSubscription?.cancel();
    _animationController.dispose();
    _feedbackTimer?.cancel();
    
    // Stop the schedule service
    _scheduleService.stopScheduleService();
    
    super.dispose();
  }

  void _subscribeToRooms() {
    setState(() {
      _isLoading = true;
    });

    // Cancel any existing subscription
    _roomsSubscription?.cancel();
    
    // Subscribe to real-time updates with explicit handling
    _roomsSubscription = _databaseService.getRoomsStream().listen(
      (rooms) {
        if (mounted) {
          setState(() {
            _rooms = rooms;
            _isLoading = false;
          });
          
          // If rooms are empty, show setup option
          if (_rooms.isEmpty) {
            _setupRoomsIfNeeded();
          }
        }
      },
      onError: (e) {
        print('Error in rooms stream: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading rooms: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    );
  }

  Future<void> _setupRoomsIfNeeded() async {
    try {
      // Check if user wants to set up rooms now
      final shouldSetup = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('No Rooms Found', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Would you like to set up demo rooms and lights now?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('LATER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
              ),
              child: const Text('SET UP NOW'),
            ),
          ],
        ),
      );
      
      if (shouldSetup == true) {
        setState(() {
          _isLoading = true;
        });
        await _databaseService.setupRooms();
        _subscribeToRooms();
      }
    } catch (e) {
      print('Error setting up rooms: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting up rooms: $e')),
      );
    }
  }

  Future<void> _addNewRoom(RoomType roomType) async {
    // Controller for room name
    final TextEditingController roomNameController = TextEditingController();
    
    try {
      // Show dialog to get room name
      final roomName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'New ${roomType == RoomType.indoor ? 'Indoor' : 'Outdoor'} Room',
            style: const TextStyle(color: Colors.white)
          ),
          content: TextField(
            controller: roomNameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter room name',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (roomNameController.text.trim().isNotEmpty) {
                  Navigator.pop(context, roomNameController.text.trim());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a room name')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
              ),
              child: const Text('ADD'),
            ),
          ],
        ),
      );
      
      if (roomName != null && roomName.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });
        
        // Create a new room map
        final Map<String, dynamic> newRoom = {
          'name': roomName,
          'type': roomType == RoomType.indoor ? 'indoor' : 'outdoor',
          'lights': [
            {
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'name': 'Main Light',
              'isOn': false,
              'brightness': 100,
              'hasMotionSensor': roomType == RoomType.outdoor,
              'motionSensorActive': roomType == RoomType.outdoor,
            }
          ],
        };
        
        // Add room to Firestore
        await _databaseService.addRoom(newRoom);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room "$roomName" added successfully!')),
        );
        
        // Rooms will update automatically via the subscription
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding room: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _removeRoom(Room room) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'Delete ${room.name}',
            style: const TextStyle(color: Colors.white)
          ),
          content: Text(
            'Are you sure you want to delete this room and all its lights? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('DELETE'),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        setState(() {
          _isLoading = true;
        });
        
        // Delete room from Firestore
        await _databaseService.deleteRoom(room.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room "${room.name}" deleted successfully!')),
        );
        
        // Rooms will update automatically via the subscription
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting room: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRooms() async {
    // For pull-to-refresh functionality
    _subscribeToRooms();
    return Future.delayed(const Duration(milliseconds: 500));
  }

  // Sign out user
  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
  
  // Get user initials for display
  String _getUserInitials() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "?";
    
    if (user.email != null && user.email!.isNotEmpty) {
      // Get initial from email
      return user.email![0].toUpperCase();
    } else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      // Get first 2 digits from phone
      return user.phoneNumber!.length > 2 ? user.phoneNumber!.substring(0, 2) : user.phoneNumber![0];
    } else if (user.displayName != null && user.displayName!.isNotEmpty) {
      // Get initials from display name
      final nameParts = user.displayName!.split(' ');
      if (nameParts.length > 1) {
        return nameParts[0][0].toUpperCase() + nameParts[1][0].toUpperCase();
      }
      return nameParts[0][0].toUpperCase();
    }
    
    return "U";
  }
  
  // Get user identifier (email or phone) for display
  String _getUserIdentifier() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Not signed in";
    
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!;
    } else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      return user.phoneNumber!;
    } else if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    
    return "Unknown user";
  }

  void _toggleVoiceListening() {
    HapticFeedback.mediumImpact();
    _voiceCommandService.toggleListening(_rooms);
  }
  
  void _showVoiceCommandOverlay() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Voice Commands',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Try saying:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildVoiceCommandExample('Turn on the kitchen light'),
              _buildVoiceCommandExample('Turn off all lights'),
              _buildVoiceCommandExample('Set bedroom brightness to 50%'),
              _buildVoiceCommandExample('Turn on outside lights'),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber.shade300,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Voice commands let you control lights hands-free. Just speak clearly and use room and light names exactly as they appear in the app.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isVoiceListening = false;
                    _animationController.reverse();
                  });
                },
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade400,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      setState(() {
        _isVoiceListening = false;
        _animationController.reverse();
      });
    });
  }
  
  Widget _buildVoiceCommandExample(String command) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mic,
            color: Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              command,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.play_circle_outline,
              color: Colors.amber,
            ),
            onPressed: () {
              // Simulate voice command execution
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Executing: "$command"'),
                  backgroundColor: Colors.amber.shade700,
                ),
              );
              Navigator.pop(context);
              setState(() {
                _isVoiceListening = false;
                _animationController.reverse();
              });
            },
          ),
        ],
      ),
    );
  }

  int get _activeLightsCount {
    int count = 0;
    for (var room in _rooms) {
      count += room.lights.where((light) => light.isOn).length;
    }
    return count;
  }

  int get _totalLightsCount {
    int count = 0;
    for (var room in _rooms) {
      count += room.lights.length;
    }
    return count;
  }

  List<Room> get _indoorRooms => 
    _rooms.where((room) => room.type == RoomType.indoor).toList();

  List<Room> get _outdoorRooms => 
    _rooms.where((room) => room.type == RoomType.outdoor).toList();

  Widget _buildHomeScreen() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadRooms,
          color: Colors.amber,
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                pinned: true,
                snap: false,
                backgroundColor: themeProvider.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
                expandedHeight: 120.0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.withOpacity(0.1),
                            ),
                            child: const Icon(
                              Icons.home_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Smart Home Lighting',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: themeProvider.isDarkMode
                            ? [const Color(0xFF0F172A), const Color(0xFF0F172A)]
                            : [Colors.white, Colors.white],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.logout,
                      color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                    ),
                    onPressed: _signOut,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
              
              // Status summary
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 100,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.amber.shade600.withOpacity(0.8), Colors.amber.shade300],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.lightbulb,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Active Lights',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$_activeLightsCount / $_totalLightsCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Indoor rooms section
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.house_rounded,
                              color: Colors.blue.shade400,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Indoor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _addNewRoom(RoomType.indoor),
                            icon: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.amber,
                            ),
                            label: const Text(
                              'New',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.amber.withOpacity(0.1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _indoorRooms.isEmpty 
                                ? null 
                                : () => _showRemoveRoomDialog(RoomType.indoor),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: _indoorRooms.isEmpty 
                                  ? Colors.grey.withOpacity(0.1) 
                                  : Colors.red.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Indoor rooms grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: _indoorRooms.isEmpty
                    ? SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                Icons.home,
                                size: 48,
                                color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No indoor rooms found',
                                style: TextStyle(
                                  color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _addNewRoom(RoomType.indoor),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade600,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                ),
                                child: const Text(
                                  'ADD INDOOR ROOM',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final room = _indoorRooms[index];
                            return RoomCard(
                              key: ValueKey('room-${room.id}'),
                              room: room,
                              onTap: () async {
                                await Navigator.pushNamed(
                                  context,
                                  '/room/${room.id}',
                                  arguments: room,
                                );
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              onLongPress: () => _showRoomOptionsBottomSheet(room),
                            );
                          },
                          childCount: _indoorRooms.length,
                        ),
                      ),
              ),
              
              // Outdoor rooms section
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.yard_rounded,
                              color: Colors.green.shade400,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Outdoor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _addNewRoom(RoomType.outdoor),
                            icon: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.amber,
                            ),
                            label: const Text(
                              'New',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(backgroundColor: Colors.amber.withOpacity(0.1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _outdoorRooms.isEmpty 
                                ? null 
                                : () => _showRemoveRoomDialog(RoomType.outdoor),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: _outdoorRooms.isEmpty 
                                  ? Colors.grey.withOpacity(0.1) 
                                  : Colors.red.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Outdoor rooms grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: _outdoorRooms.isEmpty
                    ? SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                Icons.yard,
                                size: 48,
                                color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No outdoor rooms found',
                                style: TextStyle(
                                  color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _addNewRoom(RoomType.outdoor),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade600,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                ),
                                child: const Text(
                                  'ADD OUTDOOR ROOM',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final room = _outdoorRooms[index];
                            return RoomCard(
                              key: ValueKey('room-${room.id}'),
                              room: room,
                              onTap: () async {
                                await Navigator.pushNamed(
                                  context,
                                  '/room/${room.id}',
                                  arguments: room,
                                );
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              onLongPress: () => _showRoomOptionsBottomSheet(room),
                            );
                          },
                          childCount: _outdoorRooms.length,
                        ),
                      ),
              ),
            ],
          ),
        ),
        
        // Voice feedback message
        if (_voiceFeedbackMessage != null)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                    ? Colors.grey.shade800.withOpacity(0.9) 
                    : Colors.grey.shade900.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _isVoiceListening ? Icons.mic : Icons.check_circle_outline,
                    color: _isVoiceListening ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _voiceFeedbackMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
        // Floating voice command button
        Positioned(
          right: 16,
          bottom: 80,
          child: FloatingActionButton(
            onPressed: _toggleVoiceListening,
            backgroundColor: _isVoiceListening ? Colors.red : Colors.amber,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isVoiceListening 
                            ? Colors.red.withOpacity(0.3) 
                            : Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2 + (_animationController.value * 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isVoiceListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
  
  void _showRoomOptionsBottomSheet(Room room) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      room.type == RoomType.indoor ? Icons.house : Icons.yard,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          '${room.lights.length} ${room.lights.length == 1 ? 'light' : 'lights'}',
                          style: TextStyle(
                            color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Options
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blue),
                title: Text(
                  'View Room Details',
                  style: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/room/${room.id}',
                    arguments: room,
                  );
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.orange),
                title: Text(
                  'Create Schedule',
                  style: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to the schedule screen and add a room-specific schedule
                  // this is not implemented yet
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Delete Room',
                  style: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeRoom(room);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _showRemoveRoomDialog(RoomType roomType) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final rooms = roomType == RoomType.indoor ? _indoorRooms : _outdoorRooms;
    
    if (rooms.isEmpty) return;
    
    Room? selectedRoom;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            title: Text(
              'Remove ${roomType == RoomType.indoor ? 'Indoor' : 'Outdoor'} Room',
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select a room to remove:',
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    child: Column(
                      children: rooms.map((room) {
                        return RadioListTile<Room>(
                          title: Text(
                            room.name,
                            style: TextStyle(
                              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            '${room.lights.length} ${room.lights.length == 1 ? 'light' : 'lights'}',
                            style: TextStyle(
                              color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                            ),
                          ),
                          value: room,
                          groupValue: selectedRoom,
                          onChanged: (value) {
                            setStateDialog(() {
                              selectedRoom = value;
                            });
                          },
                          activeColor: Colors.amber,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: selectedRoom == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        _removeRoom(selectedRoom!);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('REMOVE'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildSchedulesScreen() {
    // Use the actual schedule list screen instead of the mock one
    return const ScheduleListScreen();
  }
  
  Widget _buildSensorsScreen() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Filter rooms with motion sensors first
    final sensorRooms = _rooms.where((room) {
      return room.lights.any((light) => light.hasMotionSensor);
    }).toList();
    
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          floating: true,
          pinned: true,
          snap: false,
          backgroundColor: themeProvider.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          expandedHeight: 120.0,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            title: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.indigo.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.sensors_rounded,
                        color: Colors.indigo,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Motion Sensors',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: themeProvider.isDarkMode
                      ? [const Color(0xFF0F172A), const Color(0xFF0F172A)]
                      : [Colors.white, Colors.white],
                ),
              ),
            ),
          ),
        ),
        
        // Empty state if no sensors
        sensorRooms.isEmpty
          ? SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sensors_off,
                        size: 64,
                        color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No motion sensors found',
                        style: TextStyle(
                          color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add outdoor lights with motion sensors to manage them here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('ADD OUTDOOR ROOM'),
                        onPressed: () => _addNewRoom(RoomType.outdoor),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= sensorRooms.length) return null;
                  
                  final room = sensorRooms[index];
                  final sensorsInRoom = room.lights.where((light) => light.hasMotionSensor).toList();
                  
                  return Container(
                    margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      title: Text(
                        room.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        '${sensorsInRoom.length} motion ${sensorsInRoom.length == 1 ? 'sensor' : 'sensors'}',
                        style: TextStyle(
                          color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                      children: sensorsInRoom.map((light) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: light.motionSensorActive
                                    ? Colors.indigo.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.sensors,
                                  color: light.motionSensorActive ? Colors.indigo : Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      light.name,
                                      style: TextStyle(
                                        color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Motion detection ${light.motionSensorActive ? 'active' : 'inactive'}',
                                      style: TextStyle(
                                        color: light.motionSensorActive ? Colors.green.shade300 : Colors.red.shade300,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (light.isOn) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Light is currently ON',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Switch(
                                value: light.motionSensorActive,
                                onChanged: (value) {
                                  _databaseService.toggleMotionSensor(room.id, light.id, value);
                                },
                                activeColor: Colors.indigo,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
                childCount: sensorRooms.length,
              ),
            ),
      ],
    );
  }
  
  Widget _buildSettingsScreen() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          floating: true,
          pinned: true,
          snap: false,
          backgroundColor: themeProvider.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          expandedHeight: 120.0,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            title: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.teal.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: Colors.teal,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: themeProvider.isDarkMode
                      ? [const Color(0xFF0F172A), const Color(0xFF0F172A)]
                      : [Colors.white, Colors.white],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User profile section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _getUserInitials(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current User',
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getUserIdentifier(),
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // App settings
                Text(
                  'App Settings',
                  style: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildSettingTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notifications',
                  subtitle: 'Manage alerts and notifications',
                  trailing: Icon(Icons.chevron_right, 
                    color: themeProvider.isDarkMode ? Colors.grey : Colors.grey.shade700),
                  onTap: () {
                    // Show notifications dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                        title: Text('Notifications',
                          style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Currently not implemented. In the future, you\'ll be able to:',
                              style: TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87)),
                            const SizedBox(height: 16),
                            _buildFeatureItem('Get alerted when lights turn on/off'),
                            _buildFeatureItem('Motion detection notifications'),
                            _buildFeatureItem('Schedule reminders'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                _buildSettingTile(
                  icon: Icons.mic_outlined,
                  title: 'Voice Commands',
                  subtitle: 'Configure voice recognition settings',
                  trailing: Icon(Icons.chevron_right, 
                    color: themeProvider.isDarkMode ? Colors.grey : Colors.grey.shade700),
                  onTap: () {
                    // Show voice commands dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                        title: Text('Voice Commands',
                          style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Voice commands allow you to control your lights using natural language.',
                              style: TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87)),
                            const SizedBox(height: 16),
                            _buildFeatureItem('Turn on/off specific lights'),
                            _buildFeatureItem('Set brightness levels'),
                            _buildFeatureItem('Control rooms or groups of lights'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                _buildSettingTile(
                  icon: Icons.color_lens_outlined,
                  title: 'App Theme',
                  subtitle: 'Change appearance and colors',
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                    activeColor: Colors.amber,
                  ),
                  onTap: () {
                    themeProvider.toggleTheme();
                  },
                ),
                
                const SizedBox(height: 24),
                
                // System settings
                Text(
                  'System',
                  style: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildSettingTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Panel',
                  subtitle: 'Access system logs and advanced settings',
                  trailing: Icon(Icons.chevron_right, 
                    color: themeProvider.isDarkMode ? Colors.grey : Colors.grey.shade700),
                  onTap: () {
                    // Navigate to admin login page
                    Navigator.pushNamed(context, '/admin_login');
                  },
                ),
                
                _buildSettingTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get assistance with the app',
                  trailing: Icon(Icons.chevron_right, 
                    color: themeProvider.isDarkMode ? Colors.grey : Colors.grey.shade700),
                  onTap: () {
                    // Navigate to help screen
                    Navigator.pushNamed(context, '/help');
                  },
                ),
                
                _buildSettingTile(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'App version and information',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onTap: () {
                    // Show about dialog
                    showAboutDialog(
                      context: context,
                      applicationName: 'Smart Home Lighting',
                      applicationVersion: 'v1.0.0',
                      applicationIcon: Image.asset('assets/icon/icon.png', width: 50, height: 50),
                      applicationLegalese: '© 2025 Smart Home Lighting. All rights reserved.',
                      children: [
                        const SizedBox(height: 16),
                        Text('Smart lighting control at your fingertips.',
                          style: TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87)),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFeatureItem(String text) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, 
            color: themeProvider.isDarkMode ? Colors.amber.shade400 : Colors.amber.shade700),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text, 
              style: TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Create screens on demand every time to reflect latest data
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Rebuild screens every time to reflect the latest data
    _screens.clear();
    _screens.addAll([
      _buildHomeScreen(),
      _buildSchedulesScreen(),
      _buildSensorsScreen(),
      _buildSettingsScreen(),
    ]);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: themeProvider.isDarkMode
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [Colors.grey.shade100, Colors.grey.shade50],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              )
            : _screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            elevation: 0,
            backgroundColor: themeProvider.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
            selectedItemColor: Colors.amber,
            unselectedItemColor: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.schedule_rounded),
                label: 'Schedules',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.sensors_rounded),
                label: 'Sensors',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}