// lib/screens/schedule_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:illumi_home/models/room.dart';
import 'package:illumi_home/models/schedule.dart';
import 'package:illumi_home/services/database_service.dart';
import 'package:illumi_home/services/theme_service.dart';
import 'package:provider/provider.dart';

class ScheduleEditScreen extends StatefulWidget {
  final bool isNew;
  final Schedule? schedule;

  const ScheduleEditScreen({
    Key? key,
    required this.isNew,
    this.schedule,
  }) : super(key: key);

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  TimeOfDay _scheduleTime = TimeOfDay.now();
  String _action = 'on';  // 'on' or 'off'
  bool _isActive = true;
  List<String> _selectedDays = ['Every day'];
  List<Room> _rooms = [];
  bool _isLoading = true;
  final List<ScheduleTarget> _selectedTargets = [];
  
  final List<String> _dayOptions = [
    'Every day',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadRooms();
    
    // Initialize form values if editing existing schedule
    if (!widget.isNew && widget.schedule != null) {
      final schedule = widget.schedule!;
      _nameController.text = schedule.name;
      
      // Parse time from string (format: "HH:MM")
      final timeParts = schedule.time.split(':');
      if (timeParts.length == 2) {
        _scheduleTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }
      
      _action = schedule.action;
      _isActive = schedule.isActive;
      _selectedDays = schedule.days;
      _selectedTargets.addAll(schedule.targets);
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadRooms() async {
    try {
      final rooms = await _databaseService.getRooms();
      
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading rooms: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _showTimePickerDialog() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _scheduleTime,
      builder: (context, child) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return Theme(
          data: ThemeData(
            colorScheme: ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              onSurface: themeProvider.isDarkMode ? Colors.white : Colors.black,
            ),
            dialogBackgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (selectedTime != null) {
      setState(() {
        _scheduleTime = selectedTime;
      });
    }
  }
  
  Future<void> _showDaySelectionDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    await showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelectedDays = List.from(_selectedDays);
        
        return AlertDialog(
          backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            'Select Days',
            style: TextStyle(
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._dayOptions.map((day) {
                      final isSelected = tempSelectedDays.contains(day);
                      
                      return CheckboxListTile(
                        title: Text(
                          day,
                          style: TextStyle(
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        value: isSelected,
                        activeColor: Colors.amber,
                        onChanged: (value) {
                          setStateDialog(() {
                            if (value == true) {
                              // Special handling for "Every day" option
                              if (day == 'Every day') {
                                tempSelectedDays = ['Every day'];
                              } else {
                                // Remove "Every day" if individual days are selected
                                tempSelectedDays.remove('Every day');
                                tempSelectedDays.add(day);
                              }
                            } else {
                              tempSelectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                // Ensure at least one day is selected
                if (tempSelectedDays.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select at least one day')),
                  );
                  return;
                }
                
                setState(() {
                  _selectedDays = tempSelectedDays;
                });
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _showTargetSelectionDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    await showDialog(
      context: context,
      builder: (context) {
        // Create a temporary list to track selections
        final tempSelectedTargets = List<ScheduleTarget>.from(_selectedTargets);
        bool allIndoor = tempSelectedTargets.any((t) => t.roomId == 'all_indoor' && t.allLightsInRoom == true);
        bool allOutdoor = tempSelectedTargets.any((t) => t.roomId == 'all_outdoor' && t.allLightsInRoom == true);
        bool allLights = tempSelectedTargets.any((t) => t.roomId == 'all' && t.allLightsInRoom == true);
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              title: Text(
                'Select Lights',
                style: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shortcut options
                    Text(
                      'Quick Selection',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All Lights'),
                          selected: allLights,
                          onSelected: (selected) {
                            setStateDialog(() {
                              if (selected) {
                                // Remove all other selections
                                tempSelectedTargets.clear();
                                // Add "all lights" target
                                tempSelectedTargets.add(
                                  ScheduleTarget(
                                    roomId: 'all',
                                    roomName: 'All Rooms',
                                    lightId: 'all',
                                    lightName: 'All Lights',
                                    allLightsInRoom: true,
                                  ),
                                );
                                allLights = true;
                                allIndoor = false;
                                allOutdoor = false;
                              } else {
                                // Remove "all lights" target
                                tempSelectedTargets.removeWhere(
                                  (t) => t.roomId == 'all' && t.allLightsInRoom == true,
                                );
                                allLights = false;
                              }
                            });
                          },
                          selectedColor: Colors.amber.withOpacity(0.2),
                          checkmarkColor: Colors.amber,
                        ),
                        FilterChip(
                          label: const Text('All Indoor'),
                          selected: allIndoor,
                          onSelected: (selected) {
                            setStateDialog(() {
                              if (selected) {
                                // Remove conflicting selections
                                tempSelectedTargets.removeWhere(
                                  (t) => t.roomId == 'all' || 
                                        (t.roomId != 'all_outdoor' && _getRoomType(t.roomId) == RoomType.indoor),
                                );
                                
                                // Add "all indoor" target
                                tempSelectedTargets.add(
                                  ScheduleTarget(
                                    roomId: 'all_indoor',
                                    roomName: 'All Indoor Rooms',
                                    lightId: 'all',
                                    lightName: 'All Lights',
                                    allLightsInRoom: true,
                                  ),
                                );
                                
                                allIndoor = true;
                                allLights = false;
                              } else {
                                // Remove "all indoor" target
                                tempSelectedTargets.removeWhere(
                                  (t) => t.roomId == 'all_indoor' && t.allLightsInRoom == true,
                                );
                                allIndoor = false;
                              }
                            });
                          },
                          selectedColor: Colors.amber.withOpacity(0.2),
                          checkmarkColor: Colors.amber,
                        ),
                        FilterChip(
                          label: const Text('All Outdoor'),
                          selected: allOutdoor,
                          onSelected: (selected) {
                            setStateDialog(() {
                              if (selected) {
                                // Remove conflicting selections
                                tempSelectedTargets.removeWhere(
                                  (t) => t.roomId == 'all' || 
                                        (t.roomId != 'all_indoor' && _getRoomType(t.roomId) == RoomType.outdoor),
                                );
                                
                                // Add "all outdoor" target
                                tempSelectedTargets.add(
                                  ScheduleTarget(
                                    roomId: 'all_outdoor',
                                    roomName: 'All Outdoor Rooms',
                                    lightId: 'all',
                                    lightName: 'All Lights',
                                    allLightsInRoom: true,
                                  ),
                                );
                                
                                allOutdoor = true;
                                allLights = false;
                              } else {
                                // Remove "all outdoor" target
                                tempSelectedTargets.removeWhere(
                                  (t) => t.roomId == 'all_outdoor' && t.allLightsInRoom == true,
                                );
                                allOutdoor = false;
                              }
                            });
                          },
                          selectedColor: Colors.amber.withOpacity(0.2),
                          checkmarkColor: Colors.amber,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    Divider(
                      color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Individual Lights',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // If any "all" options are selected, disable individual selection
                    if (allLights || allIndoor || allOutdoor)
                      Text(
                        'Deselect "All" options to select individual lights',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      )
                    else
                      // Individual room and light selection - in an Expanded to allow scrolling
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _rooms.length,
                          itemBuilder: (context, index) {
                            final room = _rooms[index];
                            
                            // Check if entire room is selected
                            final isRoomSelected = tempSelectedTargets.any(
                              (t) => t.roomId == room.id && t.allLightsInRoom == true,
                            );
                            
                            return ExpansionTile(
                              title: Text(
                                room.name,
                                style: TextStyle(
                                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              leading: Icon(
                                room.type == RoomType.indoor ? Icons.home : Icons.yard,
                                color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                              children: [
                                // Option to select entire room
                                CheckboxListTile(
                                  title: Text(
                                    'All lights in ${room.name}',
                                    style: TextStyle(
                                      color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  value: isRoomSelected,
                                  activeColor: Colors.amber,
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      if (value == true) {
                                        // Remove any individual lights from this room
                                        tempSelectedTargets.removeWhere(
                                          (t) => t.roomId == room.id,
                                        );
                                        
                                        // Add the whole room
                                        tempSelectedTargets.add(
                                          ScheduleTarget(
                                            roomId: room.id,
                                            roomName: room.name,
                                            lightId: 'all',
                                            lightName: 'All Lights',
                                            allLightsInRoom: true,
                                          ),
                                        );
                                      } else {
                                        // Remove the whole room
                                        tempSelectedTargets.removeWhere(
                                          (t) => t.roomId == room.id && t.allLightsInRoom == true,
                                        );
                                      }
                                    });
                                  },
                                ),
                                
                                // Divider
                                Divider(
                                  indent: 16,
                                  endIndent: 16,
                                  color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                ),
                                
                                // Individual lights (disabled if entire room is selected)
                                ...room.lights.map((light) {
                                  // Check if this light is selected
                                  final isSelected = tempSelectedTargets.any(
                                    (t) => t.roomId == room.id && t.lightId == light.id && t.allLightsInRoom != true,
                                  );
                                  
                                  return CheckboxListTile(
                                    title: Text(
                                      light.name,
                                      style: TextStyle(
                                        color: isRoomSelected 
                                            ? (themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400)
                                            : (themeProvider.isDarkMode ? Colors.white : Colors.black),
                                      ),
                                    ),
                                    value: isRoomSelected || isSelected,
                                    activeColor: Colors.amber,
                                    onChanged: isRoomSelected 
                                        ? null  // Disable if entire room is selected
                                        : (value) {
                                            setStateDialog(() {
                                              if (value == true) {
                                                // Add this light
                                                tempSelectedTargets.add(
                                                  ScheduleTarget(
                                                    roomId: room.id,
                                                    roomName: room.name,
                                                    lightId: light.id,
                                                    lightName: light.name,
                                                    allLightsInRoom: false,
                                                  ),
                                                );
                                              } else {
                                                // Remove this light
                                                tempSelectedTargets.removeWhere(
                                                  (t) => t.roomId == room.id && t.lightId == light.id && t.allLightsInRoom != true,
                                                );
                                              }
                                            });
                                          },
                                  );
                                }).toList(),
                              ],
                            );
                          },
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
                TextButton(
                  onPressed: () {
                    // Ensure at least one target is selected
                    if (tempSelectedTargets.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select at least one light')),
                      );
                      return;
                    }
                    
                    setState(() {
                      _selectedTargets.clear();
                      _selectedTargets.addAll(tempSelectedTargets);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  RoomType _getRoomType(String roomId) {
    final room = _rooms.firstWhere(
      (r) => r.id == roomId,
      orElse: () => Room(id: '', name: '', type: RoomType.indoor, lights: []),
    );
    return room.type;
  }
  
  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one light')),
      );
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Format time to HH:MM string
      final formattedTime = '${_scheduleTime.hour.toString().padLeft(2, '0')}:${_scheduleTime.minute.toString().padLeft(2, '0')}';
      
      // Create schedule data
      final scheduleData = {
        'name': _nameController.text,
        'time': formattedTime,
        'days': _selectedDays,
        'isActive': _isActive,
        'action': _action,
        'targets': _selectedTargets.map((target) => target.toMap()).toList(),
      };
      
      if (widget.isNew) {
        // Create new schedule
        await _databaseService.addSchedule(scheduleData);
      } else if (widget.schedule != null) {
        // Update existing schedule
        await _databaseService.updateSchedule(widget.schedule!.id, scheduleData);
      }
      
      // Return success
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving schedule: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew ? 'New Schedule' : 'Edit Schedule',
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveSchedule,
            icon: const Icon(Icons.save),
            label: const Text('SAVE'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.amber,
            ),
          ),
        ],
      ),
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
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Schedule Name',
                          labelStyle: TextStyle(
                            color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                          filled: true,
                          fillColor: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.amber),
                          ),
                        ),
                        style: TextStyle(
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Schedule time
                      Text(
                        'Schedule Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showTimePickerDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${_scheduleTime.hour == 0 ? 12 : (_scheduleTime.hour > 12 ? _scheduleTime.hour - 12 : _scheduleTime.hour)}:${_scheduleTime.minute.toString().padLeft(2, '0')} ${_scheduleTime.hour >= 12 ? 'PM' : 'AM'}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Schedule days
                      Text(
                        'Schedule Days',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showDaySelectionDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _selectedDays.contains('Every day') 
                                      ? 'Every day' 
                                      : _selectedDays.join(', '),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Schedule action (turn on/off)
                      Text(
                        'Action',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(
                                  'Turn ON',
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                value: 'on',
                                groupValue: _action,
                                onChanged: (value) {
                                  setState(() {
                                    _action = value!;
                                  });
                                },
                                activeColor: Colors.amber,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(
                                  'Turn OFF',
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                value: 'off',
                                groupValue: _action,
                                onChanged: (value) {
                                  setState(() {
                                    _action = value!;
                                  });
                                },
                                activeColor: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Selected lights
                      Text(
                        'Selected Lights',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showTargetSelectionDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lightbulb,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _selectedTargets.isEmpty
                                  ? Text(
                                      'Select lights to schedule',
                                      style: TextStyle(
                                        color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  : Text(
                                      _formatSelectedTargets(),
                                      style: TextStyle(
                                        color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Selected targets chips
                      if (_selectedTargets.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedTargets.map((target) {
                            String label = '';
                            
                            if (target.roomId == 'all' && target.allLightsInRoom == true) {
                              label = 'All Lights';
                            } else if (target.roomId == 'all_indoor' && target.allLightsInRoom == true) {
                              label = 'All Indoor Lights';
                            } else if (target.roomId == 'all_outdoor' && target.allLightsInRoom == true) {
                              label = 'All Outdoor Lights';
                            } else if (target.allLightsInRoom == true) {
                              label = 'All Lights in ${target.roomName}';
                            } else {
                              label = '${target.lightName} (${target.roomName})';
                            }
                            
                            return Chip(
                              label: Text(label),
                              backgroundColor: themeProvider.isDarkMode 
                                  ? Colors.grey.shade800 
                                  : Colors.grey.shade200,
                              labelStyle: TextStyle(
                                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                              ),
                              deleteIcon: const Icon(
                                Icons.cancel,
                                size: 18,
                              ),
                              onDeleted: () {
                                setState(() {
                                  _selectedTargets.remove(target);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Schedule active status
                      SwitchListTile(
                        title: Text(
                          'Schedule Active',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          _isActive ? 'This schedule will run automatically' : 'This schedule is disabled',
                          style: TextStyle(
                            color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        activeColor: Colors.amber,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            widget.isNew ? 'CREATE SCHEDULE' : 'SAVE CHANGES',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
  
  String _formatSelectedTargets() {
    if (_selectedTargets.isEmpty) {
      return 'No lights selected';
    }
    
    if (_selectedTargets.length == 1) {
      final target = _selectedTargets.first;
      
      if (target.roomId == 'all' && target.allLightsInRoom == true) {
        return 'All lights in all rooms';
      } else if (target.roomId == 'all_indoor' && target.allLightsInRoom == true) {
        return 'All indoor lights';
      } else if (target.roomId == 'all_outdoor' && target.allLightsInRoom == true) {
        return 'All outdoor lights';
      } else if (target.allLightsInRoom == true) {
        return 'All lights in ${target.roomName}';
      } else {
        return '${target.lightName} in ${target.roomName}';
      }
    } else {
      return '${_selectedTargets.length} lights selected';
    }
  }
}