import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_colors.dart';
import '../models/supervisor.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;
  late AnimationController _progressController;

  // Animations
  late Animation<double> _bgScale;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoRotate;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleOpacity;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _shimmer;
  late Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Background gentle zoom
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _bgScale = Tween<double>(begin: 1.05, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeOut),
    );

    // Logo entrance
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _logoRotate = Tween<double>(begin: -0.08, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Text entrance
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    // Shimmer on logo
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmer = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Floating particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Progress bar
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  void _startSequence() async {
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();
    _progressController.forward();

    await Future.delayed(const Duration(milliseconds: 3200));
    _navigate();
  }

  void _navigate() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final supervisorJson = prefs.getString('supervisor');

    Supervisor? supervisor;
    if (supervisorJson != null) {
      try {
        supervisor = Supervisor.fromJson(jsonDecode(supervisorJson));
      } catch (_) {
        await prefs.remove('supervisor');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => supervisor != null
            ? HomeScreen(supervisor: supervisor!)
            : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgController,
          _logoController,
          _textController,
          _shimmerController,
          _particleController,
          _progressController,
        ]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Gradient Background ──────────────────────────────────
              _buildBackground(),

              // ── Floating Particles ───────────────────────────────────
              _buildParticles(size),

              // ── Main Content ─────────────────────────────────────────
              _buildContent(size),

              // ── Bottom Progress Bar ──────────────────────────────────
              _buildProgressBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Transform.scale(
      scale: _bgScale.value,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D2116), // very dark forest
              Color(0xFF1D3B26), // forest
              Color(0xFF254D32), // forest mid
              Color(0xFF1A3521), // deep green
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Subtle radial glow top-centre
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF387D51).withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom glow
            Positioned(
              bottom: -60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFE89D1C).withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticles(Size size) {
    const particles = [
      _Particle(x: 0.12, y: 0.18, size: 4, speed: 1.0, delay: 0.0),
      _Particle(x: 0.82, y: 0.22, size: 3, speed: 0.8, delay: 0.3),
      _Particle(x: 0.25, y: 0.72, size: 5, speed: 1.2, delay: 0.6),
      _Particle(x: 0.75, y: 0.68, size: 3, speed: 0.9, delay: 0.1),
      _Particle(x: 0.55, y: 0.10, size: 4, speed: 1.1, delay: 0.4),
      _Particle(x: 0.08, y: 0.50, size: 3, speed: 0.7, delay: 0.7),
      _Particle(x: 0.90, y: 0.48, size: 4, speed: 1.3, delay: 0.2),
      _Particle(x: 0.38, y: 0.88, size: 3, speed: 1.0, delay: 0.5),
    ];

    final t = _particleController.value;

    return Stack(
      children: particles.map((p) {
        final phase = (t * p.speed + p.delay) % 1.0;
        final floatY = math.sin(phase * 2 * math.pi) * 12;
        final opacity = 0.15 + 0.2 * math.sin(phase * 2 * math.pi + math.pi / 2);

        return Positioned(
          left: p.x * size.width,
          top: p.y * size.height + floatY,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: p.size.toDouble(),
              height: p.size.toDouble(),
              decoration: const BoxDecoration(
                color: Color(0xFF5AB375),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContent(Size size) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // ── Logo Card ─────────────────────────────────────────────
          Transform.rotate(
            angle: _logoRotate.value,
            child: Opacity(
              opacity: _logoOpacity.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF5AB375).withOpacity(0.20),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Inner ring
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF5AB375).withOpacity(0.25),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Main logo container
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: const Color(0xFF5AB375).withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/rice.jpeg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Shimmer overlay on logo
                    ClipOval(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Transform.translate(
                          offset: Offset(_shimmer.value * 80, -40),
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Container(
                              width: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.12),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 36),

          // ── App Title ─────────────────────────────────────────────
          SlideTransition(
            position: _titleSlide,
            child: FadeTransition(
              opacity: _titleOpacity,
              child: Text(
                'Rice Guard',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  height: 1.1,
                  shadows: const [
                    Shadow(
                      color: Color(0x55000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Subtitle ──────────────────────────────────────────────
          SlideTransition(
            position: _subtitleSlide,
            child: FadeTransition(
              opacity: _subtitleOpacity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 1,
                    color: const Color(0xFF5AB375).withOpacity(0.5),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'AI-Powered Disease Detection',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 14,
                      color: Color(0xFF7DB58A),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 28,
                    height: 1,
                    color: const Color(0xFF5AB375).withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(flex: 3),

          // ── Loading dots ──────────────────────────────────────────
          FadeTransition(
            opacity: _subtitleOpacity,
            child: _LoadingDots(controller: _particleController),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _subtitleOpacity,
        child: Container(
          height: 3,
          alignment: Alignment.centerLeft,
          color: Colors.white.withOpacity(0.06),
          child: FractionallySizedBox(
            widthFactor: _progressValue.value,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF387D51), Color(0xFF5AB375), Color(0xFFE89D1C)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Particle data class ─────────────────────────────────────────────────────
class _Particle {
  final double x, y, speed, delay;
  final int size;
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.delay,
  });
}

// ── Pulsing loading dots ────────────────────────────────────────────────────
class _LoadingDots extends StatelessWidget {
  final AnimationController controller;
  const _LoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (controller.value + i * 0.33) % 1.0;
            final scale = 0.5 + 0.5 * math.sin(phase * 2 * math.pi).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6 * scale,
              height: 6 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFF5AB375).withOpacity(0.4 + 0.6 * scale),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
