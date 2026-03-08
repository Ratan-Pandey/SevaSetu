import 'dart:io';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  /// KEEP YOUR EXISTING LOGIN LOGIC HERE
  Future<void> _login() async {

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {

      /// YOUR BACKEND LOGIN CALL HERE
      /// Example:
      /// await AuthService.login(
      ///   _emailController.text,
      ///   _passwordController.text,
      /// );

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login failed"),
        ),
      );

    }

    setState(() {
      _isLoading = false;
    });
  }

  /// DISPOSE CONTROLLERS (BEST PRACTICE)
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1F2937),
              Color(0xFF111827),
            ],
          ),
        ),

        child: Center(
          child: Container(
            width: 900,
            padding: const EdgeInsets.all(40),

            decoration: BoxDecoration(
              color: const Color(0xFF1F2937).withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),

            child: Row(
              children: [

                /// LEFT SIDE
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      Image.file(
                        File(
                          r"C:\Users\sanvi\Downloads\SevaSetu-main (1) - Copy\SevaSetu-main\logo.png",
                        ),
                        height: 90,
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "SEVA SETU",
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),

                    ],
                  ),
                ),

                const SizedBox(width: 40),

                /// RIGHT LOGIN CARD
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(30),

                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(18),
                    ),

                    child: Form(
                      key: _formKey,

                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          const Text(
                            "Sign In",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            "Enter your credentials to continue",
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),

                          const SizedBox(height: 25),

                          /// EMAIL FIELD
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.white),

                            decoration: InputDecoration(
                              hintText: "Email Address",
                              hintStyle:
                                  const TextStyle(color: Colors.white54),

                              filled: true,
                              fillColor: const Color(0xFF1F2937),

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),

                              prefixIcon: const Icon(
                                Icons.email,
                                color: Colors.white70,
                              ),
                            ),

                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Enter email";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          /// PASSWORD FIELD
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),

                            decoration: InputDecoration(
                              hintText: "Password",
                              hintStyle:
                                  const TextStyle(color: Colors.white54),

                              filled: true,
                              fillColor: const Color(0xFF1F2937),

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),

                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Colors.white70,
                              ),

                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white70,
                                ),

                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),

                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Enter password";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 25),

                          /// LOGIN BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 50,

                            child: ElevatedButton(

                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4A857),

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),

                              onPressed: _isLoading ? null : _login,

                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          /// TEST CREDENTIALS
                          const Center(
                            child: Column(
                              children: [

                                Text(
                                  "TEST CREDENTIALS",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    letterSpacing: 2,
                                  ),
                                ),

                                SizedBox(height: 6),

                                Text(
                                  "officer@test.com",
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),

                                Text(
                                  "password123",
                                  style: TextStyle(
                                    color: Colors.white,
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

              ],
            ),
          ),
        ),
      ),
    );
  }
}