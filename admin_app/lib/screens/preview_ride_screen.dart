import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_theme.dart';
import '../models/place.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

class PreviewRideScreen extends StatefulWidget {
  final String customerName;
  final String customerPhone;
  final Place pickupLocation;
  final Place? dropoffLocation;
  final bool isOpenRide;

  const PreviewRideScreen({
    Key? key,
    required this.customerName,
    required this.customerPhone,
    required this.pickupLocation,
    this.dropoffLocation,
    required this.isOpenRide,
  }) : super(key: key);

  @override
  _PreviewRideScreenState createState() => _PreviewRideScreenState();
}

class _PreviewRideScreenState extends State<PreviewRideScreen> {
  late TextEditingController pickupController;
  late TextEditingController dropoffController;
  late TextEditingController priceController;
  late TextEditingController distanceController;
  bool isEditing = false;
  bool isLoading = false;
  double? calculatedPrice;
  double? calculatedDistance;
  bool useCalculatedValues = true;

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius of the earth in km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = (sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _calculatePriceAndDistance() async {
    if (widget.isOpenRide || widget.dropoffLocation == null) {
      setState(() {
        calculatedDistance = 0.0;
        calculatedPrice = 0.0;
        if (useCalculatedValues) {
          priceController.text = '0.0';
          distanceController.text = '0.0';
        }
      });
      return;
    }

    // Calculate distance between pickup and dropoff
    final pickup = widget.pickupLocation.location;
    final dropoff = widget.dropoffLocation!.location;

    try {
      // Get the active price configuration from Firestore
      final pricesQuery = await FirebaseFirestore.instance
          .collection('prices')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (pricesQuery.docs.isEmpty) {
        throw Exception('No active price configuration found');
      }

      final priceData = pricesQuery.docs.first.data();
      final minimumFare = (priceData['minimumFare'] ?? 5.0).toDouble();
      final pricePerKm = (priceData['pricePerKm'] ?? 1.0).toDouble();
      final maximumKm = (priceData['maximumKm'] ?? 0.0).toDouble();

      // Calculate straight-line distance
      final distance = _calculateDistance(
        pickup.latitude,
        pickup.longitude,
        dropoff.latitude,
        dropoff.longitude,
      );

      // Calculate price based on distance
      double price;
      if (distance <= maximumKm) {
        price = minimumFare;
      } else {
        price = minimumFare + ((distance - maximumKm) * pricePerKm);
      }

      setState(() {
        calculatedDistance = distance;
        calculatedPrice = price;
        if (useCalculatedValues) {
          priceController.text = price.toStringAsFixed(0);
          distanceController.text = distance.toStringAsFixed(2);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حساب السعر: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    pickupController = TextEditingController(text: widget.pickupLocation.name);
    dropoffController =
        TextEditingController(text: widget.dropoffLocation?.name ?? '');
    priceController = TextEditingController(text: '0.0');
    distanceController = TextEditingController(text: '0.0');
    _calculatePriceAndDistance();

    // Add listeners to detect manual changes
    priceController.addListener(_onPriceChanged);
    distanceController.addListener(_onDistanceChanged);
  }

  void _onPriceChanged() {
    // If user manually changes price, don't use calculated values
    final currentPrice = double.tryParse(priceController.text);
    if (currentPrice != null &&
        calculatedPrice != null &&
        (currentPrice - calculatedPrice!).abs() > 0.1) {
      setState(() {
        useCalculatedValues = false;
      });
    }
  }

  void _onDistanceChanged() {
    // If user manually changes distance, don't use calculated values
    final currentDistance = double.tryParse(distanceController.text);
    if (currentDistance != null &&
        calculatedDistance != null &&
        (currentDistance - calculatedDistance!).abs() > 0.01) {
      setState(() {
        useCalculatedValues = false;
      });
    }
  }

  @override
  void dispose() {
    pickupController.dispose();
    dropoffController.dispose();
    priceController.dispose();
    distanceController.dispose();
    super.dispose();
  }

  Future<void> _saveRide() async {
    // Validate fields
    if (pickupController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال موقع الانطلاق')),
      );
      return;
    }

    if (!widget.isOpenRide) {
      if (dropoffController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال موقع الوصول')),
        );
        return;
      }

      final distance = double.tryParse(distanceController.text);
      if (distance == null || distance <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال مسافة صحيحة')),
        );
        return;
      }

      final price = double.tryParse(priceController.text);
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال سعر صحيح')),
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Get the last index to increment
      final lastRideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .orderBy('index', descending: true)
          .limit(1)
          .get();

      final lastIndex = lastRideDoc.docs.isEmpty
          ? 0
          : lastRideDoc.docs.first.data()['index'] ?? 0;
      final newIndex = lastIndex + 1;

      // Check if client exists or create new one
      String customerId = '';
      final clientQuery = await FirebaseFirestore.instance
          .collection('clients')
          .where('phone', isEqualTo: widget.customerPhone)
          .limit(1)
          .get();

      if (clientQuery.docs.isEmpty) {
        // Create new client
        final clientData = {
          'name': widget.customerName,
          'phone': widget.customerPhone,
          'cityId': widget.pickupLocation.cityId,
          'createdAt': FieldValue.serverTimestamp(),
        };
        final clientDoc = await FirebaseFirestore.instance
            .collection('clients')
            .add(clientData);
        customerId = clientDoc.id;
      } else {
        customerId = clientQuery.docs.first.id;
      }

      // Find nearby drivers (within 5 km of pickup location)
      // Search for both 'online' and 'available' status
      debugPrint('🔵 [AdminRide] Searching for drivers in city: ${widget.pickupLocation.cityId}');
      
      // Get all approved drivers first, then filter by city
      final driversQuery = await FirebaseFirestore.instance
          .collection('drivers')
          .where('isApproved', isEqualTo: true)
          .get();

      debugPrint('🔵 [AdminRide] Total approved drivers: ${driversQuery.docs.length}');

      List<String> nearbyDriverIds = [];
      int onlineCount = 0;
      int withLocationCount = 0;
      int totalInCity = 0;
      
      for (var driverDoc in driversQuery.docs) {
        final driverData = driverDoc.data();
        final driverCity = driverData['city'] as String?;
        final driverStatus = driverData['status'] as String?;
        final driverLocation = driverData['location'] as GeoPoint?;
        
        // Debug: Show driver city
        debugPrint('🔵 [AdminRide] Driver ${driverDoc.id}: city="$driverCity", status=$driverStatus');
        
        // Check if driver is in the same city (case-insensitive)
        if (driverCity == null || 
            driverCity.toLowerCase() != widget.pickupLocation.cityId.toLowerCase()) {
          continue;
        }
        
        totalInCity++;
        
        // Count statuses
        if (driverStatus == 'online') onlineCount++;
        if (driverLocation != null) withLocationCount++;
        
        // Only include online drivers (not busy)
        if (driverStatus != 'online') {
          continue;
        }
        
        if (driverLocation != null) {
          final distance = _calculateDistance(
            widget.pickupLocation.location.latitude,
            widget.pickupLocation.location.longitude,
            driverLocation.latitude,
            driverLocation.longitude,
          );
          
          debugPrint('🔵 [AdminRide] Driver ${driverDoc.id}: status=$driverStatus, distance=${distance.toStringAsFixed(2)}km');
          
          // Include drivers within 1 km
          if (distance <= 1.0) {
            nearbyDriverIds.add(driverDoc.id);
          }
        }
      }

      debugPrint('🟢 [AdminRide] Stats:');
      debugPrint('  - Total drivers in city: $totalInCity');
      debugPrint('  - Online drivers: $onlineCount');
      debugPrint('  - Drivers with location: $withLocationCount');
      debugPrint('  - Nearby drivers (within 1km): ${nearbyDriverIds.length}');

      // Build ride data matching the Ride model structure
      final rideData = {
        'customerName': widget.customerName,
        'customerPhone': null, // Hidden until driver accepts
        'actualCustomerPhone': widget.customerPhone, // Store actual phone for later
        'pickupLocation': GeoPoint(
          widget.pickupLocation.location.latitude,
          widget.pickupLocation.location.longitude,
        ),
        'pickupAddress': pickupController.text.trim(),
        'dropoffLocation': widget.dropoffLocation != null
            ? GeoPoint(
                widget.dropoffLocation!.location.latitude,
                widget.dropoffLocation!.location.longitude,
              )
            : GeoPoint(0, 0),
        'dropoffAddress':
            widget.dropoffLocation != null ? dropoffController.text.trim() : '',
        'distance':
            widget.isOpenRide ? 0.0 : double.parse(distanceController.text),
        'fare': widget.isOpenRide ? 0.0 : double.parse(priceController.text),
        'isOpen': widget.isOpenRide,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'driverId': null,
        'driverName': null,
        'driverPhone': null,
        'startTime': null,
        'endTime': null,
        'customerId': customerId,
        'cityId': widget.pickupLocation.cityId,
        'index': newIndex,
        'isFromCustomerApp': false, // Mark as admin-created ride
        'nearbyDriverIds': nearbyDriverIds, // Only show to nearby drivers
      };

      // Show drivers info dialog
      if (mounted) {
        final shouldContinue = await _showDriversInfoDialog(
          totalInCity: totalInCity,
          onlineCount: onlineCount,
          withLocationCount: withLocationCount,
          nearbyCount: nearbyDriverIds.length,
        );

        if (!shouldContinue) {
          setState(() => isLoading = false);
          return;
        }
      }

      if (nearbyDriverIds.isEmpty) {
        if (mounted) {
          await _showDriversInfoDialog(
            totalInCity: totalInCity,
            onlineCount: onlineCount,
            withLocationCount: withLocationCount,
            nearbyCount: 0,
            isError: true,
          );
        }
        return;
      }

      await FirebaseFirestore.instance.collection('rides').add(rideData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الرحلة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء الرحلة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<bool> _showDriversInfoDialog({
    required int totalInCity,
    required int onlineCount,
    required int withLocationCount,
    required int nearbyCount,
    bool isError = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: !isError,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                color: isError ? AppColors.error : AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isError ? 'لا يوجد سائقون متاحون' : 'معلومات السائقين',
                  style: AppTextStyles.arabicHeadline.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDriverStatRow(
                  'إجمالي السائقين في المدينة',
                  totalInCity,
                  Icons.location_city_rounded,
                  AppColors.secondary,
                ),
                const SizedBox(height: 12),
                _buildDriverStatRow(
                  'السائقون المتصلون',
                  onlineCount,
                  Icons.wifi_rounded,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildDriverStatRow(
                  'السائقون بموقع GPS',
                  withLocationCount,
                  Icons.location_on_rounded,
                  AppColors.warning,
                ),
                const SizedBox(height: 12),
                Divider(color: AppColors.border, thickness: 1),
                const SizedBox(height: 12),
                _buildDriverStatRow(
                  'السائقون القريبون (ضمن 1 كم)',
                  nearbyCount,
                  Icons.near_me_rounded,
                  isError ? AppColors.error : AppColors.success,
                  isHighlight: true,
                ),
                if (isError) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'لا يمكن إنشاء الرحلة بدون سائقين قريبين',
                            style: AppTextStyles.arabicBodySmall.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (isError)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'حسناً',
                  style: AppTextStyles.arabicBody.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else ...[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'إلغاء',
                  style: AppTextStyles.arabicBody.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'متابعة',
                  style: AppTextStyles.arabicBody.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ) ?? false;
  }

  Widget _buildDriverStatRow(
    String label,
    int count,
    IconData icon,
    Color color, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isHighlight ? Border.all(color: color, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.arabicBody.copyWith(
                color: AppColors.textPrimary,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: AppTextStyles.arabicHeadline.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: isHighlight ? 24 : 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    Color? iconColor,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: isEditing,
        keyboardType: keyboardType,
        textDirection: TextDirection.rtl,
        style: AppTextStyles.arabicBody.copyWith(
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: iconColor) : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide(color: AppColors.border),
          ),
          filled: true,
          fillColor: isEditing ? AppColors.surface : AppColors.surfaceVariant,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معلومات الزبون',
                        style: AppTextStyles.arabicBodySmall,
                      ),
                      Text(
                        widget.customerName,
                        style: AppTextStyles.arabicBody.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.customerPhone,
                        style: AppTextStyles.arabicBodySmall.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Pickup location
            _buildTextField(
              pickupController,
              'موقع الانطلاق',
              icon: Icons.my_location,
              iconColor: AppColors.success,
            ),

            // Dropoff location (if not open ride)
            if (!widget.isOpenRide) ...[
              _buildTextField(
                dropoffController,
                'موقع الوصول',
                icon: Icons.location_on,
                iconColor: AppColors.error,
              ),

              // Distance
              _buildTextField(
                distanceController,
                'المسافة (كم)',
                icon: Icons.straighten,
                iconColor: AppColors.info,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                suffixIcon: isEditing
                    ? IconButton(
                        icon: Icon(Icons.refresh, color: AppColors.primary),
                        onPressed: () {
                          setState(() {
                            useCalculatedValues = true;
                          });
                          _calculatePriceAndDistance();
                        },
                        tooltip: 'إعادة الحساب',
                      )
                    : null,
              ),

              // Price
              _buildTextField(
                priceController,
                'السعر (MRU)',
                icon: Icons.attach_money,
                iconColor: AppColors.warning,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                suffixIcon: isEditing
                    ? IconButton(
                        icon: Icon(Icons.refresh, color: AppColors.primary),
                        onPressed: () {
                          setState(() {
                            useCalculatedValues = true;
                          });
                          _calculatePriceAndDistance();
                        },
                        tooltip: 'إعادة الحساب',
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isOpenRide ? 'رحلة مفتوحة' : 'تفاصيل الرحلة',
          style: AppTextStyles.arabicTitle,
        ),
        backgroundColor: AppColors.primary,
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => isEditing = true),
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: isLoading ? null : _saveRide,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: isLoading
                      ? null
                      : () => setState(() => isEditing = false),
                ),
              ],
            ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جاري إنشاء الرحلة...',
                    style: AppTextStyles.arabicBody,
                  ),
                ],
              ),
            )
          : Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Map preview
                    Container(
                      height: 250,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            widget.pickupLocation.location.latitude,
                            widget.pickupLocation.location.longitude,
                          ),
                          zoom: 12,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('pickup'),
                            position: LatLng(
                              widget.pickupLocation.location.latitude,
                              widget.pickupLocation.location.longitude,
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueGreen),
                            infoWindow: InfoWindow(
                              title: 'موقع الانطلاق',
                              snippet: widget.pickupLocation.name,
                            ),
                          ),
                          if (widget.dropoffLocation != null)
                            Marker(
                              markerId: const MarkerId('dropoff'),
                              position: LatLng(
                                widget.dropoffLocation!.location.latitude,
                                widget.dropoffLocation!.location.longitude,
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueRed),
                              infoWindow: InfoWindow(
                                title: 'موقع الوصول',
                                snippet: widget.dropoffLocation!.name,
                              ),
                            ),
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                    ),

                    // Ride information card
                    _buildInfoCard(),

                    const SizedBox(height: 16),

                    // Confirm button
                    ElevatedButton(
                      onPressed: isLoading || isEditing ? null : _saveRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isOpenRide
                            ? AppColors.secondary
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'تأكيد وإنشاء الرحلة',
                            style: AppTextStyles.arabicTitle.copyWith(
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
            ),
    );
  }
}
