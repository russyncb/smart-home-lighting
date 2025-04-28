// lib/services/voice_command_service.dart
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter/material.dart';
import 'package:illumi_home/models/room.dart';
import 'package:illumi_home/services/database_service.dart';
import 'package:permission_handler/permission_handler.dart';

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
      // First request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        onFeedbackMessage("Microphone permission denied");
        return;
      }
      
      try {
        _isInitialized = await _speechToText.initialize(
          onError: (error) {
            print("Speech recognition error: $error");
            onFeedbackMessage("Error: $error");
          },
          onStatus: (status) {
            print("Speech recognition status: $status");
            if (status == "done" || status == "notListening") {
              _isListening = false;
              onListeningStatusChanged(false);
            }
          },
          debugLogging: true, // Enable debugging
        );
        
        if (_isInitialized) {
          print("Speech recognition initialized successfully");
          // Get available locales to diagnose issues
          final locales = await _speechToText.locales();
          print("Available locales: ${locales.map((l) => l.localeId).join(', ')}");
        } else {
          print("Failed to initialize speech recognition");
          onFeedbackMessage("Speech recognition not available on this device");
        }
      } catch (e) {
        print("Exception during speech recognition initialization: $e");
        onFeedbackMessage("Error initializing speech: $e");
      }
    }
  }
  
  bool get isListening => _isListening;
  
  Future<void> toggleListening(List<Room> rooms) async {
    await initialize();
    
    if (_speechToText.isListening) {
      await _speechToText.stop();
      _isListening = false;
      onListeningStatusChanged(false);
      onFeedbackMessage("Stopped listening");
      return;
    }
    
    if (_isInitialized) {
      try {
        // Get available locales
        final locales = await _speechToText.locales();
        String localeId = "en_US";
        
        // Try to find a compatible locale
        if (!locales.any((locale) => locale.localeId == "en_US")) {
          // If en_US is not available, try to find any English locale
          final englishLocales = locales.where((locale) => 
            locale.localeId.startsWith("en_") || locale.localeId == "en");
          
          if (englishLocales.isNotEmpty) {
            localeId = englishLocales.first.localeId;
            print("Using alternative English locale: $localeId");
          } else if (locales.isNotEmpty) {
            // If no English locale, use the first available
            localeId = locales.first.localeId;
            print("No English locale available, using: $localeId");
          }
        }
        
        _isListening = await _speechToText.listen(
          onResult: (result) => _processVoiceResult(result, rooms),
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,  // Changed to true to get more feedback
          localeId: localeId,
          cancelOnError: false,  // Don't cancel on error
          onSoundLevelChange: (level) {
            // Optional: can be used to show a visual indicator of sound level
            // print("Sound level: $level");
          },
        );
        
        if (_isListening) {
          onFeedbackMessage("Listening... Say a command");
        } else {
          onFeedbackMessage("Couldn't start listening. Please try again.");
        }
        
        onListeningStatusChanged(_isListening);
      } catch (e) {
        print("Exception during speech listening: $e");
        onFeedbackMessage("Error starting speech recognition: $e");
        _isListening = false;
        onListeningStatusChanged(false);
      }
    } else {
      onFeedbackMessage("Speech recognition not available. Please check app permissions.");
    }
  }
  
  void _processVoiceResult(SpeechRecognitionResult result, List<Room> rooms) async {
    // Show partial results to give user feedback
    if (result.recognizedWords.isNotEmpty && !result.finalResult) {
      print("Partial result: ${result.recognizedWords}");
      // Optionally show partial results
      // onFeedbackMessage("I heard: \"${result.recognizedWords}\"");
    }
    
    if (result.finalResult && result.recognizedWords.isNotEmpty) {
      final command = result.recognizedWords.toLowerCase();
      print("Final result: $command");
      
      onFeedbackMessage("I heard: \"$command\"");
      
      // Process the command
      await _executeCommand(command, rooms);
    } else if (result.finalResult && result.recognizedWords.isEmpty) {
      onFeedbackMessage("I didn't catch that. Please try again.");
    }
  }
  
  Future<void> _executeCommand(String command, List<Room> rooms) async {
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
  }
  
  Future<void> _processBrightnessCommand(String command, List<Room> rooms) async {
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
  }
  
  Future<void> _controlAllLights(bool turnOn, List<Room> rooms) async {
    await _databaseService.toggleAllLights(turnOn);
    onFeedbackMessage("${turnOn ? 'Turned on' : 'Turned off'} all lights");
  }
  
  void dispose() {
    _speechToText.stop();
  }
}