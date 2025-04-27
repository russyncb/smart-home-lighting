// lib/utils/formatters.dart
import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // First, get the text without any formatting
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    // Limit to maximum 10 digits
    if (text.length > 10) {
      text = text.substring(0, 10);
    }
    
    // Apply formatting based on length
    String formattedText = '';
    
    if (text.isEmpty) {
      formattedText = '';
    } else if (text.length < 4) {
      // Format: 7X
      formattedText = text;
    } else if (text.length < 7) {
      // Format: 7X XXX
      formattedText = '${text.substring(0, 3)} ${text.substring(3)}';
    } else {
      // Format: 7X XXX XXXX
      formattedText = '${text.substring(0, 3)} ${text.substring(3, 6)} ${text.substring(6)}';
    }
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}