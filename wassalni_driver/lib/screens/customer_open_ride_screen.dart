import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_theme.dart';
import '../utils/sharedpreferences_helper.dart';
import 'dart:async';

class CustomerOpenRideScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const CustomerOpenRideScreen({
    super.key,
    required this.rideId,
    required this.rideData,
  });

  @override
  State<CustomerOpenRideScreen> createState() => _CustomerOpenRideScreenState();
}

class _CustomerOpenRideScreenState extends State<CustomerOpenRideScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Map<String, dynamic>? _rideData;
  final Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _isAccepting = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _rideData = widget.rideData;
    _listenToRideUpdates();
    _getCurrentLocation();
    _updateMarkers();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _getCurrentLocation() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        _updateMarkers();
      });
    });
  }

  void _listenToRideUpdates() {
    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        if (mounted) Navigator.pop(context);
        return;
      }

      setState(() {
        _rideData = snapshot.data();
        _updateMarkers();
      });

      // Check if ride was accepted by another driver
      final status = _rideData?['status'];
      final driverId = _rideData?['driverId'];
      
      if (status == 'accepted' && driverId != null) {
        _checkIfAcceptedByMe(driverId);
      }
    });
  }

  Future<void> _checkIfAcceptedByMe(String acceptedDriverId) async {
    final myDriverId = await SharedPreferencesHelper.getUserId();
    if (myDriverId != acceptedDriverId && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول الرحلة من سائق آخر'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // Pickup marker
    final pickupLocation = _rideData?['pickupLocation'] as GeoPoint?;
    if (pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickupLocation.latitude, pickupLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'نقطة الانطلاق',
            snippet: _rideData?['pickupAddress'],
          ),
        ),
      );
    }

    // Dropoff marker
    final dropoffLocation = _rideData?['dropoffLocation'] as GeoPoint?;
    if (dropoffLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(dropoffLocation.latitude, dropoffLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'نقطة الوصول',
            snippet: _rideData?['dropoffAddress'],
          ),
        ),
      );
    }

    // My location marker
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('myLocation'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'موقعي'),
        ),
      );
    }
  }

  Future<void> _acceptRide() async {
    setState(() => _isAccepting = true);

    try {
      final driverId = await SharedPreferencesHelper.getUserId();
      final driverName = await SharedPreferencesHelper.getUserName();
      final driverPhone = await SharedPreferencesHelper.getUserPhone();

      if (driverId == null || driverName == null || driverPhone == null) {
        throw Exception('بيانات السائق غير متوفرة');
      }

      // Update ride with driver info
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'status': 'accepted',
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'acceptedAt': FieldValue.serverTimestamp(),
        'driverLocation': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
      });

      // Update driver status to busy
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'status': 'busy',
        'currentRideId': widget.rideId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول الرحلة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAccepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في قبول الرحلة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickupAddress = _rideData?['pickupAddress'] ?? 'غير محدد';
    final dropoffAddress = _rideData?['dropoffAddress'] ?? 'غير محدد';
    final customerName = _rideData?['customerName'] ?? 'زبون';
    final customerPhone = _rideData?['customerPhone'] ?? '';
    final fare = _rideData?['fare']?.toDouble() ?? 0.0;
    final distance = _rideData?['distance']?.toDouble() ?? 0.0;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _rideData?['pickupLocation'] != null
                  ? LatLng(
                      (_rideData!['pickupLocation'] as GeoPoint).latitude,
                      (_rideData!['pickupLocation'] as GeoPoint).longitude,
                    )
                  : const LatLng(18.0735, -15.9582),
              zoom: 14,
            ),
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Top Bar
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
                gradient: AppColors.secondaryGradient,
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
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'رحلة مفتوحة من زبون',
                          style: AppTextStyles.arabicTitle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_open_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'رحلة مفتوحة',
                                style: AppTextStyles.arabicBodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Info Card
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
                  children: [
                    // Customer Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.secondary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: AppColors.secondaryGradient,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: AppTextStyles.arabicBody.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  customerPhone,
                                  style: AppTextStyles.arabicBodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'زبون',
                              style: AppTextStyles.arabicBodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ride Details
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.attach_money_rounded,
                            label: 'السعر',
                            value: '${fare.toStringAsFixed(2)} MRU',
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.route_rounded,
                            label: 'المسافة',
                            value: '${distance.toStringAsFixed(2)} كم',
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Locations
                    _buildLocationRow(
                      icon: Icons.my_location_rounded,
                      iconColor: AppColors.success,
                      label: 'من',
                      value: pickupAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildLocationRow(
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.error,
                      label: 'إلى',
                      value: dropoffAddress,
                    ),
                    const SizedBox(height: 24),

                    // Accept Button
                    ElevatedButton.icon(
                      onPressed: _isAccepting ? null : _acceptRide,
                      icon: _isAccepting
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
                        _isAccepting ? 'جاري القبول...' : 'قبول الرحلة',
                        style: AppTextStyles.arabicTitle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
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

  Widget _buildInfoCard({
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
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.arabicBody.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.arabicBodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
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
              Text(
                value,
                style: AppTextStyles.arabicBody.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
