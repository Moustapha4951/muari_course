import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/place.dart';
import '../utils/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({Key? key}) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};

  LatLng _selectedLocation = const LatLng(18.0735, -15.9582);
  bool _isLoading = true;
  String _addressText = 'جاري تحديد العنوان...';
  bool _isAddressLoading = false;
  BitmapDescriptor? _customMarkerIcon;

  @override
  void initState() {
    super.initState();
    _createCustomMarker();
    _initializeMap();
  }

  Future<void> _createCustomMarker() async {
    final Uint8List markerIcon =
        await _getBytesFromAsset('assets/images/location_pin.png', 120);
    _customMarkerIcon = BitmapDescriptor.fromBytes(markerIcon);

    if (_customMarkerIcon == null) {
      await _createProgrammaticMarker();
    }
  }

  Future<void> _createProgrammaticMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const size = Size(120, 120);

    final Paint circlePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(60, 50), 40, circlePaint);

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(60, 55), 35, shadowPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(const Offset(60, 50), 38, borderPaint);

    final Paint locationPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(60, 25)
      ..lineTo(40, 55)
      ..quadraticBezierTo(60, 65, 60, 90)
      ..quadraticBezierTo(60, 65, 80, 55)
      ..close();

    canvas.drawPath(path, locationPaint);

    final Paint dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(60, 50), 8, dotPaint);

    final ui.Image image = await pictureRecorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final Uint8List markerBytes = byteData.buffer.asUint8List();
      _customMarkerIcon = BitmapDescriptor.fromBytes(markerBytes);
    } else {
      _customMarkerIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    try {
      ByteData data = await rootBundle.load(path);
      ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: width,
      );
      ui.FrameInfo fi = await codec.getNextFrame();
      ByteData? byteData =
          await fi.image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint('خطأ في تحميل صورة الماركر: $e');
      return Uint8List(0);
    }
  }

  Future<void> _initializeMap() async {
    try {
      _updateMarkerPosition(_selectedLocation);
      _getAddressFromLatLng(_selectedLocation);
    } catch (e) {
      debugPrint('خطأ في تهيئة الخريطة: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateMarkerPosition(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selectedLocation'),
          position: position,
          draggable: true,
          icon: _customMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          onDragEnd: (newPosition) {
            setState(() {
              _selectedLocation = newPosition;
              _getAddressFromLatLng(newPosition);
            });
          },
        ),
      );
      _selectedLocation = position;
    });
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() {
      _isAddressLoading = true;
      _addressText = 'جاري البحث عن العنوان...';
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _addressText = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ]
              .where((element) => element != null && element.isNotEmpty)
              .join(', ');
        });
      } else {
        setState(() => _addressText = 'لم يتم العثور على عنوان');
      }
    } catch (e) {
      debugPrint('خطأ في الحصول على العنوان: $e');
      setState(() => _addressText = 'تعذر الحصول على العنوان');
    } finally {
      setState(() => _isAddressLoading = false);
    }
  }

  void _confirmLocation() {
    final selectedPlace = Place(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'موقع مختار على الخريطة',
      description: _addressText,
      cityId: 'نواكشوط',
      location: GeoPoint(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      ),
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, selectedPlace);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'اختيار موقع على الخريطة',
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
          Container(
            margin: const EdgeInsets.only(left: 8, right: 8),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              onPressed: _confirmLocation,
              tooltip: 'تأكيد الموقع',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController.setMapStyle('''
                [
                  {
                    "elementType": "geometry",
                    "stylers": [{ "color": "#f5f5f5" }]
                  },
                  {
                    "elementType": "labels.text.stroke",
                    "stylers": [{ "color": "#ffffff" }]
                  },
                  {
                    "elementType": "labels.text.fill",
                    "stylers": [{ "color": "#616161" }]
                  },
                  {
                    "featureType": "administrative.locality",
                    "elementType": "labels.text.fill",
                    "stylers": [{ "color": "#2E3F51" }]
                  },
                  {
                    "featureType": "poi",
                    "elementType": "labels.text.fill",
                    "stylers": [{ "color": "#757575" }]
                  },
                  {
                    "featureType": "poi.park",
                    "elementType": "geometry",
                    "stylers": [{ "color": "#c8e6c9" }]
                  },
                  {
                    "featureType": "poi.park",
                    "elementType": "labels.text.fill",
                    "stylers": [{ "color": "#4caf50" }]
                  },
                  {
                    "featureType": "road",
                    "elementType": "geometry",
                    "stylers": [{ "color": "#ffffff" }]
                  },
                  {
                    "featureType": "road.arterial",
                    "elementType": "geometry",
                    "stylers": [{ "color": "#fafafa" }]
                  },
                  {
                    "featureType": "road.highway",
                    "elementType": "geometry",
                    "stylers": [{ "color": "#ffeb3b" }]
                  },
                  {
                    "featureType": "road.highway",
                    "elementType": "geometry.stroke",
                    "stylers": [{ "color": "#fbc02d" }]
                  },
                  {
                    "featureType": "road.highway",
                    "elementType": "labels.text.fill",
                    "stylers": [{ "color": "#f57c00" }]
                  },
                  {
                    "featureType": "transit",
                    "elementType": "geometry",
                    "stylers": [{ "color": "#e0e0e0" }]
                  },
                  {
                    "featureType": "transit.station",
                    "elementType": "labels.text.fill",
                    "stylers": [{ "color": "#2E3F51" }]
                  },
                  {
                    "featureType": "water",
                    "elementType": "geometry",
                    "stylers": [{ "color": "#90caf9" }]
                  },
                  {
                    "featureType": "water",
                    "elementType": "labels.text.fill",
                    "stylers": [{ "color": "#1976d2" }]
                  },
                  {
                    "featureType": "poi.business",
                    "stylers": [{ "visibility": "off" }]
                  },
                  {
                    "featureType": "poi.medical",
                    "elementType": "geometry",
                    "stylers": [{ "color": "#ffcdd2" }]
                  },
                  {
                    "featureType": "poi.school",
                    "elementType": "geometry",
                    "stylers": [{ "color": "#fff9c4" }]
                  }
                ]
              ''');
            },
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onTap: (position) {
              _updateMarkerPosition(position);
              _getAddressFromLatLng(position);
            },
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 15,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'معلومات الموقع',
                    style: AppTextStyles.arabicHeadline.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isAddressLoading
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 150,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.border,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 100,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.border,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _addressText,
                                  style: AppTextStyles.arabicBody.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pin_drop_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الإحداثيات: ${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                            style: AppTextStyles.arabicBodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(
                        'تأكيد هذا الموقع',
                        style: AppTextStyles.arabicTitle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _confirmLocation,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'اضغط على الخريطة أو اسحب المؤشر',
                        style: AppTextStyles.arabicBodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 150,
            right: 16,
            child: Column(
              children: [
                _buildMapButton(
                    Icons.add,
                    () => _mapController.animateCamera(
                          CameraUpdate.zoomIn(),
                        )),
                const SizedBox(height: 8),
                _buildMapButton(
                    Icons.remove,
                    () => _mapController.animateCamera(
                          CameraUpdate.zoomOut(),
                        )),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
