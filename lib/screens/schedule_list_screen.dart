// lib/screens/schedule_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:illumi_home/models/schedule.dart';
import 'package:illumi_home/screens/schedule_edit_screen.dart';
import 'package:illumi_home/services/database_service.dart';
import 'package:illumi_home/services/schedule_service.dart';
import 'package:illumi_home/services/theme_service.dart';
import 'package:provider/provider.dart';

class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  State<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final ScheduleService _scheduleService = ScheduleService();
  
  List<Schedule> _schedules = [];
  bool _isLoading = true;
  StreamSubscription? _schedulesSubscription;
  
  @override
  void initState() {
    super.initState();
    _subscribeToSchedules();
  }
  
  @override
  void dispose() {
    _schedulesSubscription?.cancel();
    super.dispose();
  }
  
  void _subscribeToSchedules() {
    setState(() {
      _isLoading = true;
    });
    
    _schedulesSubscription?.cancel();
    _schedulesSubscription = _databaseService.getSchedulesStream().listen(
      (schedules) {
        if (mounted) {
          setState(() {
            _schedules = schedules;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        print('Error in schedules stream: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading schedules: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    );
  }
  
  Future<void> _addNewSchedule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScheduleEditScreen(
          isNew: true,
        ),
      ),
    );
    
    if (result == true) {
      // Schedule was added, refresh happens automatically via Stream
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule added successfully')),
      );
    }
  }
  
  Future<void> _editSchedule(Schedule schedule) async {
    final result = await Navigator.pushNamed(
      context,
      '/schedule/edit/${schedule.id}',
      arguments: schedule,
    );
    
    if (result == true) {
      // Schedule was updated, refresh happens automatically via Stream
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule updated successfully')),
      );
    }
  }
  
  Future<void> _toggleScheduleStatus(Schedule schedule) async {
    try {
      await _databaseService.toggleSchedule(
        schedule.id,
        !schedule.isActive,
      );
      
      String message = schedule.isActive 
        ? 'Schedule deactivated' 
        : 'Schedule activated';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling schedule: $e')),
      );
    }
  }
  
  Future<void> _deleteSchedule(Schedule schedule) async {
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Schedule'),
          content: Text('Are you sure you want to delete "${schedule.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
      
      await _databaseService.deleteSchedule(schedule.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting schedule: $e')),
      );
    }
  }
  
  Future<void> _runScheduleNow(Schedule schedule) async {
    try {
      final result = await _scheduleService.executeScheduleNow(schedule.id);
      
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Schedule "${schedule.name}" executed')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to execute schedule')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error executing schedule: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
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
                        color: Colors.orange.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Schedules',
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
                Icons.add_circle_outline,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: _addNewSchedule,
            ),
            const SizedBox(width: 10),
          ],
        ),
        
        // Loading indicator or empty state
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          ),
        
        // Empty state
        if (!_isLoading && _schedules.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 64,
                    color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No schedules found',
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a schedule to automate your lights',
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _addNewSchedule,
                    icon: const Icon(Icons.add),
                    label: const Text('ADD SCHEDULE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // List of schedules
        if (!_isLoading && _schedules.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final schedule = _schedules[index];
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                        title: Text(
                          schedule.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: schedule.action == 'on' 
                                        ? Colors.green.withOpacity(0.2) 
                                        : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    schedule.action == 'on' ? 'Turn ON' : 'Turn OFF',
                                    style: TextStyle(
                                      color: schedule.action == 'on' ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  schedule.formattedTime,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTargets(schedule.targets),
                              style: TextStyle(
                                color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Days: ${schedule.formattedDays}',
                              style: TextStyle(
                                color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        trailing: Switch(
                          value: schedule.isActive,
                          onChanged: (value) => _toggleScheduleStatus(schedule),
                          activeColor: Colors.amber,
                        ),
                      ),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _runScheduleNow(schedule),
                            icon: const Icon(
                              Icons.play_arrow_outlined,
                              size: 16,
                            ),
                            label: const Text('Run Now'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _editSchedule(schedule),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                            ),
                            label: const Text('Edit'),
                            style: TextButton.styleFrom(
                              foregroundColor: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _deleteSchedule(schedule),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 16,
                            ),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade300,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                );
              },
              childCount: _schedules.length,
            ),
          ),
      ],
    );
  }
  
  String _formatTargets(List<ScheduleTarget> targets) {
    if (targets.isEmpty) {
      return 'No lights selected';
    }
    
    if (targets.length == 1) {
      final target = targets.first;
      
      if (target.roomId == 'all_indoor' || target.allLightsInRoom == true && target.roomId == 'all_indoor') {
        return 'All indoor lights';
      } else if (target.roomId == 'all_outdoor' || target.allLightsInRoom == true && target.roomId == 'all_outdoor') {
        return 'All outdoor lights';
      } else if (target.roomId == 'all' || target.allLightsInRoom == true && target.roomId == 'all') {
        return 'All lights';
      } else if (target.allLightsInRoom == true) {
        return 'All lights in ${target.roomName ?? 'unknown room'}';
      } else {
        return '${target.lightName ?? 'Unknown light'} in ${target.roomName ?? 'unknown room'}';
      }
    } else {
      // Multiple targets
      return '${targets.length} lights in ${_countUniqueRooms(targets)} rooms';
    }
  }
  
  int _countUniqueRooms(List<ScheduleTarget> targets) {
    final uniqueRooms = targets.map((t) => t.roomId).toSet();
    return uniqueRooms.length;
  }
}