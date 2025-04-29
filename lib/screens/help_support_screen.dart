// lib/screens/help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:illumi_home/services/theme_service.dart';
import 'package:provider/provider.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & Support',
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Big bold message
              const Text(
                'YOU\'RE ON YOUR OWN',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Crying emoji
              const Text(
                '😭🙏🏾',
                style: TextStyle(
                  fontSize: 80,
                ),
              ),
              const SizedBox(height: 32),
              
              // Explanation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'No support available at this time. Try turning it off, and on again.',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              
              // "Helpful" tips
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unhelpful Tips:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildUnhelpfulTip(
                      context, 
                      'Have you tried turning it off and on again?',
                    ),
                    _buildUnhelpfulTip(
                      context, 
                      'Maybe your lights are just broken?',
                    ),
                    _buildUnhelpfulTip(
                      context, 
                      'Check if your electricity bill is paid.',
                    ),
                    _buildUnhelpfulTip(
                      context, 
                      'Try using candles instead?',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // "Contact" button
              ElevatedButton.icon(
                onPressed: () {
                  // Show unhelpful message
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                      title: Text(
                        'Contact Us',
                        style: TextStyle(
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      content: Text(
                        'Our support team is currently on vacation... like forever.',
                        style: TextStyle(
                          color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('FINE'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.contact_support),
                label: const Text('Contact Support'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildUnhelpfulTip(BuildContext context, String text) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb,
            size: 18,
            color: Colors.amber,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}