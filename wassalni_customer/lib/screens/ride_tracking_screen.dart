import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import 'rate_driver_screen.dart';
import 'dart:async';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;

  const RideTrackingScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  Map<String, dynamic>? _rideData;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
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
      if (!snapshot.exists) return;

      setState(() {
        _rideData = snapshot.data();
        _isLoading = false;
        _updateMarkers();
      });

      // Check if ride is completed or cancelled
      final status = _rideData?['status'];
      if (status == 'completed') {
        // Show rating screen
        Future.delayed(const Duration(seconds: 2), () async {
          if (mounted) {
            final driverId = _rideData?['driverId'];
            final driverName = _rideData?['driverName'];
            
            if (driverId != null && driverName != null) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RateDriverScreen(
                    rideId: widget.rideId,
                    driverId: driverId,
                    driverName: driverName,
                  ),
                ),
              );
            }
            
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        });
      } else if (status == 'cancelled') {
        // Navigate back after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  void _updateMarkers() {
    _markers.clear();
    _polylines.clear();

    final pickupLocation = _rideData?['pickupLocation'] as GeoPoint?;
    final dropoffLocation = _rideData?['dropoffLocation'] as GeoPoint?;
    final driverLocation = _rideData?['driverLocation'] as GeoPoint?;

    // Pickup marker
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

    // Driver marker (if available)
    if (driverLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driverLocation.latitude, driverLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'السائق',
            snippet: _rideData?['driverName'],
          ),
        ),
      );

      // Draw polyline from driver to pickup (if not started)
      final status = _rideData?['status'];
      if (pickupLocation != null && (status == 'accepted' || status == 'on_way')) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_to_pickup'),
            points: [
              LatLng(driverLocation.latitude, driverLocation.longitude),
              LatLng(pickupLocation.latitude, pickupLocation.longitude),
            ],
            color: AppColors.info,
            width: 4,
          ),
        );
      }

      // Draw polyline from driver to dropoff (if started)
      if (dropoffLocation != null && (status == 'started')) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_to_dropoff'),
            points: [
              LatLng(driverLocation.latitude, driverLocation.longitude),
              LatLng(dropoffLocation.latitude, dropoffLocation.longitude),
            ],
            color: AppColors.success,
            width: 4,
          ),
        );
      }
    }

    // Draw polyline from pickup to dropoff (route)
    if (pickupLocation != null && dropoffLocation != null) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            LatLng(pickupLocation.latitude, pickupLocation.longitude),
            LatLng(dropoffLocation.latitude, dropoffLocation.longitude),
          ],
          color: AppColors.primary.withOpacity(0.5),
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }
  }

  Future<void> _callDriver() async {
    final driverPhone = _rideData?['driverPhone'];
    if (driverPhone != null) {
      final uri = Uri.parse('tel:$driverPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إلغاء الرحلة',
          style: AppTextStyles.arabicTitle,
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من إلغاء الرحلة؟',
          style: AppTextStyles.arabicBody,
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('لا', style: AppTextStyles.arabicBody),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('نعم', style: AppTextStyles.arabicBody.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .update({
          'status': 'cancelled',
          'cancelReason': 'ألغى الزبون الرحلة',
          'cancelledBy': 'customer',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الرحلة'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في إلغاء الرحلة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'في انتظار السائق...';
      case 'accepted':
        return 'تم قبول الرحلة';
      case 'on_way':
        return 'السائق في الطريق إليك';
      case 'arrived':
        return 'السائق وصل';
      case 'started':
        return 'الرحلة جارية';
      case 'completed':
        return 'اكتملت الرحلة';
      case 'cancelled':
        return 'تم إلغاء الرحلة';
      default:
        return 'غير معروف';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.info;
      case 'on_way':
        return AppColors.info;
      case 'arrived':
        return AppColors.success;
      case 'started':
        return AppColors.success;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _rideData?['status'];
    final driverName = _rideData?['driverName'];
    final driverPhone = _rideData?['driverPhone'];

    return Scaffold(
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Stack(
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
                  polylines: _polylines,
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
                      color: AppColors.surface,
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
                          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(status).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: _getStatusColor(status),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getStatusText(status),
                                  style: AppTextStyles.arabicBody.copyWith(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
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
                          // Driver Info (if accepted)
                          if (status != 'pending' && driverName != null) ...[
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        driverName,
                                        style: AppTextStyles.arabicTitle.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'السائق',
                                        style: AppTextStyles.arabicBodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (driverPhone != null)
                                  IconButton(
                                    onPressed: _callDriver,
                                    icon: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.phone_rounded,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Divider(color: AppColors.border),
                            const SizedBox(height: 20),
                          ],

                          // Ride Details
                          _buildDetailRow(
                            icon: Icons.my_location_rounded,
                            iconColor: AppColors.success,
                            label: 'من',
                            value: _rideData?['pickupAddress'] ?? '',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            icon: Icons.location_on_rounded,
                            iconColor: AppColors.error,
                            label: 'إلى',
                            value: _rideData?['dropoffAddress'] ?? '',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            icon: Icons.attach_money_rounded,
                            iconColor: AppColors.primary,
                            label: 'السعر',
                            value: '${_rideData?['fare']?.toStringAsFixed(2) ?? '0'} MRU',
                          ),

                          // Cancel Button (only if pending or accepted)
                          if (status == 'pending' || status == 'accepted') ...[
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: _cancelRide,
                              icon: const Icon(Icons.cancel_rounded),
                              label: Text(
                                'إلغاء الرحلة',
                                style: AppTextStyles.arabicBody.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.error, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDetailRow({
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}
