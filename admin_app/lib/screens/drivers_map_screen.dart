import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_details_screen.dart';

class DriversMapScreen extends StatefulWidget {
  final String? focusedDriverId;

  const DriversMapScreen({
    Key? key,
    this.focusedDriverId,
  }) : super(key: key);

  @override
  State<DriversMapScreen> createState() => _DriversMapScreenState();
}

class _DriversMapScreenState extends State<DriversMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableDrivers = [];

  final LatLng _defaultLocation = const LatLng(18.0735, -15.9582);
  BitmapDescriptor? _onlineDriverMarker;
  BitmapDescriptor? _offlineDriverMarker;
  BitmapDescriptor? _focusedDriverMarker;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _createCustomMarkers();
    await _loadAvailableDrivers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _createCustomMarkers() async {
    try {
      _onlineDriverMarker = await _createBeautifulDriverMarker(
        const Color(0xFF00C853), // Green for online
        false,
      );
      _offlineDriverMarker = await _createBeautifulDriverMarker(
        const Color(0xFF9E9E9E), // Gray for offline
        false,
      );
      _focusedDriverMarker = await _createBeautifulDriverMarker(
        const Color(0xFF6C63FF), // Purple for focused
        true,
      );
    } catch (e) {
      debugPrint('خطأ في إنشاء الماركرز: $e');
      _onlineDriverMarker =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      _offlineDriverMarker =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      _focusedDriverMarker =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  Future<BitmapDescriptor> _createBeautifulDriverMarker(
    Color primaryColor,
    bool isHighlighted,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 120.0;
    final center = Offset(size / 2, size / 2);

    // Draw outer glow/shadow
    final glowPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 42, glowPaint);

    // Draw highlight ring if focused
    if (isHighlighted) {
      final highlightPaint = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(center, 44, highlightPaint);
    }

    // Draw white background circle
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 38, bgPaint);

    // Draw gradient circle
    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - 35, center.dy - 35),
        Offset(center.dx + 35, center.dy + 35),
        [primaryColor, primaryColor.withOpacity(0.7)],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 35, gradientPaint);

    // Draw car icon
    final carPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Car body
    final carPath = Path();
    // Main body
    carPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 40, height: 24),
      const Radius.circular(4),
    ));
    // Roof
    carPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 6),
        width: 24,
        height: 12,
      ),
      const Radius.circular(3),
    ));
    canvas.drawPath(carPath, carPaint);

    // Draw wheels
    final wheelPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 12, center.dy + 10), 4, wheelPaint);
    canvas.drawCircle(Offset(center.dx + 12, center.dy + 10), 4, wheelPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 35, borderPaint);

    // Draw direction indicator (small triangle at top)
    final trianglePaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;
    final trianglePath = Path();
    trianglePath.moveTo(center.dx, center.dy - 50);
    trianglePath.lineTo(center.dx - 8, center.dy - 38);
    trianglePath.lineTo(center.dx + 8, center.dy - 38);
    trianglePath.close();
    canvas.drawPath(trianglePath, trianglePaint);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<Uint8List> _createColoredMarker(
      Color mainColor, Color secondaryColor, bool isOnline,
      {bool isHighlighted = false}) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const Size size = Size(150, 150);

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(const Offset(75, 105), 25, shadowPaint);

    final Paint pinBasePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;

    final Path pinPath = Path()
      ..moveTo(75, 120)
      ..quadraticBezierTo(70, 85, 75, 60)
      ..quadraticBezierTo(80, 85, 75, 120);
    canvas.drawPath(pinPath, pinBasePaint);

    final Paint circlePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(75, 60), 40, circlePaint);

    if (isHighlighted) {
      final Paint highlightPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8;
      canvas.drawCircle(const Offset(75, 60), 48, highlightPaint);
    }

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(const Offset(75, 60), 40, borderPaint);

    final Paint innerCirclePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(75, 60), 30, innerCirclePaint);

    final Paint carPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    if (isOnline) {
      final Path carPath = Path()
        ..moveTo(55, 70)
        ..lineTo(95, 70)
        ..lineTo(90, 55)
        ..lineTo(60, 55)
        ..close();
      canvas.drawPath(carPath, carPaint);

      final Paint windowPaint = Paint()
        ..color = Colors.lightBlue[100]!
        ..style = PaintingStyle.fill;
      final Path windowPath = Path()
        ..moveTo(65, 55)
        ..lineTo(85, 55)
        ..lineTo(83, 48)
        ..lineTo(67, 48)
        ..close();
      canvas.drawPath(windowPath, windowPaint);

      canvas.drawCircle(const Offset(65, 70), 6, Paint()..color = Colors.black);
      canvas.drawCircle(const Offset(85, 70), 6, Paint()..color = Colors.black);
      canvas.drawCircle(
          const Offset(65, 70), 4, Paint()..color = Colors.grey[300]!);
      canvas.drawCircle(
          const Offset(85, 70), 4, Paint()..color = Colors.grey[300]!);

      canvas.drawCircle(
          const Offset(100, 45), 8, Paint()..color = Colors.green);
      canvas.drawCircle(
          const Offset(100, 45), 6, Paint()..color = Colors.lightGreen);
    } else {
      final Path carPath = Path()
        ..moveTo(55, 70)
        ..lineTo(95, 70)
        ..lineTo(90, 55)
        ..lineTo(60, 55)
        ..close();
      canvas.drawPath(carPath, Paint()..color = Colors.grey[700]!);

      final Paint windowPaint = Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.fill;
      final Path windowPath = Path()
        ..moveTo(65, 55)
        ..lineTo(85, 55)
        ..lineTo(83, 48)
        ..lineTo(67, 48)
        ..close();
      canvas.drawPath(windowPath, windowPaint);

      canvas.drawCircle(const Offset(65, 70), 6, Paint()..color = Colors.black);
      canvas.drawCircle(const Offset(85, 70), 6, Paint()..color = Colors.black);
      canvas.drawCircle(
          const Offset(65, 70), 4, Paint()..color = Colors.grey[400]!);
      canvas.drawCircle(
          const Offset(85, 70), 4, Paint()..color = Colors.grey[400]!);

      final Paint offlinePaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawLine(
          const Offset(95, 45), const Offset(105, 55), offlinePaint);
      canvas.drawLine(
          const Offset(105, 45), const Offset(95, 55), offlinePaint);
    }

    final Paint shimmerPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(65, 50),
        40,
        [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.0),
        ],
      );
    canvas.drawCircle(const Offset(65, 50), 20, shimmerPaint);

    final ui.Image image = await pictureRecorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      return byteData.buffer.asUint8List();
    } else {
      return Uint8List(0);
    }
  }

  Future<void> _loadAvailableDrivers() async {
    setState(() => _isLoading = true);

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('drivers').get();

      if (mounted) {
        setState(() {
          _availableDrivers = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
      }

      debugPrint('تم تحميل عدد السائقين: ${_availableDrivers.length}');

      for (var driver in _availableDrivers) {
        debugPrint(
            'بيانات السائق: ${driver['name']} - ${driver.keys.join(', ')}');
      }

      _updateMarkers();
    } catch (e) {
      debugPrint('خطأ في تحميل بيانات السائقين: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في تحميل بيانات السائقين: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();

      int driversWithLocation = 0;
      LatLng? focusedDriverLocation;

      for (final driver in _availableDrivers) {
        LatLng? position;

        if (driver.containsKey('currentLocation')) {
          final dynamic location = driver['currentLocation'];
          if (location is GeoPoint) {
            position = LatLng(location.latitude, location.longitude);
            debugPrint('تم العثور على موقع السائق في حقل currentLocation');
          }
        }

        if (position == null && driver.containsKey('location')) {
          final dynamic location = driver['location'];
          if (location is GeoPoint) {
            position = LatLng(location.latitude, location.longitude);
            debugPrint('تم العثور على موقع السائق في حقل location');
          }
        }

        if (position == null &&
            (driver.containsKey('geopoint') ||
                driver.containsKey('geo_point'))) {
          final dynamic geopoint = driver['geopoint'] ?? driver['geo_point'];
          if (geopoint is GeoPoint) {
            position = LatLng(geopoint.latitude, geopoint.longitude);
            debugPrint('تم العثور على موقع السائق في حقل geopoint');
          }
        }

        if (position == null) {
          position = LatLng(
              _defaultLocation.latitude + (0.001 * driversWithLocation),
              _defaultLocation.longitude + (0.001 * driversWithLocation));
          debugPrint('تم استخدام موقع افتراضي للسائق ${driver['name']}');
        }

        driversWithLocation++;

        final bool isOnline = driver['status'] == 'online';
        final bool isFocused = driver['id'] == widget.focusedDriverId;

        if (isFocused) {
          focusedDriverLocation = position;
        }

        final BitmapDescriptor icon = isFocused
            ? (_focusedDriverMarker ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure))
            : (isOnline
                ? (_onlineDriverMarker ??
                    BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen))
                : (_offlineDriverMarker ??
                    BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueViolet)));

        _markers.add(
          Marker(
            markerId: MarkerId(driver['id']),
            position: position,
            icon: icon,
            infoWindow: InfoWindow(
              title: driver['name'] ?? 'سائق',
              snippet: isOnline ? 'متصل الآن' : 'غير متصل',
            ),
            onTap: () => _showDriverActionSheet(driver, position!),
            zIndex: isFocused ? 2.0 : 1.0,
          ),
        );
      }

      debugPrint('تم إضافة $driversWithLocation سائق على الخريطة');

      if (focusedDriverLocation != null && _mapController != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: focusedDriverLocation!,
                zoom: 15,
              ),
            ),
          );
        });
      } else if (_markers.isNotEmpty && _mapController != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _fitAllMarkers();
        });
      }
    });
  }

  void _showDriverActionSheet(Map<String, dynamic> driver, LatLng position) {
    final bool isOnline = driver['status'] == 'online';
    final String driverId = driver['id'];
    final String driverName = driver['name'] ?? 'سائق';
    final String driverPhone = driver['phone'] ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  if (driverPhone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: () async {
                        final url = 'tel:$driverPhone';
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url));
                        }
                      },
                    ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isOnline ? 'متصل' : 'غير متصل',
                            style: TextStyle(
                              color: isOnline ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor:
                                isOnline ? Colors.green : Colors.grey,
                            radius: 5,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2E3F51).withOpacity(0.1),
                    radius: 24,
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF2E3F51),
                      size: 28,
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              _buildDriverActionButton(
                icon: Icons.info_outline,
                label: 'عرض تفاصيل السائق',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToDriverDetails(driverId, driver);
                },
              ),
              _buildDriverActionButton(
                icon: Icons.message_outlined,
                label: 'إرسال إشعار',
                onTap: () {
                  Navigator.pop(context);
                  _showDriverNotificationScreen();
                },
              ),
              _buildDriverActionButton(
                icon: Icons.block,
                label: isOnline ? 'تعليق الحساب' : 'إلغاء تعليق الحساب',
                color: isOnline ? Colors.red : Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _toggleDriverStatus(driver, !isOnline);
                },
              ),
              _buildDriverActionButton(
                icon: Icons.attach_money,
                label: 'إضافة رصيد',
                onTap: () {
                  Navigator.pop(context);
                  _showDriverBalanceManagement();
                },
              ),
              _buildDriverActionButton(
                icon: Icons.history,
                label: 'سجل الرحلات',
                onTap: () {
                  Navigator.pop(context);
                  _showDriverRidesHistory(driver);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF2E3F51),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                icon,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriverNotificationScreen() {
    TextEditingController titleController = TextEditingController();
    TextEditingController messageController = TextEditingController();
    List<String> selectedDrivers = [];
    bool sendToAll = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'إرسال إشعارات للسائقين',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'عنوان الإشعار',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'أدخل عنوان الإشعار',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'محتوى الإشعار',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: messageController,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'أدخل محتوى الإشعار',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'إرسال إلى جميع السائقين',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: sendToAll,
                            activeColor: const Color(0xFF2E3F51),
                            onChanged: (value) {
                              setState(() {
                                sendToAll = value;
                                if (value) {
                                  selectedDrivers.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (!sendToAll) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'اختر السائقين',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          height: 200,
                          child: ListView.builder(
                            itemCount: _availableDrivers.length,
                            itemBuilder: (context, index) {
                              final driver = _availableDrivers[index];
                              final driverId = driver['id'] as String;
                              final isSelected =
                                  selectedDrivers.contains(driverId);

                              return CheckboxListTile(
                                title: Text(
                                  driver['name'] ?? 'بدون اسم',
                                  textAlign: TextAlign.right,
                                ),
                                value: isSelected,
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected!) {
                                      selectedDrivers.add(driverId);
                                    } else {
                                      selectedDrivers.remove(driverId);
                                    }
                                  });
                                },
                                secondary: CircleAvatar(
                                  backgroundColor:
                                      const Color(0xFF2E3F51).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFF2E3F51),
                                  ),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleController.text.isEmpty ||
                          messageController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى ملء جميع الحقول المطلوبة'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      _sendNotificationToDrivers(
                        title: titleController.text,
                        message: messageController.text,
                        sendToAll: sendToAll,
                        selectedDriverIds: selectedDrivers,
                      );

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E3F51),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'إرسال الإشعار',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendNotificationToDrivers({
    required String title,
    required String message,
    required bool sendToAll,
    required List<String> selectedDriverIds,
  }) async {
    try {
      setState(() => _isLoading = true);

      final batch = FirebaseFirestore.instance.batch();
      final List<String> targetDriverIds = sendToAll
          ? _availableDrivers.map((driver) => driver['id'] as String).toList()
          : selectedDriverIds;

      for (final driverId in targetDriverIds) {
        final driverRef =
            FirebaseFirestore.instance.collection('drivers').doc(driverId);
        final driverDoc = await driverRef.get();

        if (driverDoc.exists) {
          final notifications =
              List<dynamic>.from(driverDoc.data()?['notifications'] ?? []);

          notifications.add({
            'title': title,
            'body': message,
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
          });

          batch.update(driverRef, {
            'notifications': notifications,
            'hasUnreadNotifications': true,
          });
        }
      }

      await batch.commit();

      // إرسال إشعار بنجاح التنفيذ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sendToAll
              ? 'تم إرسال الإشعار لجميع السائقين بنجاح'
              : 'تم إرسال الإشعار لـ ${selectedDriverIds.length} سائق بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إرسال الإشعار: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDriverBalanceManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'إدارة أرصدة السائقين',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'البحث عن سائق',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (value) {
                          // يمكنك تنفيذ وظيفة البحث هنا
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _availableDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = _availableDrivers[index];
                    final balance =
                        (driver['balance'] as num?)?.toDouble() ?? 0.0;
                    final withdrawalMethod =
                        driver['withdrawalMethod'] as String? ?? 'غير محدد';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle),
                              color: Colors.green,
                              onPressed: () => _showAddBalanceDialog(driver),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle),
                              color: Colors.red,
                              onPressed: () => _showRemoveBalanceDialog(driver),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    driver['name'] ?? 'بدون اسم',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'الرصيد الحالي: ${balance.toStringAsFixed(2)} دينار',
                                    style: TextStyle(
                                      color: balance > 0
                                          ? Colors.green
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'طريقة السحب: $withdrawalMethod',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              backgroundColor:
                                  const Color(0xFF2E3F51).withOpacity(0.1),
                              radius: 24,
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF2E3F51),
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBalanceDialog(Map<String, dynamic> driver) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'إضافة رصيد',
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل المبلغ المراد إضافته للسائق',
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (دينار)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال المبلغ'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final amount = double.parse(amountController.text);
                if (amount <= 0) {
                  throw const FormatException('المبلغ يجب أن يكون أكبر من صفر');
                }

                Navigator.pop(context);
                await _updateDriverBalance(
                  driver: driver,
                  amount: amount,
                  note: noteController.text,
                  isAddition: true,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('خطأ في المبلغ: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showRemoveBalanceDialog(Map<String, dynamic> driver) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'سحب رصيد',
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل المبلغ المراد سحبه من السائق',
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (دينار)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (إجباري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال المبلغ'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (noteController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال سبب السحب'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final amount = double.parse(amountController.text);
                if (amount <= 0) {
                  throw const FormatException('المبلغ يجب أن يكون أكبر من صفر');
                }

                final currentBalance =
                    (driver['balance'] as num?)?.toDouble() ?? 0.0;
                if (amount > currentBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('المبلغ يتجاوز الرصيد الحالي للسائق'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _updateDriverBalance(
                  driver: driver,
                  amount: amount,
                  note: noteController.text,
                  isAddition: false,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('خطأ في المبلغ: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('سحب'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDriverBalance({
    required Map<String, dynamic> driver,
    required double amount,
    required String note,
    required bool isAddition,
  }) async {
    try {
      setState(() => _isLoading = true);

      final driverId = driver['id'] as String;
      final driverRef =
          FirebaseFirestore.instance.collection('drivers').doc(driverId);
      final driverDoc = await driverRef.get();

      if (!driverDoc.exists) {
        throw Exception('لم يتم العثور على السائق');
      }

      final currentBalance =
          (driverDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      final newBalance =
          isAddition ? currentBalance + amount : currentBalance - amount;

      // إنشاء سجل للمعاملة
      final transaction = {
        'amount': amount,
        'type': isAddition ? 'إضافة' : 'سحب',
        'note': note,
        'timestamp': FieldValue.serverTimestamp(),
        'adminId': 'admin', // يمكنك استبدالها بمعرف المدير الفعلي
      };

      // تحديث رصيد السائق وإضافة المعاملة
      final List<dynamic> transactions =
          List<dynamic>.from(driverDoc.data()?['transactions'] ?? []);
      transactions.add(transaction);

      await driverRef.update({
        'balance': newBalance,
        'transactions': transactions,
      });

      // إرسال إشعار للسائق
      final notifications =
          List<dynamic>.from(driverDoc.data()?['notifications'] ?? []);

      notifications.add({
        'title': isAddition ? 'تمت إضافة رصيد لحسابك' : 'تم سحب رصيد من حسابك',
        'body': isAddition
            ? 'تمت إضافة $amount دينار إلى رصيدك. ملاحظة: $note'
            : 'تم سحب $amount دينار من رصيدك. ملاحظة: $note',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await driverRef.update({
        'notifications': notifications,
        'hasUnreadNotifications': true,
      });

      // تحديث قائمة السائقين
      await _loadAvailableDrivers();

      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAddition
              ? 'تمت إضافة $amount دينار إلى رصيد ${driver['name']} بنجاح'
              : 'تم سحب $amount دينار من رصيد ${driver['name']} بنجاح'),
          backgroundColor: isAddition ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDriverRidesHistory(Map<String, dynamic> driver) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ هذه الميزة قريباً'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _navigateToDriverDetails(
      String driverId, Map<String, dynamic> driverData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverDetailsScreen(
          driverId: driverId,
          driverData: driverData,
        ),
      ),
    ).then((_) => _loadAvailableDrivers()); // تحديث البيانات عند العودة
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMarkers();
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    final bounds = _getBounds();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'خريطة السائقين',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E3F51),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableDrivers,
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: 'البحث عن سائق',
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: _showAdminTools,
            tooltip: 'أدوات المدير',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _defaultLocation,
                    zoom: 13,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapToolbarEnabled: true,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                ),
                if (_markers.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.red.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'لا يوجد سائقين متاحين حالياً',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'إحصائيات السائقين',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatIndicator(
                                'السائقون المتصلون',
                                _availableDrivers
                                    .where((d) => d['status'] == 'online')
                                    .length
                                    .toString(),
                                Colors.green,
                              ),
                              _buildStatIndicator(
                                'إجمالي السائقين',
                                _availableDrivers.length.toString(),
                                const Color(0xFF2E3F51),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'sendNotification',
            onPressed: _showBroadcastDialog,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.notifications),
            tooltip: 'إرسال إشعار جماعي',
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'fitMarkers',
            onPressed: _fitAllMarkers,
            backgroundColor: const Color(0xFF2E3F51),
            child: const Icon(Icons.center_focus_strong),
            tooltip: 'عرض جميع السائقين',
          ),
        ],
      ),
    );
  }

  Widget _buildStatIndicator(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  LatLngBounds _getBounds() {
    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      minLat = lat < minLat ? lat : minLat;
      maxLat = lat > maxLat ? lat : maxLat;
      minLng = lng < minLng ? lng : minLng;
      maxLng = lng > maxLng ? lng : maxLng;
    }

    // إضافة هامش صغير
    final latPadding = (maxLat - minLat) * 0.2;
    final lngPadding = (maxLng - minLng) * 0.2;

    return LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  void _showAdminTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'أدوات مدير النظام',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildAdminToolButton(
                  icon: Icons.notifications_active,
                  title: 'إرسال إشعار للسائقين',
                  subtitle: 'إرسال إشعار لجميع السائقين أو سائق محدد',
                  onTap: () {
                    Navigator.pop(context);
                    _showDriverNotificationScreen();
                  },
                ),
                _buildAdminToolButton(
                  icon: Icons.block,
                  title: 'تعليق حسابات سائقين',
                  subtitle: 'إيقاف أو إلغاء تعليق حسابات السائقين',
                  onTap: () {
                    Navigator.pop(context);
                    _showDriversStatusManagement();
                  },
                ),
                _buildAdminToolButton(
                  icon: Icons.map_outlined,
                  title: 'إدارة المناطق',
                  subtitle: 'إدارة المناطق ومناطق الخدمة',
                  onTap: () {
                    Navigator.pop(context);
                    _showZonesManagement();
                  },
                ),
                _buildAdminToolButton(
                  icon: Icons.price_change,
                  title: 'تحديث أسعار النقل',
                  subtitle: 'تعديل أسعار التوصيل للمناطق المختلفة',
                  onTap: () {
                    Navigator.pop(context);
                    _showPriceManagement();
                  },
                ),
                _buildAdminToolButton(
                  icon: Icons.assignment,
                  title: 'تقارير وإحصائيات',
                  subtitle: 'عرض تقارير مفصلة عن نشاط السائقين',
                  onTap: () {
                    Navigator.pop(context);
                    _showReportsScreen();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminToolButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E3F51).withOpacity(0.1),
          child: Icon(
            icon,
            color: const Color(0xFF2E3F51),
          ),
        ),
        title: Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          textAlign: TextAlign.right,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  final _searchController = TextEditingController();
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'بحث عن سائق',
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'اسم السائق أو رقم الهاتف',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _searchDrivers(_searchController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E3F51),
            ),
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }

  void _searchDrivers(String query) {
    if (query.isEmpty) return;

    final filteredDrivers = _availableDrivers.where((driver) {
      final name = driver['name']?.toString().toLowerCase() ?? '';
      final phone = driver['phone']?.toString() ?? '';
      return name.contains(query.toLowerCase()) || phone.contains(query);
    }).toList();

    if (filteredDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على أي سائق'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'نتائج البحث',
          textAlign: TextAlign.right,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filteredDrivers.length,
            itemBuilder: (context, index) {
              final driver = filteredDrivers[index];
              return ListTile(
                title: Text(
                  driver['name'] ?? 'بدون اسم',
                  textAlign: TextAlign.right,
                ),
                subtitle: Text(
                  driver['phone'] ?? 'بدون رقم',
                  textAlign: TextAlign.right,
                ),
                trailing: CircleAvatar(
                  backgroundColor:
                      driver['status'] == 'online' ? Colors.green : Colors.grey,
                  radius: 5,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _focusOnDriver(driver);
                },
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E3F51),
            ),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _focusOnDriver(Map<String, dynamic> driver) {
    LatLng? position;

    if (driver.containsKey('currentLocation')) {
      final dynamic location = driver['currentLocation'];
      if (location is GeoPoint) {
        position = LatLng(location.latitude, location.longitude);
      }
    } else if (driver.containsKey('location')) {
      final dynamic location = driver['location'];
      if (location is GeoPoint) {
        position = LatLng(location.latitude, location.longitude);
      }
    }

    if (position != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 16,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تحديد موقع السائق'),
        ),
      );
    }
  }

  final _notificationTitleController = TextEditingController();
  final _notificationBodyController = TextEditingController();
  void _showBroadcastDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'إرسال إشعار للسائقين',
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _notificationTitleController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'عنوان الإشعار',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notificationBodyController,
              textAlign: TextAlign.right,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'نص الإشعار',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'اختر المستلمين',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendNotification(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('السائقين المتصلين'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendNotification(false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E3F51),
                  ),
                  child: const Text('جميع السائقين'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _notificationTitleController.clear();
              _notificationBodyController.clear();
              Navigator.pop(context);
            },
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _sendNotification(bool onlineOnly) {
    final title = _notificationTitleController.text.trim();
    final body = _notificationBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول'),
        ),
      );
      return;
    }

    final targetDrivers = onlineOnly
        ? _availableDrivers.where((d) => d['status'] == 'online').toList()
        : _availableDrivers;

    if (targetDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد سائقين لإرسال الإشعار لهم'),
        ),
      );
      return;
    }

    for (var driver in targetDrivers) {
      try {
        final notifications = driver['notifications'] ?? [];
        notifications.add({
          'title': title,
          'body': body,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });

        FirebaseFirestore.instance
            .collection('drivers')
            .doc(driver['id'])
            .update({
          'notifications': notifications,
          'hasUnreadNotifications': true,
        });
      } catch (e) {
        debugPrint('خطأ في إرسال الإشعار للسائق ${driver['name']}: $e');
      }
    }

    _notificationTitleController.clear();
    _notificationBodyController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم إرسال الإشعار بنجاح إلى ${targetDrivers.length} سائق',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showDriversStatusManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'إدارة حالة السائقين',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              textAlign: TextAlign.right,
                              decoration: InputDecoration(
                                hintText: 'البحث عن سائق',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: (value) {},
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E3F51),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.filter_list,
                                color: Colors.white,
                              ),
                              onSelected: (value) {},
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'all',
                                  child: Text('جميع السائقين'),
                                ),
                                const PopupMenuItem(
                                  value: 'online',
                                  child: Text('المتصلين فقط'),
                                ),
                                const PopupMenuItem(
                                  value: 'offline',
                                  child: Text('غير المتصلين فقط'),
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
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _availableDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = _availableDrivers[index];
                    final isOnline = driver['status'] == 'online';
                    final isActive = driver['isActive'] == true;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isActive
                              ? (isOnline ? Colors.green : Colors.grey)
                              : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Switch(
                              value: isActive,
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.red,
                              onChanged: (value) {
                                _updateDriverActiveStatus(driver, value);
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? (isOnline
                                                  ? Colors.green
                                                  : Colors.grey)
                                              : Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isActive
                                              ? (isOnline ? 'متصل' : 'غير متصل')
                                              : 'معلق',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        driver['name'] ?? 'بدون اسم',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'رقم الهاتف: ${driver['phone'] ?? 'غير متوفر'}',
                                    textAlign: TextAlign.right,
                                  ),
                                  if (driver['completedRides'] != null)
                                    Text(
                                      'عدد الرحلات: ${driver['completedRides'] is List ? driver['completedRides'].length : 0}',
                                      textAlign: TextAlign.right,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              backgroundColor:
                                  const Color(0xFF2E3F51).withOpacity(0.1),
                              radius: 24,
                              child: Icon(
                                Icons.person,
                                color: isActive
                                    ? (isOnline ? Colors.green : Colors.grey)
                                    : Colors.red,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _activateAllDrivers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('تفعيل الكل'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _deactivateAllDrivers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.block),
                        label: const Text('تعليق الكل'),
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

  Future<void> _updateDriverActiveStatus(
      Map<String, dynamic> driver, bool isActive) async {
    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driver['id'])
          .update({
        'isActive': isActive,
        'status': isActive ? 'online' : 'offline',
      });

      final notifications = driver['notifications'] ?? [];
      notifications.add({
        'title': isActive ? 'تم تفعيل حسابك' : 'تم تعليق حسابك',
        'body': isActive
            ? 'تم تفعيل حسابك بنجاح. يمكنك الآن قبول الطلبات.'
            : 'تم تعليق حسابك مؤقتًا. يرجى التواصل مع الإدارة.',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driver['id'])
          .update({
        'notifications': notifications,
        'hasUnreadNotifications': true,
      });

      await _loadAvailableDrivers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive
              ? 'تم تفعيل حساب ${driver['name']} بنجاح'
              : 'تم تعليق حساب ${driver['name']} بنجاح'),
          backgroundColor: isActive ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _activateAllDrivers() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تفعيل جميع السائقين',
          textAlign: TextAlign.right,
        ),
        content: const Text(
          'هل أنت متأكد من تفعيل جميع حسابات السائقين؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                setState(() => _isLoading = true);

                final batch = FirebaseFirestore.instance.batch();

                for (final driver in _availableDrivers) {
                  final driverRef = FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(driver['id']);

                  batch.update(driverRef, {
                    'isActive': true,
                    'status': 'online',
                  });
                }

                await batch.commit();

                await _loadAvailableDrivers();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تفعيل جميع حسابات السائقين بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('تفعيل الكل'),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateAllDrivers() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تعليق جميع السائقين',
          textAlign: TextAlign.right,
        ),
        content: const Text(
          'هل أنت متأكد من تعليق جميع حسابات السائقين؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                setState(() => _isLoading = true);

                final batch = FirebaseFirestore.instance.batch();

                for (final driver in _availableDrivers) {
                  final driverRef = FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(driver['id']);

                  batch.update(driverRef, {
                    'isActive': false,
                    'status': 'offline',
                  });
                }

                await batch.commit();

                await _loadAvailableDrivers();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تعليق جميع حسابات السائقين بنجاح'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('تعليق الكل'),
          ),
        ],
      ),
    );
  }

  void _showZonesManagement() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ هذه الميزة قريباً'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showPriceManagement() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ هذه الميزة قريباً'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showReportsScreen() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ هذه الميزة قريباً'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _toggleDriverStatus(Map<String, dynamic> driver, bool setToOnline) {
    _updateDriverActiveStatus(driver, setToOnline);
  }
}
