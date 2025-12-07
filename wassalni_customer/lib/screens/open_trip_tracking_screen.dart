import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../utils/app_theme.dart';

class OpenTripTrackingScreen extends StatefulWidget {
  final String rideId;

  const OpenTripTrackingScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<OpenTripTrackingScreen> createState() => _OpenTripTrackingScreenState();
}

class _OpenTripTrackingScreenState extends State<OpenTripTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  Map<String, dynamic>? _rideData;
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToRideUpdates();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
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
        _isLoading = false;
        _updateMarkers();
      });

      // Check if ride is completed or cancelled
      final status = _rideData?['status'];
      if (status == 'completed' || status == 'cancelled') {
        _showCompletionDialog();
      }
    });
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

    // Driver location marker
    final driverLocation = _rideData?['driverLocation'] as GeoPoint?;
    if (driverLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driverLocation.latitude, driverLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: _rideData?['driverName'] ?? 'السائق',
          ),
        ),
      );

      // Move camera to driver location
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(driverLocation.latitude, driverLocation.longitude),
        ),
      );
    }
  }

  void _showCompletionDialog() {
    final status = _rideData?['status'];
    final totalFare = (_rideData?['currentFare'] ?? 0.0).toDouble();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          status == 'completed' ? 'تم إنهاء الرحلة' : 'تم إلغاء الرحلة',
          style: AppTextStyles.arabicTitle,
        ),
        content: status == 'completed'
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'التكلفة الإجمالية',
                    style: AppTextStyles.arabicBody,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalFare.toStringAsFixed(2)} MRU',
                    style: AppTextStyles.arabicTitle.copyWith(
                      fontSize: 32,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              )
            : Text(
                'تم إلغاء الرحلة',
                style: AppTextStyles.arabicBody,
              ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('حسناً', style: AppTextStyles.arabicBody),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    final status = _rideData?['status'] ?? 'pending';
    final totalDistance = (_rideData?['totalDistance'] ?? 0.0).toDouble();
    final totalTime = (_rideData?['totalTime'] ?? 0.0).toDouble();
    final currentFare = (_rideData?['currentFare'] ?? 0.0).toDouble();
    final isPaused = _rideData?['isPaused'] ?? false;
    final driverName = _rideData?['driverName'] ?? 'في انتظار السائق';

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

          // Top Status Bar
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
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'رحلة مفتوحة',
                              style: AppTextStyles.arabicTitle.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              _getStatusText(status),
                              style: AppTextStyles.arabicBodySmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isPaused)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'متوقف مؤقتاً',
                            style: AppTextStyles.arabicBodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Info Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Driver Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName,
                              style: AppTextStyles.arabicBody.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_rideData?['driverPhone'] != null)
                              Text(
                                _rideData!['driverPhone'],
                                style: AppTextStyles.arabicBodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Meters
                  if (status == 'started' || status == 'completed')
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildMeterCard(
                                icon: Icons.route_rounded,
                                label: 'المسافة',
                                value: '${totalDistance.toStringAsFixed(2)} كم',
                                color: AppColors.info,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMeterCard(
                                icon: Icons.timer_rounded,
                                label: 'الوقت',
                                value: '${totalTime.toStringAsFixed(0)} دقيقة',
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Current Fare
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'التكلفة الحالية',
                                style: AppTextStyles.arabicTitle.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${currentFare.toStringAsFixed(2)} MRU',
                                style: AppTextStyles.arabicTitle.copyWith(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.arabicCaption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.arabicTitle.copyWith(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'في انتظار السائق';
      case 'accepted':
        return 'السائق في الطريق';
      case 'on_way':
        return 'السائق في الطريق إليك';
      case 'arrived':
        return 'السائق وصل';
      case 'started':
        return 'الرحلة جارية';
      case 'completed':
        return 'تم إنهاء الرحلة';
      case 'cancelled':
        return 'تم إلغاء الرحلة';
      default:
        return status;
    }
  }
}
