import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/place.dart';
import '../utils/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final String title;
  final String cityId;
  final Position? initialPosition;

  const MapPickerScreen({
    super.key,
    required this.title,
    required this.cityId,
    this.initialPosition,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  final Set<Marker> _markers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _selectedLocation = LatLng(
        widget.initialPosition!.latitude,
        widget.initialPosition!.longitude,
      );
      _updateMarker();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _updateMarker();
    });
  }

  void _updateMarker() {
    _markers.clear();
    if (_selectedLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(
            title: 'الموقع المحدد',
          ),
        ),
      );
    }
  }

  Future<void> _confirmLocation() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقع على الخريطة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Find nearest place from Firestore
      String locationName = 'موقع محدد';
      
      final placesSnapshot = await FirebaseFirestore.instance
          .collection('places')
          .where('cityId', isEqualTo: widget.cityId)
          .where('isActive', isEqualTo: true)
          .get();

      if (placesSnapshot.docs.isNotEmpty) {
        double minDistance = double.infinity;
        String nearestPlaceName = '';

        for (var doc in placesSnapshot.docs) {
          final placeData = doc.data();
          final placeLocation = placeData['location'] as GeoPoint;
          
          // Calculate distance using Haversine formula approximation
          final lat1 = _selectedLocation!.latitude;
          final lon1 = _selectedLocation!.longitude;
          final lat2 = placeLocation.latitude;
          final lon2 = placeLocation.longitude;
          
          final dLat = (lat2 - lat1) * 111.32; // km per degree latitude
          final dLon = (lon2 - lon1) * 111.32 * 0.9; // approximate for latitude
          final distance = (dLat * dLat + dLon * dLon);
          
          if (distance < minDistance) {
            minDistance = distance;
            nearestPlaceName = placeData['name'] ?? '';
          }
        }

        if (nearestPlaceName.isNotEmpty) {
          locationName = 'قرب $nearestPlaceName';
        }
      }

      // Create a Place object with the selected location
      final place = Place(
        id: 'map_selected_${DateTime.now().millisecondsSinceEpoch}',
        name: locationName,
        description: 'موقع تم اختياره من الخريطة',
        location: GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        cityId: widget.cityId,
        createdAt: DateTime.now(),
      );

      if (mounted) {
        Navigator.pop(context, place);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('تم رفض إذن الموقع');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('يرجى تفعيل إذن الموقع من الإعدادات');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _updateMarker();
      });

      // Move camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 16),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديد موقعك الحالي'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
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
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ??
                  (widget.initialPosition != null
                      ? LatLng(widget.initialPosition!.latitude, widget.initialPosition!.longitude)
                      : const LatLng(18.0735, -15.9582)), // Nouakchott
              zoom: 14,
            ),
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.arabicTitle.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
          ),

          // Instructions
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                  Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'اضغط على الخريطة لتحديد الموقع',
                      style: AppTextStyles.arabicBodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 180,
            right: 16,
            child: FloatingActionButton(
              onPressed: _isLoading ? null : _useCurrentLocation,
              backgroundColor: Colors.white,
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : Icon(Icons.my_location_rounded, color: AppColors.primary),
            ),
          ),

          // Confirm Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _isLoading || _selectedLocation == null ? null : _confirmLocation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    'تأكيد الموقع',
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
