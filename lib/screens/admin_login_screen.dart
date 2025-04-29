// lib/screens/admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:illumi_home/services/theme_service.dart';
import 'package:provider/provider.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final List<TextEditingController> _pinControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );
  
  bool _isError = false;
  String _errorMessage = '';
  bool _isLoading = false;
  
  @override
  void dispose() {
    for (final controller in _pinControllers) {
      controller.dispose();
    }
    for (final node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
  
  void _verifyPin() {
    final enteredPin = _pinControllers.map((controller) => controller.text).join();
    
    setState(() {
      _isLoading = true;
    });
    
    // Simulate verification delay
    Future.delayed(const Duration(seconds: 1), () {
      if (enteredPin == '123456') {
        // Correct PIN
        setState(() {
          _isError = false;
          _isLoading = false;
        });
        
        // Navigate to admin logs screen
        Navigator.pushReplacementNamed(context, '/admin_logs');
      } else {
        // Incorrect PIN
        setState(() {
          _isError = true;
          _errorMessage = 'Invalid PIN. Please try again.';
          _isLoading = false;
          
          // Clear PIN fields
          for (final controller in _pinControllers) {
            controller.clear();
          }
          
          // Focus on first field
          if (_pinFocusNodes.isNotEmpty) {
            _pinFocusNodes.first.requestFocus();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // Get screen size
    final size = MediaQuery.of(context).size;
    // Calculate a smaller width for PIN fields to ensure no overflow
    // Take 70% of screen width for all fields combined with spacing
    final availableWidth = size.width * 0.7;
    final pinFieldWidth = (availableWidth / 6) - 4; // 4 pixels for margins
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Login',
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Admin icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.amber,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Admin Access',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Subtitle
                Text(
                  'Enter 6-digit PIN to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 48),
                
                // PIN input fields
                // Contain them in a fixed width container to avoid overflow
                Container(
                  width: availableWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      6,
                      (index) => Container(
                        width: pinFieldWidth,
                        height: 56, // Slightly reduced height
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: TextField(
                          controller: _pinControllers[index],
                          focusNode: _pinFocusNodes[index],
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          obscureText: true,
                          obscuringCharacter: '•',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22, // Slightly smaller font
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: themeProvider.isDarkMode 
                                ? const Color(0xFF1E293B) 
                                : Colors.grey.shade200,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10), // Smaller radius
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _isError ? Colors.red : Colors.amber,
                                width: 1.5, // Thinner border
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            // When a digit is entered, move to next field
                            if (value.isNotEmpty && index < 5) {
                              _pinFocusNodes[index + 1].requestFocus();
                            }
                            
                            // If all digits are entered, verify PIN
                            if (index == 5 && value.isNotEmpty) {
                              final allFilled = _pinControllers.every(
                                (controller) => controller.text.isNotEmpty
                              );
                              if (allFilled) {
                                _verifyPin();
                              }
                            }
                            
                            // Clear error when user starts typing again
                            if (_isError) {
                              setState(() {
                                _isError = false;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Error message
                if (_isError) ...[
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                
                // Continue button
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.amber.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                            ),
                          )
                        : const Text(
                            'VERIFY',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                // Hint for PIN
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hint: The default admin PIN is obvious',
                          style: TextStyle(
                            color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}