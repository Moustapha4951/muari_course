import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/city.dart';
import '../models/place.dart';
import '../utils/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  List<City> _cities = [];
  List<Place> _places = [];
  bool _isLoading = true;
  City? _selectedCity;
  final TextEditingController _searchController = TextEditingController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cities')
          .orderBy('name')
          .get();

      setState(() {
        _cities = snapshot.docs
            .map((doc) => City.fromMap(doc.data(), doc.id))
            .toList();
        
        if (_cities.isNotEmpty && _selectedCity == null) {
          _selectedCity = _cities.first;
          _loadPlaces();
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      print('Error loading cities: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPlaces() async {
    if (_selectedCity == null) return;

    setState(() => _isLoading = true);
    try {
      print('Loading places for city: ${_selectedCity!.id}');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('places')
          .where('cityId', isEqualTo: _selectedCity!.id)
          .get();

      if (snapshot.docs.isEmpty && _selectedCity!.id == 'nouakchott') {
        print('No places found in Firestore. Adding default places...');
        
        final batch = FirebaseFirestore.instance.batch();
        final defaultPlaces = Places.places;
        
        for (var place in defaultPlaces) {
          final docRef = FirebaseFirestore.instance.collection('places').doc();
          final placeData = {
            'name': place.name,
            'description': place.description,
            'location': place.location,
            'cityId': 'nouakchott',
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
          };
          batch.set(docRef, placeData);
        }

        await batch.commit();
        print('Added ${defaultPlaces.length} default places');

        final newSnapshot = await FirebaseFirestore.instance
            .collection('places')
            .where('cityId', isEqualTo: _selectedCity!.id)
            .get();

        setState(() {
          _places = newSnapshot.docs
              .map((doc) => Place.fromMap(doc.data(), doc.id))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _places = snapshot.docs
              .map((doc) => Place.fromMap(doc.data(), doc.id))
              .toList();
          _isLoading = false;
        });
      }

      print('Loaded ${_places.length} places');
    } catch (e) {
      print('Error loading places: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في تحميل الأماكن')),
        );
      }
    }
  }

  List<Place> _getFilteredPlaces() {
    if (_searchController.text.isEmpty) return _places;
    
    final query = _searchController.text.toLowerCase();
    return _places.where((place) {
      return place.name.toLowerCase().contains(query) ||
             place.description.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _addPlace(String name, String description, GeoPoint location) async {
    if (_selectedCity == null) return;

    try {
      await FirebaseFirestore.instance.collection('places').add({
        'name': name,
        'description': description,
        'location': location,
        'cityId': _selectedCity!.id,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة المكان بنجاح')),
      );
      
      _loadPlaces();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء إضافة المكان')),
      );
    }
  }

  Future<void> _togglePlaceStatus(Place place) async {
    try {
      await FirebaseFirestore.instance
          .collection('places')
          .doc(place.id)
          .update({
        'isActive': !place.isActive,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            place.isActive
                ? 'تم تعطيل المكان بنجاح'
                : 'تم تفعيل المكان بنجاح',
          ),
        ),
      );

      _loadPlaces();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تحديث حالة المكان')),
      );
    }
  }

  Future<void> _deletePlace(Place place) async {
    try {
      await FirebaseFirestore.instance
          .collection('places')
          .doc(place.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المكان بنجاح')),
      );

      _loadPlaces();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء حذف المكان')),
      );
    }
  }

  void _showAddPlaceDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مكان جديد', textAlign: TextAlign.right),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'اسم المكان',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                textAlign: TextAlign.right,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'وصف المكان',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty ||
                  descriptionController.text.isEmpty ||
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
              _addPlace(
                nameController.text,
                descriptionController.text,
                GeoPoint(lat, lng),
              );
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(Place place) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: place.isActive ? AppColors.border : AppColors.error.withOpacity(0.2),
          width: 1,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete_rounded, color: AppColors.error),
                      onPressed: () => _showDeleteDialog(place),
                      tooltip: 'حذف',
                    ),
                    Switch(
                      value: place.isActive,
                      onChanged: (value) => _togglePlaceStatus(place),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        place.name,
                        style: AppTextStyles.arabicBody.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: place.isActive
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          place.isActive ? 'نشط' : 'معطل',
                          style: AppTextStyles.arabicCaption.copyWith(
                            color: place.isActive ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                height: 1,
                color: AppColors.border,
              ),
            ),
            Text(
              place.description,
              style: AppTextStyles.arabicBodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  '${place.location.latitude.toStringAsFixed(4)}, ${place.location.longitude.toStringAsFixed(4)}',
                  style: AppTextStyles.arabicCaption.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Place place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حذف المكان',
          style: AppTextStyles.arabicTitle,
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من حذف ${place.name}؟',
          style: AppTextStyles.arabicBody,
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePlace(place);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlaces = _getFilteredPlaces();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'إدارة الأماكن',
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
            onPressed: _loadPlaces,
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: _selectedCity != null
          ? FloatingActionButton.extended(
              onPressed: _showAddPlaceDialog,
              backgroundColor: AppColors.secondary,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'إضافة مكان',
                style: AppTextStyles.arabicBody.copyWith(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                DropdownButtonFormField<City>(
                  value: _selectedCity,
                  decoration: InputDecoration(
                    labelText: 'اختر المدينة',
                    labelStyle: AppTextStyles.arabicBody.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                  ),
                  items: _cities.map((city) {
                    return DropdownMenuItem(
                      value: city,
                      child: Text(
                        city.name,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.arabicBody,
                      ),
                    );
                  }).toList(),
                  onChanged: (city) {
                    setState(() {
                      _selectedCity = city;
                      _loadPlaces();
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.arabicBody,
                  decoration: InputDecoration(
                    hintText: 'بحث عن مكان...',
                    hintStyle: AppTextStyles.arabicBody.copyWith(
                      color: AppColors.textHint,
                    ),
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildLoadingShimmer()
                : _selectedCity == null
                    ? _buildEmptyState(
                        Icons.location_city_rounded,
                        'الرجاء اختيار مدينة',
                      )
                    : filteredPlaces.isEmpty
                        ? _buildEmptyState(
                            Icons.place_rounded,
                            'لا توجد أماكن في ${_selectedCity!.name}',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadPlaces,
                            child: ListView.builder(
                              itemCount: filteredPlaces.length,
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                              itemBuilder: (context, index) =>
                                  _buildPlaceCard(filteredPlaces[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.all(24),
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.arabicBody.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
