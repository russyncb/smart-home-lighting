// lib/services/voice_command_service.dart
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter/material.dart';
import 'package:illumi_home/models/room.dart';
import 'package:illumi_home/services/database_service.dart';

class VoiceCommandService {
  final SpeechToText _speechToText = SpeechToText();
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Callback for status updates
  final Function(bool isListening) onListeningStatusChanged;
  
  // Callback for displaying feedback to user
  final Function(String message) onFeedbackMessage;
  
  VoiceCommandService({
    required this.onListeningStatusChanged,
    required this.onFeedbackMessage,
  });
  
  Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        _isInitialized = await _speechToText.initialize();
        
        if (_isInitialized) {
          print("Speech recognition initialized successfully");
        } else {
          print("Failed to initialize speech recognition");
          onFeedbackMessage("Speech recognition not available on this device");
        }
      } catch (e) {
        print("Exception during speech recognition initialization: $e");
        onFeedbackMessage("Error initializing speech: $e");
        _isInitialized = false;
      }
    }
  }
  
  bool get isListening => _isListening;
  
  Future<void> toggleListening(List<Room> rooms) async {
    try {
      // Make sure we're initialized
      if (!_isInitialized) {
        await initialize();
      }
      
      // If already listening, stop
      if (_speechToText.isListening) {
        await _speechToText.stop();
        _isListening = false;
        onListeningStatusChanged(false);
        onFeedbackMessage("Stopped listening");
        return;
      }
      
      // Start listening if initialized
      if (_isInitialized) {
        _isListening = true;
        onListeningStatusChanged(true);
        
        // Simple approach like in your working example
        _speechToText.listen(
          onResult: (result) {
            if (result.finalResult) {
              print("Final recognized words: ${result.recognizedWords}");
              if (result.recognizedWords.isNotEmpty) {
                onFeedbackMessage("I heard: \"${result.recognizedWords}\"");
                _executeCommand(result.recognizedWords.toLowerCase(), rooms);
              } else {
                onFeedbackMessage("I didn't catch that. Please try again.");
              }
            }
          },
          onSoundLevelChange: (level) {
            // Could be used for visualization
          },
          listenMode: ListenMode.confirmation,
        );
        
        onFeedbackMessage("Listening... Say a command");
      } else {
        onFeedbackMessage("Speech recognition not available. Please check app permissions.");
      }
    } catch (e) {
      print("Error in toggleListening: $e");
      onFeedbackMessage("Error: $e");
      _isListening = false;
      onListeningStatusChanged(false);
    }
  }
  
  Future<void> _executeCommand(String command, List<Room> rooms) async {
    try {
      // Check if command is to turn something on or off
      bool turnOn = false;
      if (command.contains('turn on') || command.contains('switch on') || 
          command.contains('open') || command.startsWith('on ')) {
        turnOn = true;
      } else if (command.contains('turn off') || command.contains('switch off') || 
                command.contains('close') || command.startsWith('off ')) {
        turnOn = false;
      } else {
        // Check for brightness adjustment
        if (command.contains('brightness') || command.contains('percent') || 
            command.contains('dim') || command.contains('brighten')) {
          await _processBrightnessCommand(command, rooms);
          return;
        }
        
        onFeedbackMessage("I didn't understand that command. Try 'turn on/off [room] light'");
        return;
      }
      
      // Process command to identify which room/light to control
      Room? targetRoom;
      Light? targetLight;
      
      // Check for "all lights" command
      if (command.contains('all lights')) {
        await _controlAllLights(turnOn, rooms);
        return;
      }
      
      // Check for "indoor lights" or "outdoor lights" command
      if (command.contains('indoor lights') || command.contains('inside lights')) {
        await _databaseService.toggleAllLightsByType('indoor', turnOn);
        onFeedbackMessage("${turnOn ? 'Turned on' : 'Turned off'} all indoor lights");
        return;
      }
      
      if (command.contains('outdoor lights') || command.contains('outside lights')) {
        await _databaseService.toggleAllLightsByType('outdoor', turnOn);
        onFeedbackMessage("${turnOn ? 'Turned on' : 'Turned off'} all outdoor lights");
        return;
      }
      
      // Try to match room and light names
      for (final room in rooms) {
        final roomNameLower = room.name.toLowerCase();
        
        // Check if the command contains the room name
        if (command.contains(roomNameLower)) {
          targetRoom = room;
          
          // If the command mentions a specific light in this room
          for (final light in room.lights) {
            final lightNameLower = light.name.toLowerCase();
            if (command.contains(lightNameLower)) {
              targetLight = light;
              break;
            }
          }
          
          // If no specific light was mentioned but room was found,
          // target the first light in the room or all lights in the room
          if (targetLight == null) {
            if (room.lights.isNotEmpty) {
              // If command has "all" in it, turn all lights in the room on/off
              if (command.contains('all')) {
                await _databaseService.toggleAllLightsInRoom(room.id, turnOn);
                onFeedbackMessage("${turnOn ? 'Turned on' : 'Turned off'} all lights in ${room.name}");
                return;
              } else {
                // Otherwise, select the first light
                targetLight = room.lights.first;
              }
            }
          }
          
          break;
        }
      }
      
      // If no room was specifically matched, see if any light name matches directly
      if (targetRoom == null) {
        for (final room in rooms) {
          for (final light in room.lights) {
            final lightNameLower = light.name.toLowerCase();
            if (command.contains(lightNameLower)) {
              targetRoom = room;
              targetLight = light;
              break;
            }
          }
          if (targetRoom != null) break;
        }
      }
      
      // Execute the command if target was identified
      if (targetRoom != null && targetLight != null) {
        await _databaseService.toggleLight(targetRoom.id, targetLight.id, turnOn, source: 'voice_command');
        onFeedbackMessage("${turnOn ? 'Turned on' : 'Turned off'} ${targetLight.name} in ${targetRoom.name}");
      } else if (targetRoom != null) {
        onFeedbackMessage("Couldn't find a specific light in ${targetRoom.name}");
      } else {
        onFeedbackMessage("I couldn't identify which light to control. Please try again with a room or light name.");
      }
    } catch (e) {
      print("Error executing command: $e");
      onFeedbackMessage("Error executing command: $e");
    }
  }
  
  Future<void> _processBrightnessCommand(String command, List<Room> rooms) async {
    try {
      // Extract percentage value
      final percentageRegExp = RegExp(r'(\d+)(?:\s*%|\s*percent)');
      final percentageMatch = percentageRegExp.firstMatch(command);
      
      int brightness = 50; // Default if no specific percentage mentioned
      
      if (percentageMatch != null) {
        brightness = int.parse(percentageMatch.group(1)!);
      } else {
        // Check for keywords like "dim" or "brighten"
        if (command.contains('dim')) {
          brightness = 30;
        } else if (command.contains('brighten') || command.contains('brighter')) {
          brightness = 100;
        }
      }
      
      // Ensure brightness is within valid range
      brightness = brightness.clamp(1, 100);
      
      // Identify target room and light
      Room? targetRoom;
      Light? targetLight;
      
      for (final room in rooms) {
        final roomNameLower = room.name.toLowerCase();
        
        if (command.contains(roomNameLower)) {
          targetRoom = room;
          
          for (final light in room.lights) {
            final lightNameLower = light.name.toLowerCase();
            if (command.contains(lightNameLower)) {
              targetLight = light;
              break;
            }
          }
          
          if (targetLight == null && room.lights.isNotEmpty) {
            targetLight = room.lights.first;
          }
          
          break;
        }
      }
      
      // If no room was matched, try to match a light directly
      if (targetRoom == null) {
        for (final room in rooms) {
          for (final light in room.lights) {
            final lightNameLower = light.name.toLowerCase();
            if (command.contains(lightNameLower)) {
              targetRoom = room;
              targetLight = light;
              break;
            }
          }
          if (targetRoom != null) break;
        }
      }
      
      // Execute the brightness adjustment if target identified
      if (targetRoom != null && targetLight != null) {
        // Make sure light is on before adjusting brightness
        if (!targetLight.isOn) {
          await _databaseService.toggleLight(targetRoom.id, targetLight.id, true, source: 'voice_command');
        }
        
        await _databaseService.adjustBrightness(targetRoom.id, targetLight.id, brightness, source: 'voice_command');
        onFeedbackMessage("Set brightness of ${targetLight.name} to $brightness%");
      } else {
        onFeedbackMessage("I couldn't identify which light to adjust. Please try again specifying a room or light name.");
      }
    } catch (e) {
      print("Error processing brightness command: $e");
      onFeedbackMessage("Error adjusting brightness: $e");
    }
  }
  
  Future<void> _controlAllLights(bool turnOn, List<Room> rooms) async {
    try {
      await _databaseService.toggleAllLights(turnOn);
      onFeedbackMessage("${turnOn ? 'Turned on' : 'Turned off'} all lights");
    } catch (e) {
      print("Error controlling all lights: $e");
      onFeedbackMessage("Error controlling lights: $e");
    }
  }
  
  void dispose() {
    try {
      _speechToText.stop();
    } catch (e) {
      print("Error stopping speech recognition: $e");
    }
  }
}