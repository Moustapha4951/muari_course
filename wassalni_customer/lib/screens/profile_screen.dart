import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../utils/shared_preferences_helper.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _customerData;
  bool _isLoading = true;
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = await SharedPreferencesHelper.getUserId();
      if (userId == null) {
        throw Exception('لم يتم العثور على معرف المستخدم');
      }

      _customerId = userId;

      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .get();

      if (doc.exists) {
        setState(() {
          _customerData = doc.data();
          _isLoading = false;
        });
      } else {
        throw Exception('لم يتم العثور على بيانات المستخدم');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الملف الشخصي: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _customerData?['name']);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تعديل الاسم',
          style: AppTextStyles.arabicTitle,
          textAlign: TextAlign.right,
        ),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.rtl,
          style: AppTextStyles.arabicBody,
          decoration: InputDecoration(
            labelText: 'الاسم الجديد',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: AppTextStyles.arabicBody),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('حفظ', style: AppTextStyles.arabicBody.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _customerData?['name']) {
      try {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(_customerId)
            .update({'name': newName});

        await SharedPreferencesHelper.saveUserData(
          userId: _customerId!,
          name: newName,
          phone: _customerData!['phone'],
          city: _customerData!['city'],
        );

        setState(() {
          _customerData?['name'] = newName;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الاسم بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في تحديث الاسم: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تسجيل الخروج',
          style: AppTextStyles.arabicTitle,
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من تسجيل الخروج؟',
          style: AppTextStyles.arabicBody,
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: AppTextStyles.arabicBody),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('تسجيل الخروج', style: AppTextStyles.arabicBody.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SharedPreferencesHelper.clearUserData();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'الملف الشخصي',
          style: AppTextStyles.arabicTitle,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 50,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _customerData?['name'] ?? 'غير محدد',
                          style: AppTextStyles.arabicTitle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _customerData?['phone'] ?? '',
                          style: AppTextStyles.arabicBody.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.local_taxi_rounded,
                            label: 'الرحلات',
                            value: '${_customerData?['completedRides'] ?? 0}',
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 50,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.star_rounded,
                            label: 'التقييم',
                            value: (_customerData?['rating'] ?? 0.0).toStringAsFixed(1),
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options
                  _buildOptionCard(
                    icon: Icons.edit_rounded,
                    title: 'تعديل الاسم',
                    subtitle: 'قم بتغيير اسمك',
                    color: AppColors.info,
                    onTap: _editName,
                  ),
                  const SizedBox(height: 12),
                  _buildOptionCard(
                    icon: Icons.phone_rounded,
                    title: 'رقم الهاتف',
                    subtitle: _customerData?['phone'] ?? '',
                    color: AppColors.success,
                    onTap: null, // Phone can't be changed
                  ),
                  const SizedBox(height: 12),
                  _buildOptionCard(
                    icon: Icons.info_rounded,
                    title: 'حول التطبيق',
                    subtitle: 'RimApp v1.0.0',
                    color: AppColors.secondary,
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'RimApp',
                        applicationVersion: '1.0.0',
                        applicationIcon: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.local_taxi_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Logout Button
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      'تسجيل الخروج',
                      style: AppTextStyles.arabicBody.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.arabicTitle.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.arabicBodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.arabicBody.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.arabicBodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColors.textHint,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
