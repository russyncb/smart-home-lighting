// lib/widgets/voice_command_button.dart
import 'package:flutter/material.dart';

class VoiceCommandButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onPressed;
  final AnimationController animationController;

  const VoiceCommandButton({
    super.key,
    required this.isListening,
    required this.onPressed,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedBuilder(
        animation: animationController,
        builder: (context, child) {
          return Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isListening 
                    ? [Colors.red.shade400, Colors.red.shade700]
                    : [Colors.amber.shade400, Colors.amber.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isListening 
                      ? Colors.red.withOpacity(0.3) 
                      : Colors.amber.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: animationController.value * 5,
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 20,
            ),
          );
        },
      ),
    );
  }
}