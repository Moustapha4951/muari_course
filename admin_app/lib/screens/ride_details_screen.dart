import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../models/price.dart';

class RideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;

  const RideDetailsScreen({
    super.key,
    required this.rideData,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  // Controllers
  final TextEditingController _fareController = TextEditingController();
  final TextEditingController _cancelReasonController = TextEditingController();
  final TextEditingController _compensationAmountController = TextEditingController();
  GoogleMapController? _mapController;

  // Stream subscriptions
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;
  Timer? _rideTimer;

  // State variables
  bool _isLoading = true;
  bool _isEditingFare = false;
  bool _isUpdatingFare = false;
  bool _shouldCompensateDriver = false;
  String? _error;

  // Ride data
  late Map<String, dynamic> _rideData;
  bool _isOpenRide = false;
  DateTime? _startTime;
  
  // Map state
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _driverLocation;
  LatLng? _customerLocation;
  
  // Ride metrics
  double _currentDistance = 0.0;
  Duration _rideTime = Duration.zero;
  double _currentFare = 0.0;

  @override
  void initState() {
    super.initState();
    _rideData = Map<String, dynamic>.from(widget.rideData);
    _isOpenRide = _rideData['isOpenRide'] == true;
    _initializeScreen();
  }

  @override
  void dispose() {
    _fareController.dispose();
    _cancelReasonController.dispose();
    _compensationAmountController.dispose();
    _rideSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _rideTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    try {
      _setupRideSubscription();
      await _loadRideData();
      _updateRideDetails();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupRideSubscription() {
    final rideId = _rideData['id'];
    if (rideId == null) return;

    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _rideData = snapshot.data()!;
          _rideData['id'] = snapshot.id;
          _updateRideDetails();
        });
      }
    });

    if (_isOpenRide && _rideData['status'] == 'started') {
      _startRideTimer();
    }
  }

  void _startRideTimer() {
    _startTime = (_rideData['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();

    _rideTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        setState(() {
          _rideTime = DateTime.now().difference(_startTime!);
          _updateOpenRideFare();
        });
      }
    });
  }

  void _updateOpenRideFare() {
    if (!_isOpenRide || _rideData['status'] != 'started') return;

    final priceDetails = _rideData['priceDetails'];
    if (priceDetails == null) return;

    final basePrice = (priceDetails['openRideBaseFare'] as num?)?.toDouble() ?? 50.0;
    final pricePerMinute = (priceDetails['openRidePerMinute'] as num?)?.toDouble() ?? 1.0;
    final pricePerKm = (priceDetails['pricePerKm'] as num?)?.toDouble() ?? 20.0;

    final minutes = _rideTime.inMinutes;
    setState(() {
      _currentFare = basePrice + (minutes * pricePerMinute) + (_currentDistance * pricePerKm);
    });
  }

  Future<void> _loadRideData() async {
    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(_rideData['id'])
          .get();

      if (rideDoc.exists) {
        setState(() {
          _rideData = rideDoc.data()!;
          _rideData['id'] = rideDoc.id;
        });

        if (_rideData['status'] == 'started') {
          _startRideTimer();
        }
      }
    } catch (e) {
      throw Exception('خطأ في تحميل بيانات الرحلة: $e');
    }
  }

  void _setupDriverLocationTracking() {
    final driverId = _rideData['driverId'];
    if (driverId == null) return;

    _driverLocationSubscription?.cancel();

    _driverLocationSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final location = snapshot.data()?['location'] as GeoPoint?;
        if (location != null) {
          setState(() {
            _driverLocation = LatLng(location.latitude, location.longitude);
            _updateMarkers();
            if (_customerLocation != null) {
              _updateDistanceTraveled();
            }
          });
        }
      }
    });
  }

  void _updateRideDetails() {
    final status = _rideData['status'] as String?;
    _setupMarkersAndRoute();

    if (status == 'accepted' || status == 'started') {
      _setupDriverLocationTracking();
    }

    if (_isOpenRide && status == 'started') {
      if (_rideTimer == null || !_rideTimer!.isActive) {
        _startRideTimer();
      }
    } else if (_rideTimer != null && _rideTimer!.isActive && status != 'started') {
      _rideTimer?.cancel();
    }
  }

  void _setupMarkersAndRoute() {
    final pickupLocation = _rideData['pickupLocation'] as GeoPoint?;
    final dropoffLocation = _rideData['dropoffLocation'] as GeoPoint?;

    if (pickupLocation != null) {
      _customerLocation = LatLng(pickupLocation.latitude, pickupLocation.longitude);
    }

    _updateMarkers();
  }

  void _updateMarkers() {
    final Set<Marker> markers = {};

    if (_customerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'موقع العميل'),
        ),
      );
    }

    final dropoffLocation = _rideData['dropoffLocation'] as GeoPoint?;
    if (dropoffLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(dropoffLocation.latitude, dropoffLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'وجهة الوصول'),
        ),
      );
    }

    if (_driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'موقع السائق'),
        ),
      );
    }

    setState(() => _markers = markers);
  }

  void _updateDistanceTraveled() {
    if (_driverLocation != null && _customerLocation != null) {
      final distance = _calculateDistance(_driverLocation!, _customerLocation!);
      setState(() => _currentDistance = distance);
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // km
    final double lat1 = start.latitude * (pi / 180);
    final double lon1 = start.longitude * (pi / 180);
    final double lat2 = end.latitude * (pi / 180);
    final double lon2 = end.longitude * (pi / 180);

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  Future<void> _updateFare() async {
    if (_fareController.text.isEmpty) return;

    setState(() => _isUpdatingFare = true);
    try {
      final newFare = double.parse(_fareController.text);
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(_rideData['id'])
          .update({'fare': newFare});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تحديث السعر بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );

      setState(() => _isEditingFare = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isUpdatingFare = false);
    }
  }

  Future<void> _cancelRide() async {
    if (_cancelReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى إدخال سبب الإلغاء'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final rideRef = FirebaseFirestore.instance.collection('rides').doc(_rideData['id']);

      batch.update(rideRef, {
        'status': 'cancelled',
        'cancelReason': _cancelReasonController.text.trim(),
        'cancelledAt': Timestamp.now(),
        'cancelledBy': 'admin',
      });

      if (_shouldCompensateDriver && _rideData['driverId'] != null) {
        final compensationAmount = double.tryParse(_compensationAmountController.text) ?? 0.0;
        if (compensationAmount > 0) {
          final driverRef = FirebaseFirestore.instance.collection('drivers').doc(_rideData['driverId']);
          batch.update(driverRef, {
            'balance': FieldValue.increment(compensationAmount),
          });

          final transactionsRef = FirebaseFirestore.instance.collection('transactions');
          batch.set(transactionsRef.doc(), {
            'driverId': _rideData['driverId'],
            'amount': compensationAmount,
            'type': 'compensation',
            'reason': 'تعويض عن إلغاء الرحلة - ${_cancelReasonController.text.trim()}',
            'date': Timestamp.now(),
            'rideId': _rideData['id'],
          });
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إلغاء الرحلة بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callDriver() async {
    final phone = _rideData['driverPhone'];
    if (phone == null) return;

    final phoneUrl = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(phoneUrl))) {
      await launchUrl(Uri.parse(phoneUrl));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('لا يمكن الاتصال بالرقم'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _callCustomer() async {
    final phone = _rideData['customerPhone'];
    if (phone == null) return;

    final phoneUrl = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(phoneUrl))) {
      await launchUrl(Uri.parse(phoneUrl));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('لا يمكن الاتصال بالرقم'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCancelDialog() {
    final fare = _rideData['fare'] is int
        ? (_rideData['fare'] as int).toDouble()
        : (_rideData['fare'] as num?)?.toDouble() ?? 0.0;

    _compensationAmountController.text = (fare / 2).round().toString();
    _cancelReasonController.clear();
    _shouldCompensateDriver = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إلغاء الرحلة',
          style: AppTextStyles.arabicTitle,
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _cancelReasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'سبب الإلغاء',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_rideData['driverId'] != null) ...[
                StatefulBuilder(
                  builder: (context, setState) => CheckboxListTile(
                    value: _shouldCompensateDriver,
                    onChanged: (value) {
                      setState(() => _shouldCompensateDriver = value ?? false);
                    },
                    title: Text(
                      'تعويض السائق',
                      style: AppTextStyles.arabicBody,
                    ),
                  ),
                ),
                if (_shouldCompensateDriver) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _compensationAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'مبلغ التعويض',
                      suffixText: 'MRU',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AppTextStyles.arabicBody.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRide();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(
              'تأكيد الإلغاء',
              style: AppTextStyles.arabicBody.copyWith(
                color: AppColors.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_customerLocation == null) return const SizedBox();

    return SizedBox(
      height: 200,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _customerLocation!,
          zoom: 15,
        ),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = _rideData['status'] as String? ?? 'unknown';
    final statusInfo = _getStatusInfo(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusInfo.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusInfo.icon, color: statusInfo.color, size: 16),
          const SizedBox(width: 8),
          Text(
            statusInfo.text,
            style: AppTextStyles.arabicBodySmall.copyWith(
              color: statusInfo.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return StatusInfo(
          color: AppColors.warning,
          icon: Icons.access_time,
          text: 'في الانتظار',
        );
      case 'accepted':
        return StatusInfo(
          color: AppColors.info,
          icon: Icons.thumb_up,
          text: 'تم القبول',
        );
      case 'started':
        return StatusInfo(
          color: AppColors.primary,
          icon: Icons.directions_car,
          text: 'جارية',
        );
      case 'completed':
        return StatusInfo(
          color: AppColors.success,
          icon: Icons.check_circle,
          text: 'مكتملة',
        );
      case 'cancelled':
        return StatusInfo(
          color: AppColors.error,
          icon: Icons.cancel,
          text: 'ملغية',
        );
      default:
        return StatusInfo(
          color: AppColors.textSecondary,
          icon: Icons.help,
          text: 'غير معروفة',
        );
    }
  }

  Widget _buildRideInfo() {
    final pickupAddress = _rideData['pickupAddress'] as String? ?? 'غير محدد';
    final dropoffAddress = _rideData['dropoffAddress'] as String? ?? 'غير محدد';
    final fare = _rideData['fare'] is int
        ? (_rideData['fare'] as int).toDouble()
        : (_rideData['fare'] as num?)?.toDouble() ?? 0.0;
    final distance = _rideData['distance'] as double? ?? 0.0;
    final status = _rideData['status'] as String? ?? 'unknown';

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تفاصيل الرحلة',
                  style: AppTextStyles.arabicTitle,
                ),
                _buildStatusBadge(),
              ],
            ),
            const Divider(height: 32),
            _buildInfoRow(
              'نقطة الانطلاق',
              pickupAddress,
              Icons.location_on,
              AppColors.success,
            ),
            if (!_isOpenRide) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                'الوجهة',
                dropoffAddress,
                Icons.location_on,
                AppColors.error,
              ),
            ],
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildInfoRow(
                    'المسافة',
                    '${distance.toStringAsFixed(1)} كم',
                    Icons.straighten,
                    AppColors.info,
                  ),
                ),
                if (_isOpenRide && status == 'started') ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoRow(
                      'الوقت',
                      _formatDuration(_rideTime),
                      Icons.timer,
                      AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    'السعر',
                    '$fare MRU',
                    Icons.payment,
                    AppColors.primary,
                  ),
                ),
                if (status == 'started' || status == 'pending') ...[
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isEditingFare = true;
                        _fareController.text = fare.toString();
                      });
                    },
                    icon: const Icon(Icons.edit),
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
            if (_isEditingFare) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fareController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'السعر الجديد',
                        suffixText: 'MRU',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _isUpdatingFare
                      ? const CircularProgressIndicator()
                      : IconButton(
                          onPressed: _updateFare,
                          icon: const Icon(Icons.check),
                          color: AppColors.success,
                        ),
                  IconButton(
                    onPressed: () {
                      setState(() => _isEditingFare = false);
                    },
                    icon: const Icon(Icons.close),
                    color: AppColors.error,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.arabicBodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.arabicBody.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final status = _rideData['status'] as String? ?? 'unknown';
    
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _callCustomer,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(Icons.phone, color: AppColors.primary),
                    label: Text(
                      'اتصال بالعميل',
                      style: AppTextStyles.arabicBody.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                if (_rideData['driverId'] != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _callDriver,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.phone, color: AppColors.primary),
                      label: Text(
                        'اتصال بالسائق',
                        style: AppTextStyles.arabicBody.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (status == 'started' || status == 'pending' || status == 'accepted') ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showCancelDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.cancel),
                label: Text(
                  'إلغاء الرحلة',
                  style: AppTextStyles.arabicBody.copyWith(
                    color: AppColors.surface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تفاصيل الرحلة',
          style: AppTextStyles.arabicTitle.copyWith(color: AppColors.surface),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              children: [
                _buildMap(),
                _buildRideInfo(),
                _buildActions(),
              ],
            ),
    );
  }
}

class StatusInfo {
  final Color color;
  final IconData icon;
  final String text;

  const StatusInfo({
    required this.color,
    required this.icon,
    required this.text,
  });
}
