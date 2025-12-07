import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rimapp_driver/utils/sharedpreferences_helper.dart';
import 'package:rimapp_driver/utils/app_theme.dart';
import 'package:rimapp_driver/utils/custom_widgets.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final QuerySnapshot driverQuery = await FirebaseFirestore.instance
          .collection('drivers')
          .where('phone', isEqualTo: _phoneController.text)
          .where('password', isEqualTo: _passwordController.text)
          .get();

      setState(() => _isLoading = false);

      if (driverQuery.docs.isNotEmpty) {
        final driverData = driverQuery.docs.first.data() as Map<String, dynamic>;
        
        if (driverData['isApproved'] == true) {
          await SharedPreferencesHelper.saveDriverData(
            phone: _phoneController.text,
            password: _passwordController.text,
            driverId: driverQuery.docs.first.id,
            name: driverData['name'],
            city: driverData['city'],
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'مرحباً ${driverData['name']}!',
                      style: AppTextStyles.arabicBody.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          }
        } else {
          _showApprovalDialog();
        }
      } else {
        _showErrorSnackBar('رقم الهاتف أو كلمة المرور غير صحيحة');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('حدث خطأ ما، الرجاء المحاولة مرة أخرى');
    }
  }

  void _showApprovalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.pending,
                color: AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'طلب الإنضمام قيد المراجعة',
                textAlign: TextAlign.right,
                style: AppTextStyles.arabicTitle,
              ),
            ),
          ],
        ),
        content: Text(
          'لم تتم الموافقة على طلب الإنضمام بعد. الرجاء الانتظار حتى تتم مراجعة طلبك من قبل الإدارة.',
          textAlign: TextAlign.right,
          style: AppTextStyles.arabicBody,
        ),
        actions: [
          MCPrimaryButton(
            text: 'حسناً',
            onPressed: () => Navigator.pop(context),
            height: 45,
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.arabicBody.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Modern Logo and Title Section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Modern Logo with Glow
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 8,
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Image.asset(
                                'assets/icon/icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // Modern App Name with Gradient
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.9),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              "Muari Course",
                              textAlign: TextAlign.center,
                              style: AppTextStyles.arabicDisplayMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 40,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    offset: const Offset(0, 3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Modern Subtitle Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.25),
                                  Colors.white.withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_taxi_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "تطبيق السائق",
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.arabicBody.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Modern Login Form Card
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.15),
                                blurRadius: 30,
                                spreadRadius: 0,
                                offset: const Offset(0, 15),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 40,
                                spreadRadius: 0,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Modern Welcome Section
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'مرحباً بك',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.arabicHeadline.copyWith(
                                        color: AppColors.primary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'سجل دخولك للمتابعة',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.arabicBody.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Phone Field
                              MCTextField(
                                controller: _phoneController,
                                label: 'رقم الهاتف',
                                hint: 'أدخل رقم هاتفك',
                                prefixIcon: Icons.phone_android,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'الرجاء إدخال رقم الهاتف';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              
                              // Password Field
                              MCTextField(
                                controller: _passwordController,
                                label: 'كلمة المرور',
                                hint: 'أدخل كلمة المرور',
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                onSuffixIconTap: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                obscureText: _obscurePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'الرجاء إدخال كلمة المرور';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),
                              
                              // Login Button
                              MCPrimaryButton(
                                text: 'تسجيل الدخول',
                                onPressed: _login,
                                isLoading: _isLoading,
                                icon: Icons.login,
                              ),
                              const SizedBox(height: 20),
                              
                              // Divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.divider,
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'أو',
                                      style: AppTextStyles.arabicBodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.divider,
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // Register Button
                              MCOutlineButton(
                                text: 'إنشاء حساب جديد',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                icon: Icons.person_add,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Footer
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'بتسجيل الدخول، أنت توافق على',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.arabicBodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الشروط والأحكام وسياسة الخصوصية',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.arabicBodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
