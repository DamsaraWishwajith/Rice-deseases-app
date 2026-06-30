import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_colors.dart';
import '../widgets/input_field.dart';
import '../widgets/button_widget.dart';
import '../models/supervisor.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showCreate = false;
  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String _selectedDistrict = '';
  String _error = '';

  @override
  Widget build(BuildContext context) {
    if (_showCreate) {
      return _buildCreateAccount();
    }
    return _buildLogin();
  }

  Widget _buildLogin() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.forest, AppColors.green, AppColors.greenL],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              top: 70,
              right: 28,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.22),
                                      width: 1.5),
                                ),
                                child: const Center(
                                  child: Text('🌾',
                                      style: TextStyle(fontSize: 32)),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Rice Guard',
                                style: TextStyle(
                                  fontFamily: 'DM Serif Display',
                                  fontSize: 38,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Disease Detection System · Sri Lanka',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.forest.withOpacity(0.15),
                                  blurRadius: 40,
                                  offset: const Offset(0, -10)),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Supervisor Login',
                                  style: TextStyle(
                                    fontFamily: 'DM Serif Display',
                                    fontSize: 22,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              InputField(
                                label: 'Email',
                                icon: '✉️',
                                value: _emailController.text,
                                onChanged: (v) => _emailController.text = v,
                                placeholder: 'Enter your email',
                              ),
                              InputField(
                                label: 'Password',
                                icon: '🔑',
                                type: 'password',
                                value: _passwordController.text,
                                onChanged: (v) => _passwordController.text = v,
                                placeholder: '••••••••',
                              ),
                              if (_error.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerPale,
                                    border: Border.all(
                                        color:
                                            AppColors.danger.withOpacity(0.27)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('⚠️ ',
                                          style: TextStyle(fontSize: 13)),
                                      Expanded(
                                        child: Text(
                                          _error,
                                          style: const TextStyle(
                                              color: AppColors.danger,
                                              fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              ButtonWidget(
                                text:
                                    _isLoading ? 'Please wait...' : 'Sign In →',
                                onPressed: _isLoading ? () {} : _handleLogin,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account?",
                                    style: TextStyle(
                                        color: AppColors.sub, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _showCreate = true),
                                    child: const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        color: AppColors.green,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAccount() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.forest, AppColors.green, AppColors.greenL],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.22),
                                      width: 1.5),
                                ),
                                child: const Center(
                                  child: Text('🌾',
                                      style: TextStyle(fontSize: 32)),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Rice Guard',
                                style: TextStyle(
                                  fontFamily: 'DM Serif Display',
                                  fontSize: 38,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Disease Detection System · Sri Lanka',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 28),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.forest.withOpacity(0.15),
                                  blurRadius: 40,
                                  offset: const Offset(0, -10)),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontFamily: 'DM Serif Display',
                                    fontSize: 22,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              InputField(
                                label: 'Username',
                                icon: '👤',
                                value: _usernameController.text,
                                onChanged: (v) => _usernameController.text = v,
                                placeholder: 'e.g. john_supervisor',
                              ),
                              InputField(
                                label: 'Email',
                                icon: '✉️',
                                type: 'email',
                                value: _emailController.text,
                                onChanged: (v) => _emailController.text = v,
                                placeholder: 'you@doa.gov.lk',
                              ),
                              InputField(
                                label: 'Password',
                                icon: '🔑',
                                type: 'password',
                                value: _passwordController.text,
                                onChanged: (v) => _passwordController.text = v,
                                placeholder: 'Min. 6 characters',
                              ),
                              InputField(
                                label: 'Confirm Password',
                                icon: '🔒',
                                type: 'password',
                                value: _confirmController.text,
                                onChanged: (v) => _confirmController.text = v,
                                placeholder: 'Re-enter password',
                              ),
                              InputField(
                                label: 'District',
                                icon: '📍',
                                value: _selectedDistrict,
                                onChanged: (v) => _selectedDistrict = v,
                                options: const [
                                  'Anuradhapura',
                                  'Polonnaruwa',
                                  'Kurunegala',
                                  'Kandy',
                                  'Galle',
                                  'Hambantota',
                                  'Matale',
                                  'Jaffna',
                                  'Batticaloa'
                                ],
                              ),
                              if (_error.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerPale,
                                    border: Border.all(
                                        color:
                                            AppColors.danger.withOpacity(0.27)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('⚠️ ',
                                          style: TextStyle(fontSize: 13)),
                                      Expanded(
                                        child: Text(
                                          _error,
                                          style: const TextStyle(
                                              color: AppColors.danger,
                                              fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ButtonWidget(
                                text: _isLoading
                                    ? 'Creating Account...'
                                    : 'Create Account →',
                                onPressed: _isLoading ? () {} : _handleCreate,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account?',
                                    style: TextStyle(
                                        color: AppColors.sub, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _showCreate = false),
                                    child: const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: AppColors.green,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://rice-diseases-store.us.stackstaging.com/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Assuming the API returns a structure that can be mapped to Supervisor
        final supervisor = Supervisor.fromJson(data['user'] ?? data);

        // Store supervisor details for auto-login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('supervisor', jsonEncode(supervisor.toJson()));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => HomeScreen(supervisor: supervisor)),
          );
        }
      } else {
        setState(() => _error =
            data['message'] ?? 'Login failed. Please check your credentials.');
      }
    } catch (e) {
      setState(() => _error =
          'Connection error. Please check your internet or server IP.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCreate() async {
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmController.text.isEmpty ||
        _selectedDistrict.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://rice-diseases-store.us.stackstaging.com/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'district': _selectedDistrict,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final supervisor = Supervisor.fromJson(data['user'] ?? data);

        // Store supervisor details for auto-login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('supervisor', jsonEncode(supervisor.toJson()));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully!'),
              backgroundColor: AppColors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => HomeScreen(supervisor: supervisor)),
          );
        }
      } else {
        setState(() => _error = data['message'] ?? 'Registration failed.');
      }
    } catch (e) {
      setState(() => _error =
          'Connection error. Please check your internet or server IP.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
