import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../utils/shared_preferences_helper.dart';
import '../models/place.dart';
import '../services/driver_location_service.dart';
import 'select_location_screen.dart';
import 'ride_request_screen.dart';
import 'open_trip_request_screen.dart';
import 'wallet_screen.dart';
import 'ride_history_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(18.0735, -15.9582); // Nouakchott
  Place? _pickupPlace;
  Place? _dropoffPlace;
  final Set<Marker> _markers = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _userName = '';
  String _userCity = 'nouakchott';
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadUserCity();
    _getCurrentLocation();
    _initializeDriverLocationService();
  }

  @override
  void dispose() {
    DriverLocationService.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final name = await SharedPreferencesHelper.getUserName();
    setState(() {
      _userName = name ?? 'مستخدم';
    });
  }

  Future<void> _loadUserCity() async {
    final city = await SharedPreferencesHelper.getUserCity();
    setState(() {
      _userCity = city ?? 'nouakchott';
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يرجى السماح بالوصول إلى الموقع'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى تفعيل إذن الموقع من الإعدادات'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
      DriverLocationService.updatePosition(position);
      debugPrint('✅ Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحصول على الموقع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeDriverLocationService() {
    DriverLocationService.initialize(
      cityId: _userCity,
      currentPosition: _currentPosition,
      maxDistanceKm: 1.0,
      onDriversUpdate: (drivers) {
        setState(() {
          _nearbyDrivers = drivers;
          _updateDriverMarkers();
        });
      },
    );
    DriverLocationService.startListening();
  }

  Future<void> _useCurrentLocation() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري الحصول على موقعك...'),
          backgroundColor: Colors.orange,
        ),
      );
      await _getCurrentLocation();
      if (_currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر الحصول على الموقع'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _pickupPlace = Place(
        id: 'current_location',
        name: 'موقعي الحالي',
        description: 'الموقع الحالي للمستخدم',
        location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        cityId: _userCity,
        createdAt: DateTime.now(),
      );
      _updateMarkers();
    });

    // Move camera to current location
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد موقعك الحالي كنقطة انطلاق'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _updateDriverMarkers() {
    // Clear existing driver markers
    _markers.removeWhere((marker) => marker.markerId.value.startsWith('driver_'));

    // Add markers for nearby drivers
    for (var driver in _nearbyDrivers) {
      final location = driver['location'] as GeoPoint;
      _markers.add(
        Marker(
          markerId: MarkerId('driver_${driver['id']}'),
          position: LatLng(location.latitude, location.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: driver['name'],
            snippet: driver['distance'] != null
                ? '${driver['distance'].toStringAsFixed(2)} كم'
                : 'سائق متاح',
          ),
        ),
      );
    }

    // Add pickup marker if selected
    if (_pickupPlace != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(
            _pickupPlace!.location.latitude,
            _pickupPlace!.location.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: _pickupPlace!.name),
        ),
      );
    }

    // Add dropoff marker if selected
    if (_dropoffPlace != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(
            _dropoffPlace!.location.latitude,
            _dropoffPlace!.location.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _dropoffPlace!.name),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Top App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surface,
                    AppColors.surface.withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Menu Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      color: AppColors.primary,
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // App Title
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_taxi_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RimApp',
                            style: AppTextStyles.arabicTitle.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Profile Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.person_rounded),
                      color: AppColors.primary,
                      onPressed: () {
                        // TODO: Open profile
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إلى أين تريد الذهاب؟',
                      style: AppTextStyles.arabicTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Pickup Location
                    Row(
                      children: [
                        Expanded(
                          child: _buildLocationField(
                            icon: Icons.my_location_rounded,
                            iconColor: AppColors.success,
                            label: 'موقع الانطلاق',
                            hint: _pickupPlace?.name ?? 'اختر موقع الانطلاق',
                            isSelected: _pickupPlace != null,
                            onTap: () async {
                              final place = await Navigator.push<Place>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SelectLocationScreen(
                                    title: 'اختر موقع الانطلاق',
                                    isPickup: true,
                                  ),
                                ),
                              );
                              if (place != null) {
                                setState(() {
                                  _pickupPlace = place;
                                  _updateMarkers();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _useCurrentLocation,
                          icon: Icon(Icons.gps_fixed_rounded, color: AppColors.primary),
                          tooltip: 'استخدم موقعي الحالي',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropoff Location
                    _buildLocationField(
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.error,
                      label: 'موقع الوصول',
                      hint: _dropoffPlace?.name ?? 'اختر موقع الوصول',
                      isSelected: _dropoffPlace != null,
                      onTap: () async {
                        final place = await Navigator.push<Place>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SelectLocationScreen(
                              title: 'اختر موقع الوصول',
                              isPickup: false,
                            ),
                          ),
                        );
                        if (place != null) {
                          setState(() {
                            _dropoffPlace = place;
                            _updateMarkers();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Request Ride Button
                    ElevatedButton.icon(
                      onPressed: _pickupPlace != null && _dropoffPlace != null
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RideRequestScreen(
                                    pickupPlace: _pickupPlace!,
                                    dropoffPlace: _dropoffPlace!,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.local_taxi_rounded),
                      label: Text(
                        'طلب رحلة',
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
                    const SizedBox(height: 12),
                    
                    // Open Trip Button
                    OutlinedButton.icon(
                      onPressed: _pickupPlace != null
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OpenTripRequestScreen(
                                    pickupPlace: _pickupPlace!,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: Icon(Icons.explore_rounded, color: _pickupPlace != null ? AppColors.primary : null),
                      label: Text(
                        'رحلة مفتوحة',
                        style: AppTextStyles.arabicTitle.copyWith(
                          color: _pickupPlace != null ? AppColors.primary : null,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _pickupPlace != null ? AppColors.primary : Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateMarkers() {
    _markers.clear();
    
    if (_pickupPlace != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(
            _pickupPlace!.location.latitude,
            _pickupPlace!.location.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'نقطة الانطلاق',
            snippet: _pickupPlace!.name,
          ),
        ),
      );
    }
    
    if (_dropoffPlace != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(
            _dropoffPlace!.location.latitude,
            _dropoffPlace!.location.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'نقطة الوصول',
            snippet: _dropoffPlace!.name,
          ),
        ),
      );
    }
    
    // Move camera to show both markers
    if (_pickupPlace != null && _dropoffPlace != null && _mapController != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _pickupPlace!.location.latitude < _dropoffPlace!.location.latitude
              ? _pickupPlace!.location.latitude
              : _dropoffPlace!.location.latitude,
          _pickupPlace!.location.longitude < _dropoffPlace!.location.longitude
              ? _pickupPlace!.location.longitude
              : _dropoffPlace!.location.longitude,
        ),
        northeast: LatLng(
          _pickupPlace!.location.latitude > _dropoffPlace!.location.latitude
              ? _pickupPlace!.location.latitude
              : _dropoffPlace!.location.latitude,
          _pickupPlace!.location.longitude > _dropoffPlace!.location.longitude
              ? _pickupPlace!.location.longitude
              : _dropoffPlace!.location.longitude,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } else if (_pickupPlace != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_pickupPlace!.location.latitude, _pickupPlace!.location.longitude),
        ),
      );
    }
  }

  Widget _buildLocationField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String hint,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.arabicCaption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: AppTextStyles.arabicBody.copyWith(
                      color: isSelected ? AppColors.textPrimary : AppColors.textHint,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
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
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppColors.background,
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 24,
                left: 24,
                right: 24,
                bottom: 24,
              ),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 35,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName,
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مرحباً بك في RimApp',
                    style: AppTextStyles.arabicBody.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.home_rounded,
                    title: 'الرئيسية',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.wallet_rounded,
                    title: 'المحفظة',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WalletScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history_rounded,
                    title: 'سجل الرحلات',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RideHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_rounded,
                    title: 'الملف الشخصي',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.info_rounded,
                    title: 'حول التطبيق',
                    onTap: () {
                      Navigator.pop(context);
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
                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'تسجيل الخروج',
                    onTap: () async {
                      // Show confirmation dialog
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('تسجيل الخروج', style: AppTextStyles.arabicTitle),
                          content: Text('هل أنت متأكد من تسجيل الخروج؟', style: AppTextStyles.arabicBody),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('إلغاء', style: AppTextStyles.arabicBody),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('تسجيل الخروج', style: AppTextStyles.arabicBody.copyWith(color: AppColors.error)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && mounted) {
                        // Clear user data
                        await SharedPreferencesHelper.clearUserData();
                        
                        // Navigate to login screen
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
      title: Text(
        title,
        style: AppTextStyles.arabicBody.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
