import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rimapp_driver/utils/app_theme.dart';
import 'package:rimapp_driver/utils/custom_widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _selectedCity;
  List<Map<String, String>> _cities = [];
  bool _loadingCities = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cities')
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _cities = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc.data()['name'] as String? ?? doc.id,
          };
        }).toList();
        _loadingCities = false;
      });
    } catch (e) {
      debugPrint('Error loading cities: $e');
      setState(() {
        _loadingCities = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // تحقق من عدم وجود حساب بنفس رقم الهاتف
      final existingDrivers = await FirebaseFirestore.instance
          .collection('drivers')
          .where('phone', isEqualTo: _phoneController.text)
          .get();

      if (existingDrivers.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'رقم الهاتف مسجل مسبقاً',
                style: AppTextStyles.arabicBody.copyWith(color: Colors.white),
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // إنشاء الحساب الجديد
      await FirebaseFirestore.instance.collection('drivers').add({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'password': _passwordController.text,
        'city': _selectedCity,
        'isApproved': false,
        'isBanned': false,
        'status': 'offline',
        'balance': 0,
        'rating': 0.0,
        'completedRides': 0,
        'location': const GeoPoint(0, 0),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            title: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.check_circle, color: AppColors.accent),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'تم التسجيل بنجاح',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.arabicTitle,
                  ),
                ),
              ],
            ),
            content: Text(
              'تم إرسال طلب الإنضمام بنجاح. سيتم مراجعة طلبك من قبل الإدارة وسيتم إبلاغك عند ��لموافقة.',
              textAlign: TextAlign.right,
              style: AppTextStyles.arabicBody,
            ),
            actionsPadding: const EdgeInsets.all(AppSpacing.md),
            actions: [
              MCPrimaryButton(
                text: 'حسناً',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                height: 48,
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ ما، الرجاء المحاولة مرة أخرى',
              style: AppTextStyles.arabicBody.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      }
    }
    setState(() => _isLoading = false);
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
                    const SizedBox(height: 24),

                    // Modern Header Section
                    Column(
                      children: [
                        // Modern Icon Badge
                        Container(
                          padding: const EdgeInsets.all(20),
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
                                blurRadius: 25,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_add_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Modern Title
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.9),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'إنشاء حساب جديد',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.arabicDisplaySmall.copyWith(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
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
                        
                        // Modern Subtitle
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.2),
                                Colors.white.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'انضم إلى Muari Course وابدأ رحلتك معنا',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.arabicBody.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Modern Registration Card
                    Container(
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
                      padding: const EdgeInsets.all(28),
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Name
                            MCTextField(
                              controller: _nameController,
                              label: 'الاسم الكامل',
                              hint: 'أدخل اسمك الكامل',
                              prefixIcon: Icons.person,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء إدخال الاسم';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Phone
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
                            const SizedBox(height: AppSpacing.md),

                            // City Dropdown
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 4,
                              ),
                              child: _loadingCities
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_city, color: AppColors.textSecondary),
                                          const SizedBox(width: 12),
                                          Text(
                                            'جاري تحميل المدن...',
                                            style: AppTextStyles.arabicBody.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const Spacer(),
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ],
                                      ),
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: _selectedCity,
                                      decoration: const InputDecoration(
                                        labelText: 'المدينة',
                                        border: InputBorder.none,
                                        prefixIcon: Icon(Icons.location_city),
                                      ),
                                      hint: Text(
                                        _cities.isEmpty ? 'لا توجد مدن متاحة' : 'اختر المدينة',
                                        style: AppTextStyles.arabicBody.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      items: _cities.map((city) {
                                        return DropdownMenuItem<String>(
                                          value: city['id'],
                                          child: Text(
                                            city['name']!,
                                            style: AppTextStyles.arabicBody,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _cities.isEmpty ? null : (value) {
                                        setState(() {
                                          _selectedCity = value;
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'الرجاء اختيار المدينة';
                                        }
                                        return null;
                                      },
                                    ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Password
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
                                if (value.length < 6) {
                                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // Register Button
                            MCPrimaryButton(
                              text: 'تسجيل',
                              onPressed: _register,
                              isLoading: _isLoading,
                              icon: Icons.person_add,
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // Back to Login
                            MCOutlineButton(
                              text: 'لديك حساب بالفعل؟ تسجيل الدخول',
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: Icons.login,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Terms
                    Column(
                      children: [
                        Text(
                          'بإنشاء حساب، أنت توافق على',
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

                    const SizedBox(height: AppSpacing.lg),
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
