import 'dart:async';
import 'package:flutter/material.dart';

class BuyerSplashScreen extends StatefulWidget {
  const BuyerSplashScreen({super.key});

  @override
  State<BuyerSplashScreen> createState() => _BuyerSplashScreenState();
}

class _BuyerSplashScreenState extends State<BuyerSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();

    // Auto navigate to home after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE), // Soft ivory/cream luxury background
      body: Stack(
        children: [
          // Top-Left Corner Geometric Watermark Pattern
          Positioned(
            top: -40,
            left: -40,
            width: 280,
            height: 280,
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(
                painter: StarWatermarkPainter(),
              ),
            ),
          ),

          // Bottom-Right Corner Geometric Watermark Pattern
          Positioned(
            bottom: -40,
            right: -40,
            width: 280,
            height: 280,
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(
                painter: StarWatermarkPainter(),
              ),
            ),
          ),

          // Center Logo & Welcome Text Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo Row (Shopping Bag Icon + aadry text)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gradient Shopping Bag Icon with Checkmark Badge
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF4511E), // Deep Coral Orange
                                Color(0xFFFF8A65), // Soft Peach Coral
                              ],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF4511E).withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Shopping Bag Handles & Body
                              const Icon(
                                Icons.shopping_bag_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              // Checkmark badge in center
                              Positioned(
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFB74D), // Soft Amber Yellow check highlight
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Brand Title "aadry"
                        const Text(
                          'aadry',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE54D42), // Signature Aadry Tomato/Coral Red
                            letterSpacing: -1.0,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Subtitle "Welcome the app."
                    const Text(
                      'Welcome the app.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280), // Neutral Muted Slate Grey
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Tap to Skip indicator (Invisible InkWell to immediately enter home)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pushReplacementNamed('/onboarding');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter for the Islamic Octagram / Star geometric watermark pattern
class StarWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8D7B68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final double width = size.width;
    final double height = size.height;

    // Draw repeating octagram star grid pattern
    const double step = 70.0;
    for (double x = 0; x < width; x += step) {
      for (double y = 0; y < height; y += step) {
        _drawOctagram(canvas, Offset(x + step / 2, y + step / 2), 26.0, paint);
      }
    }
  }

  void _drawOctagram(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    // Square 1 (Rotated 0 deg)
    path.addRect(Rect.fromCenter(center: center, width: radius * 1.4, height: radius * 1.4));
    
    // Square 2 (Rotated 45 deg)
    final path2 = Path();
    path2.addRect(Rect.fromCenter(center: center, width: radius * 1.4, height: radius * 1.4));
    final Matrix4 matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..rotateZ(0.785398) // 45 degrees in radians
      ..translate(-center.dx, -center.dy);
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path2.transform(matrix.storage), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
