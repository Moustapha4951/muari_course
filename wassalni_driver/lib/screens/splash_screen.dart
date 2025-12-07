import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rimapp_driver/utils/sharedpreferences_helper.dart';
import 'package:rimapp_driver/utils/app_theme.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'ride_screen_new_version.dart';
import 'open_ride_screen_v2.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeIn),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1500), () {
      _checkPendingRides();
    });
  }

  Future<void> _checkPendingRides() async {
    try {
      final pendingRideId = await SharedPreferencesHelper.getPendingRideId();
      
      if (pendingRideId != null && pendingRideId.isNotEmpty) {
        debugPrint('SplashScreen: تم العثور على رحلة معلقة - $pendingRideId');
        
        try {
          final rideDoc = await FirebaseFirestore.instance
              .collection('rides')
              .doc(pendingRideId)
              .get();
          
          if (rideDoc.exists) {
            final rideStatus = rideDoc.data()?['status'] as String?;
            
            if (rideStatus == 'pending') {
              debugPrint('الرحلة لا تزال معلقة، سيتم فتح شاشة التفاصيل');
              
              final isOpenRide = rideDoc.data()?['isOpenRide'] == true || rideDoc.data()?['rideType'] == 'open';
              debugPrint('نوع الرحلة: ${isOpenRide ? "مفتوحة" : "عادية"}');
              
              await Future.delayed(const Duration(milliseconds: 500));
              
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => isOpenRide
                        ? OpenRideScreenV2(
                            rideData: rideDoc.data() ?? {},
                            rideId: pendingRideId,
                          )
                        : RideScreenNewVersion(
                            rideData: rideDoc.data() ?? {},
                            rideId: pendingRideId,
                          ),
                  ),
                );
                return;
              }
            } else {
              debugPrint('الرحلة ل��ست في حالة معلقة، حالتها: $rideStatus');
              await SharedPreferencesHelper.clearPendingRideId();
            }
          } else {
            debugPrint('الرحلة غير موجودة في قاعدة البيانات');
            await SharedPreferencesHelper.clearPendingRideId();
          }
        } catch (e) {
          debugPrint('خطأ أثناء التحقق من الرحلة المعلقة: $e');
        }
      } else {
        debugPrint('لا توجد رحلات معلقة محفوظة');
      }
    } catch (e) {
      debugPrint('خطأ عام في _checkPendingRides: $e');
    }
    
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final driverData = await SharedPreferencesHelper.getDriverData();
    
    if (driverData['phone'] != null && driverData['password'] != null) {
      try {
        final QuerySnapshot driverQuery = await FirebaseFirestore.instance
            .collection('drivers')
            .where('phone', isEqualTo: driverData['phone'])
            .where('password', isEqualTo: driverData['password'])
            .get();

        if (driverQuery.docs.isNotEmpty) {
          final userData = driverQuery.docs.first.data() as Map<String, dynamic>;
          if (userData['isApproved'] == true) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
              );
              return;
            }
          }
        }
        await SharedPreferencesHelper.clearDriverData();
      } catch (e) {
        await SharedPreferencesHelper.clearDriverData();
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        child: Stack(
          children: [
            // Animated Background Circles
            Positioned(
              top: -100,
              right: -100,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
            ),
            
            // Main Content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    
                    // Modern Animated Logo with Glow Effect
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(30),
                          child: RotationTransition(
                            turns: _rotateAnimation,
                            child: Image.asset(
                              'assets/icon/icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Modern App Name with Gradient Text Effect
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withOpacity(0.9),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'Muari Course',
                                style: AppTextStyles.arabicDisplayLarge.copyWith(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.2),
                                      offset: const Offset(0, 4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Modern Badge Design
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.25),
                                    Colors.white.withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_taxi_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'تطبيق السائق',
                                    style: AppTextStyles.arabicTitle.copyWith(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Modern Tagline with Icon
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.route_rounded,
                                color: Colors.white.withOpacity(0.9),
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'رحلتك تبدأ معنا',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.arabicBody.copyWith(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'خدمة نقل موثوقة وآمنة',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.arabicBodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 2),
                    
                    // Modern Loading Indicator
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.2),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'جاري التحميل...',
                            style: AppTextStyles.arabicBody.copyWith(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Modern Version Badge
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'الإصدار 2.0.0',
                          style: AppTextStyles.arabicBodySmall.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
