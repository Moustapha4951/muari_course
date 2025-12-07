import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_theme.dart';
import '../models/place.dart';
import 'map_picker_screen.dart';

class SelectLocationScreen extends StatefulWidget {
  final String title;
  final bool isPickup;

  const SelectLocationScreen({
    super.key,
    required this.title,
    this.isPickup = true,
  });

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Place> _places = [];
  List<Place> _filteredPlaces = [];
  bool _isLoading = true;
  String? _selectedCityId;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('places')
          .where('isActive', isEqualTo: true)
          .get();

      _places = snapshot.docs
          .map((doc) => Place.fromMap(doc.data(), doc.id))
          .toList();
      _filteredPlaces = _places;
    } catch (e) {
      debugPrint('Error loading places: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPlaces(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPlaces = _places;
      } else {
        _filteredPlaces = _places
            .where((place) =>
                place.name.toLowerCase().contains(query.toLowerCase()) ||
                place.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTextStyles.arabicTitle,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  style: AppTextStyles.arabicBody,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن موقع...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _filterPlaces('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: _filterPlaces,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    Position? currentPosition;
                    try {
                      currentPosition = await Geolocator.getCurrentPosition();
                    } catch (e) {
                      debugPrint('Could not get current position: $e');
                    }

                    if (mounted) {
                      final place = await Navigator.push<Place>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapPickerScreen(
                            title: widget.title,
                            cityId: 'nouakchott',
                            initialPosition: currentPosition,
                          ),
                        ),
                      );
                      if (place != null && mounted) {
                        Navigator.pop(context, place);
                      }
                    }
                  },
                  icon: Icon(Icons.map_rounded, color: AppColors.primary),
                  label: Text(
                    'اختر من الخريطة',
                    style: AppTextStyles.arabicBody.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Places List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : _filteredPlaces.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredPlaces.length,
                        itemBuilder: (context, index) {
                          final place = _filteredPlaces[index];
                          return _buildPlaceCard(place);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(Place place) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        onTap: () => Navigator.pop(context, place),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isPickup
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.isPickup
                      ? Icons.my_location_rounded
                      : Icons.location_on_rounded,
                  color: widget.isPickup ? AppColors.success : AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: AppTextStyles.arabicBody.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.description,
                      style: AppTextStyles.arabicBodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_rounded,
            size: 80,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مواقع',
            style: AppTextStyles.arabicTitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جرب البحث بكلمات مختلفة',
            style: AppTextStyles.arabicBody.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
