import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';

class RideSettingsScreen extends StatefulWidget {
  const RideSettingsScreen({super.key});

  @override
  State<RideSettingsScreen> createState() => _RideSettingsScreenState();
}

class _RideSettingsScreenState extends State<RideSettingsScreen> {
  final TextEditingController _maxDistanceController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('rideSettings')
          .get();

      if (settingsDoc.exists) {
        final maxDistance = settingsDoc.data()?['maxRideDistanceKm'];
        if (maxDistance != null) {
          _maxDistanceController.text = maxDistance.toString();
        } else {
          _maxDistanceController.text = '1.0';
        }
      } else {
        // Create default settings
        await FirebaseFirestore.instance
            .collection('settings')
            .doc('rideSettings')
            .set({
          'maxRideDistanceKm': 1.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _maxDistanceController.text = '1.0';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الإعدادات: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    final maxDistance = double.tryParse(_maxDistanceController.text);
    
    if (maxDistance == null || maxDistance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مسافة صحيحة')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('rideSettings')
          .set({
        'maxRideDistanceKm': maxDistance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ الإعدادات: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'إعدادات الرحلات',
          style: AppTextStyles.arabicTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.settings_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'إعدادات نطاق الرحلات',
                                    style: AppTextStyles.arabicTitle.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'تحديد المسافة القصوى لعرض الرحلات للسائقين',
                                    style: AppTextStyles.arabicBodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Divider(color: AppColors.border),
                        const SizedBox(height: 24),
                        Text(
                          'المسافة القصوى (كيلومتر)',
                          style: AppTextStyles.arabicBody.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _maxDistanceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          style: AppTextStyles.arabicBody,
                          decoration: InputDecoration(
                            hintText: 'أدخل المسافة بالكيلومتر',
                            hintStyle: AppTextStyles.arabicBody.copyWith(
                              color: AppColors.textHint,
                            ),
                            prefixIcon: Icon(Icons.straighten_rounded, color: AppColors.primary),
                            suffixText: 'كم',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.info.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.info,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'سيتم عرض الرحلات للسائقين فقط إذا كانت المسافة بين موقع السائق ونقطة الانطلاق أقل من أو تساوي هذه القيمة. القيمة الافتراضية: 1 كم',
                                  style: AppTextStyles.arabicBodySmall.copyWith(
                                    color: AppColors.info,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveSettings,
                            icon: _isSaving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.textOnPrimary),
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _isSaving ? 'جاري الحفظ...' : 'حفظ الإعدادات',
                              style: AppTextStyles.arabicBody.copyWith(
                                color: AppColors.textOnPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'ملاحظات مهمة',
                              style: AppTextStyles.arabicBody.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• الرحلات الأقدم من 30 ثانية لن تظهر للسائقين تلقائياً\n'
                          '• يتم حساب المسافة بشكل مباشر (خط مستقيم) وليس عبر الطرق\n'
                          '• تأكد من تفعيل خدمات الموقع على أجهزة السائقين',
                          style: AppTextStyles.arabicBodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _maxDistanceController.dispose();
    super.dispose();
  }
}
