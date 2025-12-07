import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;

  const MapScreen({
    Key? key,
    required this.rideData,
    required this.rideId,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;

  @override
  void initState() {
    super.initState();
    _prepareMapData();
    _monitorRideChanges();
  }

  void _prepareMapData() {
    try {
      // Extract pickup location coordinates
      if (widget.rideData.containsKey('pickupLocation')) {
        final dynamic pickupLoc = widget.rideData['pickupLocation'];

        if (pickupLoc is GeoPoint) {
          _pickupLocation = LatLng(pickupLoc.latitude, pickupLoc.longitude);
        } else if (pickupLoc is Map) {
          final double? lat = _getDoubleValue(pickupLoc, 'latitude') ??
              _getDoubleValue(pickupLoc, 'lat') ??
              _getDoubleValue(pickupLoc, '_latitude');

          final double? lng = _getDoubleValue(pickupLoc, 'longitude') ??
              _getDoubleValue(pickupLoc, 'lng') ??
              _getDoubleValue(pickupLoc, '_longitude');

          if (lat != null && lng != null) {
            _pickupLocation = LatLng(lat, lng);
          }
        }
      }

      // Extract dropoff location coordinates
      if (widget.rideData.containsKey('dropoffLocation')) {
        final dynamic dropoffLoc = widget.rideData['dropoffLocation'];

        if (dropoffLoc is GeoPoint) {
          _dropoffLocation = LatLng(dropoffLoc.latitude, dropoffLoc.longitude);
        } else if (dropoffLoc is Map) {
          final double? lat = _getDoubleValue(dropoffLoc, 'latitude') ??
              _getDoubleValue(dropoffLoc, 'lat') ??
              _getDoubleValue(dropoffLoc, '_latitude');

          final double? lng = _getDoubleValue(dropoffLoc, 'longitude') ??
              _getDoubleValue(dropoffLoc, 'lng') ??
              _getDoubleValue(dropoffLoc, '_longitude');

          if (lat != null && lng != null) {
            _dropoffLocation = LatLng(lat, lng);
          }
        }
      }
    } catch (e) {
      debugPrint('Error preparing map data: $e');
    }
  }

  double? _getDoubleValue(Map<dynamic, dynamic> map, String key) {
    if (!map.containsKey(key)) return null;

    final value = map[key];
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  void _monitorRideChanges() {
    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final status = data['status'];
      
      // Update UI based on ride status changes
      if (mounted) {
        setState(() {
          // Refresh markers and polylines if locations changed
          _updateMapMarkers();
          _drawRouteLine();
        });
      }
    });
  }

  void _updateMapMarkers() {
    if (_mapController == null) return;

    setState(() {
      _markers.clear();

      // Add pickup marker
      if (_pickupLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: _pickupLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'نقطة الانطلاق',
              snippet: widget.rideData['pickupAddress'] ?? '',
            ),
          ),
        );
      }

      // Add dropoff marker
      if (_dropoffLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('dropoff'),
            position: _dropoffLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'نقطة الوصول',
              snippet: widget.rideData['dropoffAddress'] ?? '',
            ),
          ),
        );
      }
    });
  }

  void _drawRouteLine() {
    if (_pickupLocation == null || _dropoffLocation == null) {
      return;
    }

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_pickupLocation!, _dropoffLocation!],
          color: AppColors.primary,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true,
        ),
      );
    });
  }

  void _adjustMapCamera() {
    if (_mapController == null) return;

    if (_pickupLocation != null && _dropoffLocation != null) {
      // Adjust camera to show both locations
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _pickupLocation!.latitude < _dropoffLocation!.latitude
              ? _pickupLocation!.latitude
              : _dropoffLocation!.latitude,
          _pickupLocation!.longitude < _dropoffLocation!.longitude
              ? _pickupLocation!.longitude
              : _dropoffLocation!.longitude,
        ),
        northeast: LatLng(
          _pickupLocation!.latitude > _dropoffLocation!.latitude
              ? _pickupLocation!.latitude
              : _dropoffLocation!.latitude,
          _pickupLocation!.longitude > _dropoffLocation!.longitude
              ? _pickupLocation!.longitude
              : _dropoffLocation!.longitude,
        ),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } else if (_pickupLocation != null) {
      // Show pickup location only
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _pickupLocation!,
            zoom: 15,
          ),
        ),
      );
    } else if (_dropoffLocation != null) {
      // Show dropoff location only
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _dropoffLocation!,
            zoom: 15,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'خريطة الرحلة',
          style: AppTextStyles.arabicTitle,
        ),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _pickupLocation == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد بيانات موقع متاحة',
                    style: AppTextStyles.arabicBody,
                  ),
                ],
              ),
            )
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pickupLocation ??
                    const LatLng(18.0735, -15.9582), // Default to Nouakchott
                zoom: 15,
              ),
              markers: _markers,
              polylines: _polylines,
              zoomControlsEnabled: true,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapToolbarEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                setState(() {
                  _mapController = controller;
                });
                _updateMapMarkers();
                _drawRouteLine();
                _adjustMapCamera();
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Center map button
          FloatingActionButton(
            heroTag: 'center_map',
            onPressed: _adjustMapCamera,
            child: const Icon(Icons.my_location),
            backgroundColor: AppColors.primary,
          ),
          const SizedBox(height: 16),
          // Refresh button
          FloatingActionButton(
            heroTag: 'refresh',
            onPressed: () {
              _updateMapMarkers();
              _drawRouteLine();
              _adjustMapCamera();
            },
            child: const Icon(Icons.refresh),
            backgroundColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}