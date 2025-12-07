import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../utils/map_style.dart';

class DriverNavigationScreen extends StatefulWidget {
  final GeoPoint pickupLocation;
  final String pickupAddress;
  final String? customerId;
  final String? customerPhone;
  final String rideId;
  final VoidCallback onArrival;

  const DriverNavigationScreen({
    Key? key,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.customerId,
    this.customerPhone,
    required this.rideId,
    required this.onArrival,
  }) : super(key: key);

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  PolylinePoints _polylinePoints = PolylinePoints();
  List<LatLng> _polylineCoordinates = [];
  Timer? _locationTimer;
  String _distanceRemaining = '';
  String _timeRemaining = '';
  double _distanceToDestination = 0.0;
  List<NavigationStep> _navigationSteps = [];
  int _currentStepIndex = 0;
  bool _isNearDestination = false;
  bool _isLoading = true;

  final String _googleApiKey = "AIzaSyB5DmcWHVqCTC-ZxFb7ydeqqkSS-TpFjwc";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: LatLng(position.latitude, position.longitude),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'موقعك الحالي'),
          ),
        );

        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(widget.pickupLocation.latitude,
                widget.pickupLocation.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            infoWindow:
                InfoWindow(title: 'موقع الزبون', snippet: widget.pickupAddress),
          ),
        );
      });

      await _getDirections();
    } catch (e) {
      debugPrint('خطأ في الحصول على الموقع: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (mounted) {
          setState(() {
            _currentPosition = position;

            _markers.removeWhere((marker) => marker.markerId.value == 'driver');
            _markers.add(
              Marker(
                markerId: const MarkerId('driver'),
                position: LatLng(position.latitude, position.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
                infoWindow: const InfoWindow(title: 'موقعك الحالي'),
                rotation: position.heading,
                flat: true,
              ),
            );
          });

          _calculateRemainingDistance();

          if (_distanceToDestination < 0.05) {
            if (!_isNearDestination) {
              setState(() => _isNearDestination = true);
              _showArrivalDialog();
            }
          } else {
            setState(() => _isNearDestination = false);
          }

          if (_shouldRefreshRoute()) {
            await _getDirections();
          }
        }
      } catch (e) {
        debugPrint('خطأ في تتبع الموقع: $e');
      }
    });
  }

  bool _shouldRefreshRoute() {
    if (_polylineCoordinates.isEmpty || _currentPosition == null) return false;

    double minDistance = double.infinity;
    for (var point in _polylineCoordinates) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance > 200;
  }

  void _calculateRemainingDistance() {
    if (_currentPosition == null) return;

    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.pickupLocation.latitude,
      widget.pickupLocation.longitude,
    );

    _distanceToDestination = distance / 1000;

    setState(() {
      if (_distanceToDestination < 1) {
        _distanceRemaining =
            '${(_distanceToDestination * 1000).toStringAsFixed(0)} متر';
      } else {
        _distanceRemaining = '${_distanceToDestination.toStringAsFixed(1)} كم';
      }

      double timeInHours = _distanceToDestination / 30;
      int minutes = (timeInHours * 60).round();

      if (minutes < 1) {
        _timeRemaining = 'أقل من دقيقة';
      } else {
        _timeRemaining = '$minutes دقيقة';
      }
    });
  }

  Future<void> _getDirections() async {
    if (_currentPosition == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            '&destination=${widget.pickupLocation.latitude},${widget.pickupLocation.longitude}'
            '&mode=driving'
            '&language=ar'
            '&key=$_googleApiKey'),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        _parseNavigationSteps(data);

        _drawRouteOnMap(data);

        if (data['routes'].isNotEmpty && data['routes'][0]['legs'].isNotEmpty) {
          final leg = data['routes'][0]['legs'][0];
          setState(() {
            _distanceRemaining = leg['distance']['text'];
            _timeRemaining = leg['duration']['text'];
          });
        }

        _adjustMapCamera();
      } else {
        debugPrint('فشل في جلب المسار: ${data['status']}');
      }
    } catch (e) {
      debugPrint('خطأ في جلب المسار: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _parseNavigationSteps(Map<String, dynamic> data) {
    List<NavigationStep> steps = [];

    if (data['routes'].isNotEmpty &&
        data['routes'][0]['legs'].isNotEmpty &&
        data['routes'][0]['legs'][0]['steps'].isNotEmpty) {
      final rawSteps = data['routes'][0]['legs'][0]['steps'];

      for (var step in rawSteps) {
        steps.add(NavigationStep(
          instruction: step['html_instructions'] ?? '',
          distance: step['distance']['text'] ?? '',
          duration: step['duration']['text'] ?? '',
          maneuver: step['maneuver'] ?? '',
        ));
      }
    }

    setState(() {
      _navigationSteps = steps;
      _currentStepIndex = 0;
    });
  }

  void _drawRouteOnMap(Map<String, dynamic> data) {
    if (data['routes'].isEmpty) return;

    final points = data['routes'][0]['overview_polyline']['points'];
    List<LatLng> polylineCoordinates = [];

    List<PointLatLng> decodedPoints = _polylinePoints.decodePolyline(points);
    for (var point in decodedPoints) {
      polylineCoordinates.add(LatLng(point.latitude, point.longitude));
    }

    setState(() {
      _polylineCoordinates = polylineCoordinates;
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          points: polylineCoordinates,
          width: 5,
        ),
      );
    });
  }

  void _adjustMapCamera() {
    if (_polylineCoordinates.isEmpty || _mapController == null) return;

    double minLat = _polylineCoordinates.first.latitude;
    double maxLat = _polylineCoordinates.first.latitude;
    double minLng = _polylineCoordinates.first.longitude;
    double maxLng = _polylineCoordinates.first.longitude;

    for (var point in _polylineCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        70,
      ),
    );
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.green),
            const SizedBox(width: 10),
            const Text('لقد وصلت!'),
          ],
        ),
        content: const Text(
          'يبدو أنك وصلت إلى موقع الزبون. هل تريد بدء الرحلة؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('ليس بعد'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onArrival();
              Navigator.pop(context); // العودة لشاشة الرحلة
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('نعم، بدء الرحلة'),
          ),
        ],
      ),
    );
  }

  void _callCustomer() {
    if (widget.customerPhone == null) return;

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: widget.customerPhone,
    );
    launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          'المسافة المتبقية: $_distanceRemaining',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.customerPhone != null)
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.white),
              onPressed: _callCustomer,
              tooltip: 'اتصال بالزبون',
            ),
          IconButton(
            icon: const Icon(Icons.wb_sunny),
            tooltip:
                'نصيحة: قم بتفعيل ميزة إبقاء الشاشة مضاءة من إعدادات هاتفك',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'للحفاظ على الشاشة مضاءة أثناء القيادة، يمكنك تفعيل خيار "إبقاء الشاشة مضاءة" من إعدادات هاتفك أو من لوحة الإشعارات',
                    textAlign: TextAlign.right,
                  ),
                  duration: Duration(seconds: 5),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : LatLng(widget.pickupLocation.latitude,
                      widget.pickupLocation.longitude),
              zoom: 15,
            ),
            compassEnabled: true,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) async {
              _mapController = controller;

              await Future.delayed(const Duration(milliseconds: 200));

              try {
                if (Platform.isAndroid) {
                  try {
                    await controller.setMapStyle("[]");
                    await Future.delayed(const Duration(milliseconds: 200));
                  } catch (e) {
                    debugPrint('خطأ في إعادة ضبط نمط الخريطة: $e');
                  }
                }

                await controller.setMapStyle(MapStyle.mapStyle);

                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('خطأ في تهيئة الخريطة: $e');
              }
            },
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 8,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _timeRemaining,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Text(
                              'وقت الوصول المقدر',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _callCustomer,
                          icon: const Icon(Icons.phone),
                          label: const Text('اتصال بالزبون'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    if (_navigationSteps.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.directions, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'الاتجاهات:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: _navigationSteps.length,
                          itemBuilder: (context, index) {
                            final step = _navigationSteps[index];
                            final isCurrentStep = index == _currentStepIndex;

                            return Card(
                              color: isCurrentStep ? Colors.blue.shade50 : null,
                              child: ListTile(
                                leading: _getNavigationIcon(step.maneuver),
                                title: Text(
                                  _parseHtmlInstructions(step.instruction),
                                  style: TextStyle(
                                    fontWeight: isCurrentStep
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle:
                                    Text('${step.distance} • ${step.duration}'),
                                dense: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                      const SizedBox(height: 16),

                    if (_isNearDestination)
                      ElevatedButton.icon(
                        onPressed: () {
                          widget.onArrival();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('وصلت للزبون'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  String _parseHtmlInstructions(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  Widget _getNavigationIcon(String maneuver) {
    IconData iconData;

    switch (maneuver) {
      case 'turn-right':
        iconData = Icons.turn_right;
        break;
      case 'turn-left':
        iconData = Icons.turn_left;
        break;
      case 'roundabout-right':
      case 'roundabout-left':
        iconData = Icons.roundabout_right;
        break;
      case 'uturn-right':
      case 'uturn-left':
        iconData = Icons.u_turn_right;
        break;
      case 'fork-right':
      case 'fork-left':
        iconData = Icons.fork_right;
        break;
      case 'straight':
        iconData = Icons.straight;
        break;
      case 'merge':
        iconData = Icons.merge;
        break;
      case 'ramp-right':
      case 'ramp-left':
        iconData = Icons.ramp_right;
        break;
      default:
        iconData = Icons.arrow_forward;
    }

    return Icon(iconData, color: Colors.blue);
  }
}

class NavigationStep {
  final String instruction;
  final String distance;
  final String duration;
  final String maneuver;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.maneuver,
  });
}
