import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';

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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          decoration: AppDecorations.cardDecoration,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "تم إرسال طلبك بنجاح!",
                style: AppTextStyles.arabicHeadline.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "سيتم مراجعة طلبك من قبل المدير العام وسيتم إخبارك عند الموافقة.",
                style: AppTextStyles.arabicBody.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final QuerySnapshot existingAdmin = await FirebaseFirestore.instance
            .collection('admins')
            .where('phone', isEqualTo: _phoneController.text)
            .get();

        if (existingAdmin.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('رقم الهاتف مسجل مسبقاً')),
          );
          setState(() => _isLoading = false);
          return;
        }

        await FirebaseFirestore.instance.collection('admins').add({
          'name': _nameController.text,
          'phone': _phoneController.text,
          'password': _passwordController.text,
          'isApproved': false,
          'role': 'supervisor',
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _isLoading = false);

        if (mounted) {
          _showSuccessDialog();
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "إنشاء حساب مشرف جديد",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.arabicDisplayMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "يرجى إدخال المعلومات المطلوبة",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.arabicBody.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    decoration: AppDecorations.cardDecoration,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: AppTextStyles.arabicBody,
                          decoration: InputDecoration(
                            labelText: 'الاسم الكامل',
                            hintText: 'أدخل اسمك الكامل',
                            prefixIcon: const Icon(Icons.person_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال الاسم';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
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
                            if (value.length < 6) {
                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('إنشاء حساب'),
                        ),
                      ],
                    ),
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
