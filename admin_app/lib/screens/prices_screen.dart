import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/price.dart';
import 'package:intl/intl.dart' as intl;
import '../utils/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class PricesScreen extends StatefulWidget {
  const PricesScreen({super.key});

  @override
  State<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends State<PricesScreen> {
  List<Price> _prices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    try {
      print('Loading prices');
      final snapshot = await FirebaseFirestore.instance
          .collection('prices')
          .orderBy('lastUpdated', descending: true)
          .get();

      setState(() {
        _prices = snapshot.docs
            .map((doc) => Price.fromMap(doc.data(), doc.id))
            .toList();
        _isLoading = false;
      });

      print('Loaded ${_prices.length} prices');
    } catch (e) {
      print('Error loading prices: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في تحميل الأسعار')),
        );
      }
    }
  }

  Future<void> _addOrUpdatePrice(Price? existingPrice) async {
    final TextEditingController minimumFareController = TextEditingController(
      text: existingPrice?.minimumFare.toString() ?? '',
    );
    final TextEditingController pricePerKmController = TextEditingController(
      text: existingPrice?.pricePerKm.toString() ?? '',
    );
    final TextEditingController maximumKmController = TextEditingController(
      text: existingPrice?.maximumKm.toString() ?? '',
    );
    final TextEditingController openRideBaseFareController =
        TextEditingController(
      text: existingPrice?.openRideBaseFare.toString() ?? '',
    );
    final TextEditingController openRidePerMinuteController =
        TextEditingController(
      text: existingPrice?.openRidePerMinute.toString() ?? '',
    );
    final TextEditingController nightFareMultiplierController =
        TextEditingController(
      text: existingPrice?.nightFareMultiplier.toString() ?? '1.2',
    );
    final TextEditingController driverShareController = TextEditingController(
      text: existingPrice?.driverShare.toString() ?? '0.8',
    );
    final TextEditingController appCommissionController = TextEditingController(
      text: existingPrice?.appCommission.toString() ?? '0.2',
    );
    final TextEditingController cancellationFeeController =
        TextEditingController(
      text: existingPrice?.cancellationFee?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existingPrice == null ? 'إضافة تسعيرة جديدة' : 'تعديل التسعيرة',
          textAlign: TextAlign.right,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minimumFareController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'الحد الأدنى للسعر',
                  suffixText: 'MRU',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pricePerKmController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'السعر لكل كيلومتر',
                  suffixText: 'MRU',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: maximumKmController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'الحد الأقصى للكيلومترات المشمولة بالسعر الأدنى',
                  suffixText: 'كم',
                  helperText:
                      'المسافات الأقل من هذا الحد ستكون بالسعر الأدنى فقط',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: openRideBaseFareController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'السعر الإبتدائي للرحلة المفتوحة',
                  suffixText: 'MRU',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: openRidePerMinuteController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'السعر بالدقيقة للرحلة المفتوحة',
                  suffixText: 'MRU',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nightFareMultiplierController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'نسبة زيادة السعر بعد منتصف الليل',
                  helperText: 'مثال: 1.2 تعني زيادة 20%',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: driverShareController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'نسبة السائق',
                  helperText: 'مثال: 0.8 تعني 80%',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: appCommissionController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'نسبة التطبيق',
                  helperText: 'مثال: 0.2 تعني 20%',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cancellationFeeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'عمولة إلغاء الرحلة (اختياري)',
                  suffixText: 'MRU',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              final minimumFare = double.tryParse(minimumFareController.text);
              final pricePerKm = double.tryParse(pricePerKmController.text);
              final maximumKm = double.tryParse(maximumKmController.text);
              final openRideBaseFare =
                  double.tryParse(openRideBaseFareController.text);
              final openRidePerMinute =
                  double.tryParse(openRidePerMinuteController.text);
              final nightFareMultiplier =
                  double.tryParse(nightFareMultiplierController.text);
              final driverShare = double.tryParse(driverShareController.text);
              final appCommission =
                  double.tryParse(appCommissionController.text);
              final cancellationFee =
                  double.tryParse(cancellationFeeController.text);

              if (minimumFare == null ||
                  pricePerKm == null ||
                  maximumKm == null ||
                  openRideBaseFare == null ||
                  openRidePerMinute == null ||
                  nightFareMultiplier == null ||
                  driverShare == null ||
                  appCommission == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('الرجاء إدخال قيم صحيحة لجميع الحقول المطلوبة')),
                );
                return;
              }

              if ((driverShare + appCommission) != 1.0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'يجب أن يكون مجموع نسبة السائق ونسبة التطبيق يساوي 100%')),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: Text(existingPrice == null ? 'إضافة' : 'تحديث'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        setState(() => _isLoading = true);

        final data = {
          'minimumFare': double.parse(minimumFareController.text),
          'pricePerKm': double.parse(pricePerKmController.text),
          'maximumKm': double.parse(maximumKmController.text),
          'openRideBaseFare': double.parse(openRideBaseFareController.text),
          'openRidePerMinute': double.parse(openRidePerMinuteController.text),
          'nightFareMultiplier':
              double.parse(nightFareMultiplierController.text),
          'driverShare': double.parse(driverShareController.text),
          'appCommission': double.parse(appCommissionController.text),
          'lastUpdated': FieldValue.serverTimestamp(),
          'isActive': true,
        };

        if (cancellationFeeController.text.isNotEmpty) {
          data['cancellationFee'] =
              double.parse(cancellationFeeController.text);
        }

        print('Saving price data: $data');

        if (existingPrice != null) {
          final batch = FirebaseFirestore.instance.batch();
          for (final price in _prices) {
            if (price.id != existingPrice.id && price.isActive) {
              batch.update(
                FirebaseFirestore.instance.collection('prices').doc(price.id),
                {'isActive': false},
              );
            }
          }
          batch.update(
            FirebaseFirestore.instance
                .collection('prices')
                .doc(existingPrice.id),
            data,
          );
          await batch.commit();
        } else {
          final batch = FirebaseFirestore.instance.batch();
          for (final price in _prices) {
            if (price.isActive) {
              batch.update(
                FirebaseFirestore.instance.collection('prices').doc(price.id),
                {'isActive': false},
              );
            }
          }
          batch.set(
            FirebaseFirestore.instance.collection('prices').doc(),
            data,
          );
          await batch.commit();
        }

        await _loadPrices();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existingPrice == null
                    ? 'تمت إضافة التسعيرة بنجاح'
                    : 'تم تحديث التسعيرة بنجاح',
              ),
            ),
          );
        }
      } catch (e) {
        print('Error saving price: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء حفظ التسعيرة: $e')),
          );
        }
      }
    }
  }

  Future<void> _togglePriceStatus(Price price) async {
    try {
      if (!price.isActive) {
        final batch = FirebaseFirestore.instance.batch();
        for (final p in _prices) {
          if (p.id != price.id && p.isActive) {
            batch.update(
              FirebaseFirestore.instance.collection('prices').doc(p.id),
              {'isActive': false},
            );
          }
        }
        batch.update(
          FirebaseFirestore.instance.collection('prices').doc(price.id),
          {'isActive': true},
        );
        await batch.commit();
      } else {
        await FirebaseFirestore.instance
            .collection('prices')
            .doc(price.id)
            .update({'isActive': false});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            price.isActive
                ? 'تم تعطيل التسعيرة بنجاح'
                : 'تم تفعيل التسعيرة بنجاح',
          ),
        ),
      );

      _loadPrices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تحديث حالة التسعيرة')),
      );
    }
  }

  Widget _buildPriceCard(Price price) {
    final formatter = intl.NumberFormat('#,##0.00', 'ar');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: price.isActive
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.border,
          width: price.isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Switch(
                      value: price.isActive,
                      onChanged: (value) => _togglePriceStatus(price),
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    if (price.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'نشط',
                              style: AppTextStyles.arabicCaption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          intl.DateFormat('yyyy/MM/dd').format(price.lastUpdated),
                          style: AppTextStyles.arabicCaption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      intl.DateFormat('HH:mm').format(price.lastUpdated),
                      style: AppTextStyles.arabicCaption.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                height: 1,
                color: AppColors.border,
              ),
            ),
            _buildSectionTitle('الأسعار الأساسية'),
            const SizedBox(height: 8),
            _buildInfoRow('الحد الأدنى للسعر',
                '${formatter.format(price.minimumFare)} MRU', Icons.attach_money_rounded),
            _buildInfoRow('السعر لكل كيلومتر',
                '${formatter.format(price.pricePerKm)} MRU', Icons.speed_rounded),
            _buildInfoRow('الحد الأقصى للكيلومترات',
                '${formatter.format(price.maximumKm)} كم', Icons.straighten_rounded),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                height: 1,
                color: AppColors.border,
              ),
            ),
            _buildSectionTitle('الرحلة المفتوحة'),
            const SizedBox(height: 8),
            _buildInfoRow('السعر الإبتدائي',
                '${formatter.format(price.openRideBaseFare)} MRU', Icons.flag_rounded),
            _buildInfoRow('السعر بالدقيقة',
                '${formatter.format(price.openRidePerMinute)} MRU', Icons.timer_rounded),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                height: 1,
                color: AppColors.border,
              ),
            ),
            _buildSectionTitle('النسب والعمولات'),
            const SizedBox(height: 8),
            _buildInfoRow('زيادة السعر ليلاً',
                '${((price.nightFareMultiplier - 1) * 100).toStringAsFixed(0)}%', Icons.nightlight_rounded),
            _buildInfoRow('نسبة السائق',
                '${(price.driverShare * 100).toStringAsFixed(0)}%', Icons.person_rounded),
            _buildInfoRow('نسبة التطبيق',
                '${(price.appCommission * 100).toStringAsFixed(0)}%', Icons.apps_rounded),
            if (price.cancellationFee != null)
              _buildInfoRow('عمولة الإلغاء',
                  '${formatter.format(price.cancellationFee)} MRU', Icons.cancel_rounded),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addOrUpdatePrice(price),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text(
                  'تعديل التسعيرة',
                  style: AppTextStyles.arabicBody.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: AppTextStyles.arabicBodySmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTextStyles.arabicBodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.arabicBodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'إدارة الأسعار',
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadPrices,
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrUpdatePrice(null),
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'إضافة تسعيرة',
          style: AppTextStyles.arabicBody.copyWith(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingShimmer()
          : _prices.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPrices,
                  child: ListView.builder(
                    itemCount: _prices.length,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                    itemBuilder: (context, index) =>
                        _buildPriceCard(_prices[index]),
                  ),
                ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 3,
        padding: const EdgeInsets.all(24),
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.attach_money_rounded,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد تسعيرات',
            style: AppTextStyles.arabicBody.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
