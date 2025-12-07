import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sharedpreferences_helper.dart';
import '../utils/app_theme.dart';
import 'register_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final QuerySnapshot adminQuery = await FirebaseFirestore.instance
            .collection('admins')
            .where('phone', isEqualTo: _phoneController.text)
            .where('password', isEqualTo: _passwordController.text)
            .get();

        setState(() => _isLoading = false);

        if (adminQuery.docs.isNotEmpty) {
          await SharedPreferencesHelper.saveAdminData(
            phone: _phoneController.text,
            password: _passwordController.text,
            adminId: adminQuery.docs.first.id,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تسجيل الدخول بنجاح')),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MainScreen(),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('رقم الهاتف أو كلمة المرور غير صحيحة')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ ما، الرجاء المحاولة مرة أخرى')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                textDirection: TextDirection.rtl,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    decoration: AppDecorations.glassDecoration,
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      height: 120,
                      width: 120,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Mauri Admin",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.arabicDisplayMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "لوحة تحكم الإدارة",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.arabicBody.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    decoration: AppDecorations.cardDecoration,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: AppTextStyles.arabicBody,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف',
                            hintText: 'أدخل رقم هاتفك',
                            prefixIcon: const Icon(Icons.phone_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال رقم الهاتف';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: AppTextStyles.arabicBody,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            hintText: 'أدخل كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال كلمة المرور';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('تسجيل الدخول'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        'ليس لديك حساب؟',
                        style: AppTextStyles.arabicBodySmall,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'إنشاء حساب',
                          style: AppTextStyles.arabicBody.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
