import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/city.dart';
import '../utils/app_theme.dart';

class CitiesScreen extends StatefulWidget {
  const CitiesScreen({super.key});

  @override
  State<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<CitiesScreen> {
  List<City> _cities = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() => _isLoading = true);
    try {
      final nouakchottRef = FirebaseFirestore.instance
          .collection('cities')
          .doc('nouakchott');
      
      final nouakchottDoc = await nouakchottRef.get();
      
      if (!nouakchottDoc.exists) {
        await nouakchottRef.set({
          'name': 'نواكشوط',
          'location': const GeoPoint(18.0857, -15.9785),
          'driversCount': 0,
          'customersCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('cities')
          .orderBy('name')
          .get();

      setState(() {
        _cities = snapshot.docs
            .map((doc) => City.fromMap(doc.data(), doc.id))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading cities: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCity(String name, GeoPoint location) async {
    try {
      await FirebaseFirestore.instance.collection('cities').add({
        'name': name,
        'location': location,
        'driversCount': 0,
        'customersCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة المدينة بنجاح')),
      );
      
      _loadCities();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء إضافة المدينة')),
      );
    }
  }

  Future<void> _toggleCityStatus(City city) async {
    try {
      await FirebaseFirestore.instance
          .collection('cities')
          .doc(city.id)
          .update({
        'isActive': !city.isActive,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            city.isActive
                ? 'تم تعطيل المدينة بنجاح'
                : 'تم تفعيل المدينة بنجاح',
          ),
        ),
      );

      _loadCities();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تحديث حالة المدينة')),
      );
    }
  }

  Future<void> _deleteCity(City city) async {
    try {
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('cityId', isEqualTo: city.id)
          .get();

      final customersSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('cityId', isEqualTo: city.id)
          .get();

      final placesSnapshot = await FirebaseFirestore.instance
          .collection('places')
          .where('cityId', isEqualTo: city.id)
          .get();

      final pricesSnapshot = await FirebaseFirestore.instance
          .collection('prices')
          .where('cityId', isEqualTo: city.id)
          .get();

      if (driversSnapshot.docs.isNotEmpty ||
          customersSnapshot.docs.isNotEmpty ||
          placesSnapshot.docs.isNotEmpty ||
          pricesSnapshot.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'لا يمكن حذف المدينة لوجود بيانات مرتبطة بها (سائقين، زبناء، أماكن أو أسعار)',
              ),
            ),
          );
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('cities')
          .doc(city.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المدينة بنجاح')),
        );
      }

      _loadCities();
    } catch (e) {
      print('Error deleting city: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء حذف المدينة')),
        );
      }
    }
  }

  void _showAddCityDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مدينة جديدة', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'اسم المدينة',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: latController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'خط العرض',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lngController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'خط الطول',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty ||
                  latController.text.isEmpty ||
                  lngController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال جميع البيانات')),
                );
                return;
              }

              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);

              if (lat == null || lng == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('الرجاء إدخال إحداثيات صحيحة')),
                );
                return;
              }

              Navigator.pop(context);
              _addCity(
                nameController.text,
                GeoPoint(lat, lng),
              );
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Widget _buildCityCard(City city) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_city_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city.name,
                        style: AppTextStyles.arabicTitle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: city.isActive ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              city.isActive ? 'نشط' : 'معطل',
                              style: AppTextStyles.arabicCaption.copyWith(
                                color: city.isActive ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: city.isActive,
                  onChanged: (value) => _toggleCityStatus(city),
                  activeColor: AppColors.primary,
                ),
                if (city.id != 'nouakchott')
                  IconButton(
                    icon: Icon(Icons.delete_rounded, color: AppColors.error),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('حذف المدينة', style: AppTextStyles.arabicTitle),
                        content: Text(
                          'هل أنت متأكد من حذف مدينة ${city.name}؟\n\nلا يمكن التراجع عن هذا الإجراء.',
                          style: AppTextStyles.arabicBody,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('إلغاء', style: AppTextStyles.arabicBody),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteCity(city);
                            },
                            child: Text('حذف', style: AppTextStyles.arabicBody.copyWith(color: AppColors.error)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.local_taxi_rounded,
                    label: 'السائقون',
                    value: '${city.driversCount}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.person_rounded,
                    label: 'الزبناء',
                    value: '${city.customersCount}',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${city.location.latitude.toStringAsFixed(4)}, ${city.location.longitude.toStringAsFixed(4)}',
                      style: AppTextStyles.arabicBodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.arabicTitle.copyWith(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.arabicCaption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
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
          'إدارة المدن',
          style: AppTextStyles.arabicTitle.copyWith(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCityDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: Text('إضافة مدينة', style: AppTextStyles.arabicBody.copyWith(color: Colors.white)),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _cities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_city_rounded,
                        size: 64,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد مدن مضافة',
                        style: AppTextStyles.arabicTitle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _cities.length,
                  padding: const EdgeInsets.only(
                    top: 8,
                    bottom: 80,
                  ),
                  itemBuilder: (context, index) => _buildCityCard(_cities[index]),
                ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
