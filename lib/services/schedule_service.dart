// lib/services/schedule_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:illumi_home/models/schedule.dart';
import 'package:illumi_home/services/database_service.dart';

class ScheduleService {
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Timer? _timer;
  List<Schedule> _schedules = [];
  Map<String, DateTime> _lastExecutedSchedules = {};

  // Start the schedule service
  void startScheduleService() {
    // Cancel any existing timer
    _timer?.cancel();
    
    // Create a timer that checks every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkSchedules();
    });
    
    // Do an initial check immediately
    _checkSchedules();
    
    print('Schedule service started');
  }
  
  // Stop the schedule service
  void stopScheduleService() {
    _timer?.cancel();
    _timer = null;
    print('Schedule service stopped');
  }
  
  // Load schedules from Firestore
  Future<void> _loadSchedules() async {
    try {
      final snapshot = await _firestore.collection('schedules').get();
      _schedules = snapshot.docs
          .map((doc) => Schedule.fromMap(doc.data(), doc.id))
          .toList();
      print('Loaded ${_schedules.length} schedules');
    } catch (e) {
      print('Error loading schedules: $e');
    }
  }
  
  // Check if any schedules need to be executed
  Future<void> _checkSchedules() async {
    await _loadSchedules();
    
    final now = DateTime.now();
    final currentMinute = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    for (final schedule in _schedules) {
      // Skip inactive schedules
      if (!schedule.isActive) continue;
      
      // Skip schedules that don't apply to today
      if (!schedule.shouldRunToday(now)) continue;
      
      // Check if the schedule time matches current time
      if (schedule.time == currentMinute) {
        // Check if we've already executed this schedule in the last 2 minutes (avoid double execution)
        final lastExecuted = _lastExecutedSchedules[schedule.id];
        if (lastExecuted != null) {
          final difference = now.difference(lastExecuted).inMinutes;
          if (difference < 2) {
            // Skip - we executed this schedule very recently
            continue;
          }
        }
        
        // Execute the schedule
        print('Executing schedule: ${schedule.name} (${schedule.action})');
        await _databaseService.executeScheduleAction(schedule.targets, schedule.action);
        
        // Record execution time
        _lastExecutedSchedules[schedule.id] = now;
      }
    }
  }
  
  // Check if a specific schedule should be executed now (for testing/manual execution)
  Future<bool> executeScheduleNow(String scheduleId) async {
    try {
      final doc = await _firestore.collection('schedules').doc(scheduleId).get();
      if (!doc.exists) return false;
      
      final schedule = Schedule.fromMap(doc.data()!, doc.id);
      
      // Skip inactive schedules
      if (!schedule.isActive) return false;
      
      // Execute the schedule
      print('Manually executing schedule: ${schedule.name} (${schedule.action})');
      await _databaseService.executeScheduleAction(schedule.targets, schedule.action);
      
      // Record execution time
      _lastExecutedSchedules[schedule.id] = DateTime.now();
      
      return true;
    } catch (e) {
      print('Error executing schedule: $e');
      return false;
    }
  }
}