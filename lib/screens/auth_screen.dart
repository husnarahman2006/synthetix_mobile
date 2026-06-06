import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/synthetix_constants.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;
  bool _isLoading = false;

  // 🟢 NEW: State variables to track password rules in real-time
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🟢 NEW: Function triggered every time the user types in the password box
  void _onPasswordChanged(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    });
  }

  Future<void> _handleAuthSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Please fill in all authorization fields.", Colors.orangeAccent);
      return;
    }

    // Check if all rules are green before creating an account
    if (!_isLoginMode) {
      if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
        _showSnackBar("Please meet all password requirements first.", Colors.orangeAccent);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (error) {
      _showSnackBar(error.message ?? "An authentication error occurred.", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor, duration: const Duration(seconds: 3)),
    );
  }

  // 🟢 NEW: Helper widget to draw each rule row (Red Cross or Green Check)
  Widget _buildRequirementRow(bool isMet, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.black54,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.bolt, size: 84, color: SynthetixConstants.primaryColor),
              const SizedBox(height: 12),

              const Text(
                "SYNTHETIX",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black87, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 3),
              ),
              const Text(
                "Secure Access Portal",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Email Address",
                  labelStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: const Icon(Icons.alternate_email, color: Colors.black54),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)
                  ),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: SynthetixConstants.primaryColor, width: 2)
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                onChanged: _onPasswordChanged, // 🟢 Triggers the real-time check!
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)
                  ),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: SynthetixConstants.primaryColor, width: 2)
                  ),
                ),
              ),

              // 🟢 NEW: The dynamic requirements card that only shows during Registration
              if (!_isLoginMode)
                Container(
                  margin: const EdgeInsets.only(top: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Password Requirements",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      _buildRequirementRow(_hasMinLength, "8+ characters"),
                      _buildRequirementRow(_hasUppercase, "One uppercase letter"),
                      _buildRequirementRow(_hasLowercase, "One lowercase letter"),
                      _buildRequirementRow(_hasNumber, "One number"),
                      _buildRequirementRow(_hasSpecialChar, "One special character (@#\$%&...)"),
                    ],
                  ),
                ),

              const SizedBox(height: 28),

              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: SynthetixConstants.primaryColor))
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SynthetixConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _handleAuthSubmit,
                child: Text(_isLoginMode ? "Sign In" : "Register Account", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () => setState(() {
                  _isLoginMode = !_isLoginMode;
                  _passwordController.clear();
                  _onPasswordChanged(""); // Reset the checks when switching modes
                }),
                child: Text.rich(
                  TextSpan(
                    text: _isLoginMode ? "New to Synthetix? " : "Already registered? ",
                    style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: _isLoginMode ? "Create an account" : "Sign in here",
                        style: const TextStyle(color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}