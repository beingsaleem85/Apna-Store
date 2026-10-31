import 'package:flutter/material.dart';
import '../buyer_splash_screen.dart'; // For StarWatermarkPainter

class BuyerOnboardingCarouselScreen extends StatefulWidget {
  const BuyerOnboardingCarouselScreen({super.key});

  @override
  State<BuyerOnboardingCarouselScreen> createState() => _BuyerOnboardingCarouselScreenState();
}

class _BuyerOnboardingCarouselScreenState extends State<BuyerOnboardingCarouselScreen> {
  final PageController _pageController = PageController(initialPage: 0); // Start on Slide 1
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Nationwide Delivery',
      'desc': 'Delight entiovatiors and nationwite delivery inamdiors.',
      'type': 'slide1', // Exact uploaded mockup 3
    },
    {
      'title': 'Delightfus Deals',
      'desc': 'Design your orders wun tebas and acirtora-aevomia deals.',
      'type': 'slide2', // Exact uploaded mockup 2
    },
    {
      'title': 'Secure Shopping',
      'desc': 'Finns was approadable and secure shopping relectons.',
      'type': 'slide3', // Exact uploaded mockup 4 (Secure Shopping)
    },
    {
      'title': 'Express Doorstep Delivery',
      'desc': 'Track your order live from seller dispatch to your doorstep.',
      'type': 'slide4',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0), // Soft cream luxury background
      body: Stack(
        children: [
          // Full-screen Islamic Octagram Star Watermark Background Pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(
                painter: StarWatermarkPainter(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Skip Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/buyer/mobile-sign-in');
                        },
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main PageView Carousel
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Top Illustration Container
                            Container(
                              height: 320,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Center(
                                child: slide['type'] == 'slide1'
                                    ? _buildDeliveryTruckIllustrationSlide1()
                                    : slide['type'] == 'slide2'
                                        ? _buildMockupIllustrationSlide2()
                                        : slide['type'] == 'slide3'
                                            ? _buildSecureShoppingIllustrationSlide3()
                                            : _buildGenericIllustration(slide['type']!),
                              ),
                            ),
                            const SizedBox(height: 48),

                            // Title
                            Text(
                              slide['title']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Subtitle
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                slide['desc']!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Page Dots Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (idx) {
                    final isActive = idx == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 10 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFEF4444) : const Color(0xFFD1D5DB),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 36),

                // Bottom CTA Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _slides.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.of(context).pushReplacementNamed('/buyer/mobile-sign-in');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1 ? 'Get Started' : 'Continue',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Exact 100% Match Pixel-Perfect Illustration for Slide 1 (Nationwide Delivery)
  Widget _buildDeliveryTruckIllustrationSlide1() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Soft Peach Circle Halo
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFFFFECE0).withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),

        // Floating Clouds Outline at Top
        const Positioned(
          top: 30,
          left: 60,
          child: Icon(Icons.cloud_outlined, size: 28, color: Color(0xFF1E293B)),
        ),
        const Positioned(
          top: 20,
          right: 60,
          child: Icon(Icons.cloud_outlined, size: 34, color: Color(0xFF1E293B)),
        ),

        // Delivery Truck Main Container
        Positioned(
          bottom: 45,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Motion Speed Lines on Left
                  Column(
                    children: [
                      Container(width: 30, height: 2, color: const Color(0xFF1E293B)),
                      const SizedBox(height: 10),
                      Container(width: 45, height: 2, color: const Color(0xFF1E293B)),
                      const SizedBox(height: 10),
                      Container(width: 25, height: 2, color: const Color(0xFF1E293B)),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Red Cargo Box
                  Container(
                    width: 140,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444), // Coral Red Cargo Box
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(4),
                      ),
                      border: Border.all(color: const Color(0xFF1E293B), width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24), // Yellow Cardboard Box
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF1E293B), width: 1.8),
                        ),
                        child: Stack(
                          children: [
                            // Tape Line across Box
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                height: 8,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Yellow Cabin
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24), // Bright Yellow Cabin
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(24),
                        bottomRight: Radius.circular(8),
                      ),
                      border: Border.all(color: const Color(0xFF1E293B), width: 2),
                    ),
                    child: Stack(
                      children: [
                        // Cabin Window
                        Positioned(
                          top: 10,
                          left: 12,
                          child: Container(
                            width: 36,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(12),
                                topLeft: Radius.circular(4),
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                              border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                            ),
                          ),
                        ),
                        // Door Handle / Bumper accent
                        Positioned(
                          bottom: 18,
                          right: 8,
                          child: Container(
                            width: 14,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Blue Lower Chassis with Wheels
              Container(
                width: 220,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF312E81), // Deep Navy Chassis
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Rear Wheel
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1E293B), width: 4),
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Front Wheel
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1E293B), width: 4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 2),
              // Ground Line under truck
              Container(
                width: 240,
                height: 2,
                color: const Color(0xFF1E293B),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Exact 100% Match Pixel-Perfect Illustration for Slide 2 (Delightfus Deals)
  Widget _buildMockupIllustrationSlide2() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Soft Peach Circle Halo
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFFFFECE0).withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),

        // Central Phone Frame with Store Canopy Awning
        Container(
          width: 140,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1E293B), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top Phone Notch Line
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Red & Yellow Striped Store Awning (Canopy)
              Positioned(
                top: 20,
                left: -6,
                right: -6,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: List.generate(6, (i) {
                      final isRed = i % 2 == 0;
                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isRed ? const Color(0xFFEF4444) : const Color(0xFFFBBF24),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(i == 0 || i == 5 ? 6 : 4),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // SALE Text inside Phone Screen
              Positioned(
                top: 75,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    const Text(
                      'SALE',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFEF4444),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // SAVE Purple Pill Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4338CA), // Deep Indigo Purple
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: const Text(
                        'SAVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Left Side: Blue Potted Plant & Shopping Bags
        Positioned(
          left: 30,
          bottom: 25,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Blue Pot with Cactus/Plant
              Column(
                children: [
                  // Cactus Leaves
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Container(
                        width: 12,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  // Blue Pot
                  Container(
                    width: 26,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF312E81), // Dark Navy Blue Pot
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Yellow & Red Shopping Bags
              Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  // Yellow Bag behind
                  Container(
                    width: 32,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                    ),
                  ),
                  // Red Bag in front
                  Container(
                    width: 20,
                    height: 30,
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right Side: Woman Character Figure with Gift Bubble
        Positioned(
          right: 30,
          bottom: 20,
          child: Column(
            children: [
              // Gift Speech Bubble
              Container(
                margin: const EdgeInsets.only(bottom: 6, left: 16),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 16,
                ),
              ),

              // Character Figure (Head, Purple Shirt, Red Pants)
              Column(
                children: [
                  // Hair & Head
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Purple Shirt
                  Container(
                    width: 28,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4338CA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Red Pants
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 12,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Exact 100% Match Pixel-Perfect Illustration for Slide 3 (Secure Shopping)
  Widget _buildSecureShoppingIllustrationSlide3() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Soft Peach Circle Halo
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFFFFECE0).withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),

        // Verified Badge Top Right
        Positioned(
          top: 35,
          right: 65,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          ),
        ),

        // Central Shield & Lock
        Positioned(
          bottom: 45,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Red Shield Container
                  Container(
                    width: 140,
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444), // Coral Red Shield
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                        bottom: Radius.circular(70),
                      ),
                      border: Border.all(color: const Color(0xFF1E293B), width: 2),
                    ),
                  ),

                  // Golden Padlock
                  Container(
                    width: 64,
                    height: 60,
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24), // Golden Yellow Lock
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B), width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E293B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),

                  // Lock Shackle with Heart Badge on top
                  Positioned(
                    top: 25,
                    child: Column(
                      children: [
                        // Heart Icon Badge
                        const Icon(Icons.favorite, size: 18, color: Color(0xFFFBBF24)),
                        Container(
                          width: 36,
                          height: 30,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF1E293B), width: 3),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Baseline Ground Line
              Container(
                width: 250,
                height: 2,
                color: const Color(0xFF1E293B),
              ),
            ],
          ),
        ),

        // Left Side: Woman with Laptop sitting cross-legged
        Positioned(
          left: 25,
          bottom: 47,
          child: Column(
            children: [
              // Woman Head/Hair
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 2),
              // Yellow Shirt
              Container(
                width: 30,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 2),
              // Laptop
              Container(
                width: 38,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                ),
              ),
            ],
          ),
        ),

        // Right Side: Red Gift & Shopping Bags
        Positioned(
          right: 25,
          bottom: 47,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Red Gift Box
              Container(
                width: 32,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 30,
                    color: const Color(0xFFFBBF24),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Yellow Bag
              Container(
                width: 36,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                ),
              ),
              const SizedBox(width: 4),

              // Purple Bag
              Container(
                width: 22,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF4338CA),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper for other slides
  Widget _buildGenericIllustration(String type) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
          child: const Icon(
            Icons.local_shipping,
            size: 50,
            color: Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }
}
