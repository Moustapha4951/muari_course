import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rimapp_driver/utils/app_theme.dart';
import '../utils/sharedpreferences_helper.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetDriverPhoneController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String _driverId = '';
  String _driverPhone = '';
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
  }

  Future<void> _loadDriverInfo() async {
    setState(() => _isLoading = true);

    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      _driverId = driverData['driverId'] ?? '';
      _driverPhone = driverData['phone'] ?? '';

      if (_driverId.isNotEmpty) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(_driverId)
            .get();

        if (driverDoc.exists) {
          setState(() {
            _currentBalance = (driverDoc.data()?['balance'] ?? 0).toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint('خطأ في تحميل معلومات السائق: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _transferBalance() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final targetPhone = _targetDriverPhoneController.text.trim();
      final transferAmount = double.parse(_amountController.text.trim());

      if (transferAmount <= 0) {
        _showErrorMessage('يجب أن يكون المبلغ أكبر من صفر');
        return;
      }

      if (transferAmount > _currentBalance) {
        _showErrorMessage('رصيدك غير كافٍ لإجراء هذا التحويل');
        return;
      }

      final QuerySnapshot targetDriverQuery = await FirebaseFirestore.instance
          .collection('drivers')
          .where('phone', isEqualTo: targetPhone)
          .limit(1)
          .get();

      if (targetDriverQuery.docs.isEmpty) {
        _showErrorMessage('لم يتم العثور على سائق برقم الهاتف المدخل');
        return;
      }

      final targetDriverDoc = targetDriverQuery.docs.first;
      final targetDriverId = targetDriverDoc.id;
      final targetDriverName = targetDriverDoc.get('name') ?? 'سائق';

      if (targetDriverId == _driverId) {
        _showErrorMessage('لا يمكنك تحويل الرصيد لنفسك');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      final currentDriverRef =
          FirebaseFirestore.instance.collection('drivers').doc(_driverId);
      batch.update(currentDriverRef, {
        'balance': FieldValue.increment(-transferAmount),
      });

      final targetDriverRef =
          FirebaseFirestore.instance.collection('drivers').doc(targetDriverId);
      batch.update(targetDriverRef, {
        'balance': FieldValue.increment(transferAmount),
      });

      final transferRef =
          FirebaseFirestore.instance.collection('balance_transfers').doc();

      batch.set(transferRef, {
        'fromDriverId': _driverId,
        'fromDriverPhone': _driverPhone,
        'toDriverId': targetDriverId,
        'toDriverPhone': targetPhone,
        'toDriverName': targetDriverName,
        'amount': transferAmount,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      await batch.commit();

      setState(() {
        _currentBalance -= transferAmount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('تم تحويل $transferAmount MRU إلى $targetDriverName بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      _targetDriverPhoneController.clear();
      _amountController.clear();
    } catch (e) {
      debugPrint('خطأ في تحويل الرصيد: $e');
      _showErrorMessage('حدث خطأ أثناء تحويل الرصيد');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelAllRides() async {
    final shouldCancel = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد إلغاء الرحلات'),
            content: const Text(
              'هل أنت متأكد من رغبتك في إلغاء جميع الرحلات التي لم تكتمل؟ لا يمكن التراجع عن هذا الإجراء.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'تأكيد الإلغاء',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldCancel) return;

    setState(() => _isLoading = true);

    try {
      final pendingRidesQuery = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: _driverId)
          .where('status',
              whereIn: ['accepted', 'on_way', 'started', 'pending']).get();

      if (pendingRidesQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد رحلات غير مكتملة لإلغائها')),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in pendingRidesQuery.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancellationReason': 'تم الإلغاء من قبل السائق',
        });
      }

      final driverRef =
          FirebaseFirestore.instance.collection('drivers').doc(_driverId);

      batch.update(driverRef, {
        'status': 'available',
        'currentRideId': null,
      });

      await batch.commit();

      final count = pendingRidesQuery.docs.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('تم إلغاء $count ${count == 1 ? 'رحلة' : 'رحلات'} بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('خطأ في إلغاء الرحلات: $e');
      _showErrorMessage('حدث خطأ أثناء إلغاء الرحلات');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
                            Icons.settings_rounded,
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
                      'الإعدادات',
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
                child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildBalanceCard(),
                              const SizedBox(height: 20),
                              _buildTransferBalanceSection(),
                              const SizedBox(height: 20),
                              _buildCancelRidesSection(),
                              const SizedBox(height: 20),
                              _buildMapProblemSection(),
                              const SizedBox(height: 20),
                            ],
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

  Widget _buildBalanceCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'رصيدك الحالي',
                  style: AppTextStyles.arabicTitle.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${_currentBalance.toStringAsFixed(0)} MRU',
              style: AppTextStyles.arabicDisplayMedium.copyWith(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferBalanceSection() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
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
                      Icons.send_to_mobile_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تحويل الرصيد',
                      style: AppTextStyles.arabicHeadline.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetDriverPhoneController,
                decoration: InputDecoration(
                  labelText: 'رقم هاتف السائق',
                  hintText: 'أدخل رقم هاتف السائق المستهدف',
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال رقم الهاتف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'المبلغ (MRU)',
                  hintText: 'أدخل المبلغ المراد تحويله',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال المبلغ';
                  }
                  try {
                    final amount = double.parse(value);
                    if (amount <= 0) return 'يجب أن يكون المبلغ أكبر من صفر';
                    if (amount > _currentBalance) return 'رصيدك غير كافٍ';
                  } catch (e) {
                    return 'الرجاء إدخال مبلغ صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _transferBalance,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('تحويل الرصيد'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelRidesSection() {
    return Container(
      decoration: AppDecorations.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel_outlined, color: AppColors.error),
                const SizedBox(width: 8),
                Text('إلغاء الرحلات', style: AppTextStyles.arabicHeadline.copyWith(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'إلغاء جميع الرحلات التي لم تكتمل. يرجى استخدام هذا الخيار بحذر.',
              style: AppTextStyles.arabicBodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _cancelAllRides,
                icon: const Icon(Icons.delete_forever_rounded),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                label: const Text('إلغاء جميع الرحلات'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapProblemSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 1, color: AppColors.divider),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('حل مشاكل الخريطة', style: AppTextStyles.arabicHeadline.copyWith(fontSize: 18)),
        ),
        Container(
          decoration: AppDecorations.cardDecoration,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إذا كانت الخريطة تظهر باللون الأبيض أو لا تظهر بشكل صحيح، قد تحتاج إلى منح التطبيق الصلاحيات المطلوبة:',
                  style: AppTextStyles.arabicBody,
                ),
                const SizedBox(height: 12),
                FutureBuilder<bool>(
                  future: _isXiaomiDevice(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data == true) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('لحل مشكلة الخريطة في أجهزة شاومي / ريدمي:',
                              style: AppTextStyles.arabicTitle),
                          const SizedBox(height: 8),
                          Text(
                            '1. انتقل إلى إعدادات الهاتف > التطبيقات > إدارة التطبيقات\n'
                            '2. ابحث عن تطبيق وصلني سائق\n'
                            '3. اختر \"الأذونات\"\n'
                            '4. فعّل \"العرض فوق التطبيقات الأخرى\"\n'
                            '5. فعّل \"الموقع\" واختر \"السماح طوال الوقت\"\n'
                            '6. عد إلى التطبيق وأعد تشغيله',
                            style: AppTextStyles.arabicBodySmall,
                          ),
                        ],
                      );
                    }
                    return Text(
                      'تأكد من منح التطبيق إذن الوصول إلى الموقع والعرض فوق التطبيقات الأخرى.',
                      style: AppTextStyles.arabicBody,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _checkAndRequestPermissions,
                      child: const Text('طلب الأذونات'),
                    ),
                    FilledButton.tonal(
                      onPressed: _openAppSettings,
                      child: const Text('فتح الإعدادات'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _resetMapSettings,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة ضبط إعدادات الخريطة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _isXiaomiDevice() async {
    if (!Platform.isAndroid) return false;
    try {
      const platform = MethodChannel('com.wassalni.driver/device_info');
      final String manufacturer =
          await platform.invokeMethod('getManufacturer') ?? "";
      return manufacturer.toLowerCase().contains('xiaomi') ||
          manufacturer.toLowerCase().contains('redmi');
    } catch (e) {
      debugPrint('خطأ في التحقق من نوع الجهاز: $e');
      return false;
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه الميزة متاحة فقط على أجهزة Android')),
      );
      return;
    }

    try {
      final locationStatus = await Permission.location.request();
      if (locationStatus.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض إذن الموقع بشكل دائم. يرجى تفعيله من إعدادات التطبيق'),
          ),
        );
        return;
      }

      final overlayStatus = await Permission.systemAlertWindow.request();
      if (overlayStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم منح الأذونات المطلوبة. أعد تشغيل التطبيق لتفع��ل التغييرات'),
          ),
        );
      } else {
        _openAppSettings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    }
  }

  void _openAppSettings() async {
    if (await openAppSettings()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("قم بتفعيل إذن 'العرض فوق التطبيقات الأخرى' وإذن 'الموقع'"),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح إعدادات التطبيق تلقائيًا. يرجى فتحها يدويًا'),
        ),
      );
    }
  }

  Future<void> _resetMapSettings() async {
    try {
      await SharedPreferencesHelper.clearData('map_style_applied');
      await SharedPreferencesHelper.clearData('map_last_position');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إعادة ضبط إعدادات الخريطة. أعد تشغيل التطبيق لتفعيل التغييرات'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء ��عادة الضبط: $e')),
      );
    }
  }

  @override
  void dispose() {
    _targetDriverPhoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
