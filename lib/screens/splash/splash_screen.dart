import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoFadeAnimation;

  late final AnimationController _textController;
  late final Animation<double> _textFadeAnimation;
  late final Animation<Offset> _textSlideAnimation;

  Timer? _navTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // 1. Logo entrance animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScaleAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
    _logoFadeAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    // 2. Text entrance animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textFadeAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    );
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));

    // Start sequence
    _startAnimationAndNavigate();
  }

  void _startAnimationAndNavigate() {
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _textController.forward();
    });

    try {
      StorageService().getAppDirectory();
    } catch (_) {}

    _navTimer = Timer(const Duration(milliseconds: 2100), () {
      if (mounted) _navigateToHome();
    });
  }

  void _navigateToHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _navTimer?.cancel();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Solid dark slate
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToHome, // Tap to immediately skip
        child: SafeArea(
          child: Stack(
            children: [
              // Center Content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flat Logo
                    FadeTransition(
                      opacity: _logoFadeAnimation,
                      child: ScaleTransition(
                        scale: _logoScaleAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppColors.primary,
                                child: const Center(
                                  child: Icon(Icons.transform, size: 54, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // App Name & Subtitle
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: FadeTransition(
                        opacity: _textFadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              'File Transformer',
                              style: GoogleFonts.outfit(
                                fontSize: 29,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'স্মার্ট ডকুমেন্ট এডিটর ও ফাইল কনভার্টার',
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8), // Slate 400
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Flat Clean Indicator
                            SizedBox(
                              width: 120,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: const LinearProgressIndicator(
                                  minHeight: 3.5,
                                  backgroundColor: Color(0xFF1E293B),
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)), // Sky blue solid
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Footer
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _textFadeAnimation,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B), // Solid slate container
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 14,
                            color: Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '১০০% অফলাইন ও নিরাপদ • v2.0',
                            style: GoogleFonts.hindSiliguri(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
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
