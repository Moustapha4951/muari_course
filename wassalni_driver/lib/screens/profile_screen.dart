import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sharedpreferences_helper.dart';
import '../utils/app_theme.dart';
import '../utils/custom_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _driverId = '';

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    setState(() => _isLoading = true);
    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      if (driverData['driverId'] != null) {
        _driverId = driverData['driverId']!;
        final driverDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(_driverId)
            .get();

        if (driverDoc.exists) {
          setState(() {
            _nameController.text = driverDoc.data()?['name'] ?? '';
            _phoneController.text = driverDoc.data()?['phone'] ?? '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في تحميل البيانات')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final driverRef =
          FirebaseFirestore.instance.collection('drivers').doc(_driverId);
      final driverDoc = await driverRef.get();

      if (!driverDoc.exists) {
        throw Exception('لم يتم العثور على بيانات السائق');
      }

      // التحقق من كلمة المرور الحالية إذا تم إدخالها
      if (_currentPasswordController.text.isNotEmpty) {
        if (driverDoc.data()?['password'] != _currentPasswordController.text) {
          throw Exception('كلمة المرور الحالية غير صحيحة');
        }

        // التحقق من تطابق كلمة المرور الجديدة
        if (_newPasswordController.text != _confirmPasswordController.text) {
          throw Exception('كلمة المرور الجديدة غير متطابقة');
        }
      }

      // تحديث البيانات
      final updates = <String, dynamic>{
        'name': _nameController.text,
        'phone': _phoneController.text,
      };

      // إضافة كلمة المرور الجديدة إذا تم تغييرها
      if (_currentPasswordController.text.isNotEmpty) {
        updates['password'] = _newPasswordController.text;
      }

      await driverRef.update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث البيانات بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.15),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'الملف الشخصي',
                      style: AppTextStyles.arabicDisplaySmall.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content Area
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Modern Profile Avatar
                                Center(
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withOpacity(0.2),
                                          AppColors.accent.withOpacity(0.1),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          blurRadius: 25,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.white,
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 50,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Modern Personal Info Card
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              gradient: AppColors.primaryGradient,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.person_outline,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'المعلومات الشخصية',
                                              style: AppTextStyles.arabicTitle.copyWith(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      MCTextField(
                                        controller: _nameController,
                                        label: 'الاسم',
                                        hint: 'أدخل اسمك',
                                        prefixIcon: Icons.person,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'الرجاء إدخال الاسم';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: AppSpacing.md),
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
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // Modern Password Change Card
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              gradient: AppColors.secondaryGradient,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.lock_outline,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'تغيير كلمة المرور',
                                              style: AppTextStyles.arabicTitle.copyWith(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      MCTextField(
                                        controller: _currentPasswordController,
                                        label: 'كلمة المرور الحالية',
                                        hint: 'أدخل كلمة المرور الحالية',
                                        prefixIcon: Icons.lock,
                                        obscureText: true,
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      MCTextField(
                                        controller: _newPasswordController,
                                        label: 'كلمة المرور الجديدة',
                                        hint: 'أدخل كلمة المرور الجديدة',
                                        prefixIcon: Icons.lock_open,
                                        obscureText: true,
                                        validator: (value) {
                                          if (_currentPasswordController.text.isNotEmpty) {
                                            if (value == null || value.isEmpty) {
                                              return 'الرجاء إدخال كلمة المرور الجديدة';
                                            }
                                            if (value.length < 6) {
                                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      MCTextField(
                                        controller: _confirmPasswordController,
                                        label: 'تأكيد كلمة المرور الجديدة',
                                        hint: 'أعد إدخال كلمة المرور الجديدة',
                                        prefixIcon: Icons.lock_reset,
                                        obscureText: true,
                                        validator: (value) {
                                          if (_currentPasswordController.text.isNotEmpty) {
                                            if (value == null || value.isEmpty) {
                                              return 'الرجاء تأكيد كلمة المرور الجديدة';
                                            }
                                            if (value != _newPasswordController.text) {
                                              return 'كلمة المرور غير متطابقة';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                // Save Button
                                MCPrimaryButton(
                                  text: 'حفظ التغييرات',
                                  onPressed: _updateProfile,
                                  isLoading: _isLoading,
                                  icon: Icons.save,
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
