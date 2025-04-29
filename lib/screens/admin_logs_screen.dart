// lib/screens/admin_logs_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:illumi_home/services/theme_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  String _filterType = 'All';
  final List<String> _filterOptions = [
    'All', 
    'Light Toggle', 
    'Brightness', 
    'Motion Sensor',
    'Voice Command',
    'Schedule',
    'Room Actions',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }
  
  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      Query query = _firestore
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(100);
      
      // Apply filter if not "All"
      if (_filterType == 'Light Toggle') {
        query = query.where('action', isEqualTo: 'toggle_light');
      } else if (_filterType == 'Brightness') {
        query = query.where('action', isEqualTo: 'adjust_brightness');
      } else if (_filterType == 'Motion Sensor') {
        query = query.where('action', isEqualTo: 'toggle_motion_sensor');
      } else if (_filterType == 'Voice Command') {
        // Filter by source being voice_command
        query = query.where('details.source', isEqualTo: 'voice_command');
      } else if (_filterType == 'Schedule') {
        // Filter by schedule actions
        query = query.where('action', whereIn: ['schedule_on', 'schedule_off']);
      } else if (_filterType == 'Room Actions') {
        // Filter by room-related actions
        query = query.where('action', whereIn: ['add_room', 'delete_room', 'toggle_room_lights']);
      }
      
      final snapshot = await query.get();
      
      // Convert to list of maps
      final logs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Add document ID to the data
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading logs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading logs: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      if (timestamp is Timestamp) {
        final dateTime = timestamp.toDate();
        return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
      }
      return 'Invalid timestamp';
    } catch (e) {
      return 'Invalid date';
    }
  }
  
  String _formatAction(String action, Map<String, dynamic> log) {
    final details = log['details'] as Map<String, dynamic>?;
    if (details == null) return action;
    
    // Check if this is a voice command
    final source = details['source'];
    final isVoiceCommand = source == 'voice_command';
    
    switch (action) {
      case 'toggle_light':
        final newState = details['newState'] ?? false;
        final lightName = details['lightName'] ?? 'Unknown light';
        String result = '${newState ? 'Turned ON' : 'Turned OFF'} $lightName';
        if (isVoiceCommand) {
          result += ' (Voice)';
        }
        return result;
        
      case 'adjust_brightness':
        final brightness = details['brightness'] ?? 0;
        final lightName = details['lightName'] ?? 'Unknown light';
        String result = 'Set $lightName brightness to $brightness%';
        if (isVoiceCommand) {
          result += ' (Voice)';
        }
        return result;
        
      case 'toggle_motion_sensor':
        final enabled = details['enabled'] ?? false;
        final lightName = details['lightName'] ?? 'Unknown light';
        return '${enabled ? 'Enabled' : 'Disabled'} motion sensor for $lightName';
        
      case 'schedule_on':
        return 'Schedule activated: turned ON lights';
        
      case 'schedule_off':
        return 'Schedule activated: turned OFF lights';
        
      case 'add_room':
        final roomName = details['roomName'] ?? 'Unknown room';
        final roomType = details['roomType'] ?? 'Unknown';
        return 'Added new $roomType room: $roomName';
        
      case 'delete_room':
        final roomName = details['roomName'] ?? 'Unknown room';
        return 'Deleted room: $roomName';
        
      case 'toggle_room_lights':
        final roomName = details['roomName'] ?? 'Unknown room';
        final newState = details['newState'] ?? false;
        return '${newState ? 'Turned ON' : 'Turned OFF'} all lights in $roomName';
        
      case 'toggle_all_lights':
        final newState = details['newState'] ?? false;
        final category = details['category'] ?? 'all';
        String categoryDisplay = 'all';
        if (category == 'all_indoor') categoryDisplay = 'indoor';
        if (category == 'all_outdoor') categoryDisplay = 'outdoor';
        return '${newState ? 'Turned ON' : 'Turned OFF'} all $categoryDisplay lights';
        
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _getActionIcon(String action, Map<String, dynamic>? details) {
    // Check if this is a voice command
    final isVoiceCommand = details != null && details['source'] == 'voice_command';
    
    if (isVoiceCommand) {
      return Icons.mic;
    }
    
    switch (action) {
      case 'toggle_light':
        return Icons.lightbulb;
      case 'adjust_brightness':
        return Icons.brightness_medium;
      case 'toggle_motion_sensor':
        return Icons.sensors;
      case 'schedule_on':
      case 'schedule_off':
        return Icons.schedule;
      case 'add_room':
        return Icons.add_home;
      case 'delete_room':
        return Icons.delete_sweep;
      case 'toggle_room_lights':
      case 'toggle_all_lights':
        return Icons.lightbulb_outline;
      default:
        return Icons.touch_app;
    }
  }

  Color _getActionColor(String action, Map<String, dynamic>? details) {
    // Check if this is a voice command
    final isVoiceCommand = details != null && details['source'] == 'voice_command';
    
    if (isVoiceCommand) {
      return Colors.purple;
    }
    
    switch (action) {
      case 'toggle_light':
        return Colors.amber;
      case 'adjust_brightness':
        return Colors.orange;
      case 'toggle_motion_sensor':
        return Colors.indigo;
      case 'schedule_on':
      case 'schedule_off':
        return Colors.teal;
      case 'add_room':
        return Colors.green;
      case 'delete_room':
        return Colors.red;
      case 'toggle_room_lights':
      case 'toggle_all_lights':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Get the user identifier (email or phone)
  String _getUserIdentifier(Map<String, dynamic> log) {
    // First try email
    final email = log['email'];
    if (email != null && email.toString().isNotEmpty) {
      return email.toString();
    }
    
    // Then try phone number
    final phone = log['phoneNumber'];
    if (phone != null && phone.toString().isNotEmpty) {
      return phone.toString();
    }
    
    // Finally try generic identifier field
    final identifier = log['identifier'];
    if (identifier != null && identifier.toString().isNotEmpty) {
      return identifier.toString();
    }
    
    return 'Unknown user';
  }

  // Get icon based on user type (email or phone)
  IconData _getUserIcon(Map<String, dynamic> log) {
    final email = log['email'];
    if (email != null && email.toString().isNotEmpty) {
      return Icons.email;
    }
    return Icons.phone_android;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Activity Logs',
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter dialog
              _showFilterDialog();
            },
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
        child: Column(
          children: [
            // Filter indicator
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 18,
                    color: themeProvider.isDarkMode ? Colors.amber : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Filter: $_filterType',
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_filterType != 'All')
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterType = 'All';
                        });
                        _loadLogs();
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: themeProvider.isDarkMode ? Colors.amber : Colors.amber.shade800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Logs list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    )
                  : _logs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No activity logs found',
                                style: TextStyle(
                                  color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _logs.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final action = log['action'] as String? ?? 'Unknown action';
                            final details = log['details'] as Map<String, dynamic>?;
                            
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
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _getActionColor(action, details).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getActionIcon(action, details),
                                    color: _getActionColor(action, details),
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  _formatAction(action, log),
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          _getUserIcon(log),
                                          size: 14,
                                          color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _getUserIdentifier(log),
                                            style: TextStyle(
                                              color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(log['timestamp']),
                                      style: TextStyle(
                                        color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  color: Colors.grey.shade500,
                                  onPressed: () {
                                    // Show log details
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => _buildLogDetailsSheet(context, log),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showFilterDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Filter Activity Logs',
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _filterOptions.map((filter) {
              final isSelected = _filterType == filter;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.amber : (themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade700),
                ),
                title: Text(
                  filter,
                  style: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _filterType = filter;
                  });
                  Navigator.pop(context);
                  _loadLogs();
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogDetailsSheet(BuildContext context, Map<String, dynamic> log) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final details = log['details'] as Map<String, dynamic>? ?? {};
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          Text(
            'Log Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailRow('Action', log['action'] ?? 'Unknown'),
          _buildDetailRow('User ID', log['userId'] ?? 'Unknown'),
          
          // Show email if available
          if (log['email'] != null && log['email'].toString().isNotEmpty)
            _buildDetailRow('Email', log['email']),
          
          // Show phone if available
          if (log['phoneNumber'] != null && log['phoneNumber'].toString().isNotEmpty)
            _buildDetailRow('Phone', log['phoneNumber']),
            
          _buildDetailRow('Room ID', log['roomId'] ?? 'Unknown'),
          _buildDetailRow('Light ID', log['lightId'] ?? 'Unknown'),
          _buildDetailRow('Timestamp', _formatTimestamp(log['timestamp'])),
          
          // Source information - highlight this for voice commands
          if (details.containsKey('source')) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: details['source'] == 'voice_command' 
                    ? Colors.purple.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Source: ${details['source']}',
                style: TextStyle(
                  color: details['source'] == 'voice_command' ? Colors.purple : Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          Text(
            'Additional Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          ...details.entries
              .where((entry) => entry.key != 'source') // Skip source since we display it above
              .map((entry) => _buildDetailRow(
                entry.key.toString().replaceFirst(entry.key[0], entry.key[0].toUpperCase()),
                entry.value.toString(),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('CLOSE'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}