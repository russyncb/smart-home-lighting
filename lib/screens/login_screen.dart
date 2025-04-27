// lib/screens/login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:illumi_home/screens/otp_verification_screen.dart';
import 'package:illumi_home/utils/formatters.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCountryCode = '+263';
  bool _isLoading = false;
  
  final List<Map<String, String>> _countryCodes = [
    {"code": "+263", "country": "Zimbabwe", "flag": "🇿🇼"},
    {"code": "+27", "country": "South Africa", "flag": "🇿🇦"},
    {"code": "+254", "country": "Kenya", "flag": "🇰🇪"},
    {"code": "+234", "country": "Nigeria", "flag": "🇳🇬"},
    {"code": "+256", "country": "Uganda", "flag": "🇺🇬"},
    {"code": "+255", "country": "Tanzania", "flag": "🇹🇿"},
    {"code": "+251", "country": "Ethiopia", "flag": "🇪🇹"},
    {"code": "+1", "country": "United States", "flag": "🇺🇸"},
    {"code": "+44", "country": "United Kingdom", "flag": "🇬🇧"},
    {"code": "+91", "country": "India", "flag": "🇮🇳"},
  ];

  void _sendVerificationCode() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '$_selectedCountryCode${_phoneController.text.trim()}',
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification on Android
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                verificationId: verificationId,
                phoneNumber: '$_selectedCountryCode${_phoneController.text.trim()}',
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // App name
                  const Text(
                    'Smart Home Lighting',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Tagline
                  const Text(
                    'Smart lighting at your fingertips',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Login card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign in to control your smart lighting system',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Phone input
                          const Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Country code dropdown
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF334155),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                  border: Border.all(color: Colors.grey.shade700),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedCountryCode,
                                  underline: Container(),
                                  dropdownColor: const Color(0xFF334155),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  items: _countryCodes.map((country) {
                                    return DropdownMenuItem<String>(
                                      value: country["code"],
                                      child: Row(
                                        children: [
                                          Text(country["flag"]!, style: const TextStyle(fontSize: 14)),
                                          const SizedBox(width: 4),
                                          Text(
                                            country["code"]!,
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCountryCode = value!;
                                    });
                                  },
                                ),
                              ),
                              
                              // Phone number input
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: '7X XXX XXXX',
                                    hintStyle: TextStyle(color: Colors.grey.shade500),
                                    filled: true,
                                    fillColor: const Color(0xFF334155),
                                    enabledBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(6),
                                        bottomRight: Radius.circular(6),
                                      ),
                                      borderSide: BorderSide(color: Color(0xFF475569)),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(6),
                                        bottomRight: Radius.circular(6),
                                      ),
                                      borderSide: BorderSide(color: Colors.amber),
                                    ),
                                  ),
                                  inputFormatters: [
                                    PhoneNumberFormatter(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendVerificationCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: Colors.amber.withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                                      ),
                                    )
                                  : const Text(
                                      'Send Verification Code',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Or divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.grey.shade700,
                                  thickness: 1,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.grey.shade700,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Email login option
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/email_login');
                              },
                              icon: const Icon(
                                Icons.email_outlined,
                                color: Colors.amber,
                              ),
                              label: const Text(
                                'Sign in with Email',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.amber),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Sign up link
                          Align(
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Don\'t have an account?',
                                  style: TextStyle(
                                    color: Colors.white70,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/email_signup');
                                  },
                                  child: const Text(
                                    'Sign up',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w500,
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
                  
                  // Footer
                  const SizedBox(height: 32),
                  const Text(
                    'SMART LIGHTING',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}