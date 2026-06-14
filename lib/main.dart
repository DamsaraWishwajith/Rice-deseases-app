import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:rice_guard/screens/login_screen.dart';
import 'package:rice_guard/screens/home_screen.dart';
import 'package:rice_guard/theme/app_colors.dart';
import 'package:rice_guard/models/supervisor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final supervisorJson = prefs.getString('supervisor');
  
  Supervisor? initialSupervisor;
  if (supervisorJson != null) {
    try {
      initialSupervisor = Supervisor.fromJson(jsonDecode(supervisorJson));
    } catch (e) {
      // If parsing fails, clear the storage
      await prefs.remove('supervisor');
    }
  }

  runApp(RiceGuardApp(initialSupervisor: initialSupervisor));
}

class RiceGuardApp extends StatelessWidget {
  final Supervisor? initialSupervisor;

  const RiceGuardApp({super.key, this.initialSupervisor});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rice Guard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'DM Sans',
        scaffoldBackgroundColor: AppColors.bg,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.forest,
          primary: AppColors.forest,
          secondary: AppColors.accent,
        ),
      ),
      home: initialSupervisor != null 
          ? HomeScreen(supervisor: initialSupervisor!) 
          : const LoginScreen(),
    );
  }
}