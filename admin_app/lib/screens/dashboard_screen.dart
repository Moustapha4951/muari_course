import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rimapp_admin/models/place.dart';
import 'package:rimapp_admin/utils/app_theme.dart';
import 'package:rimapp_admin/screens/search_places_screen.dart';
import 'package:rimapp_admin/screens/preview_ride_screen.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  Place? _pickupLocation;
  Place? _dropoffLocation;
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isSearching = false;
  Timer? _debounce;
  bool _isNewCustomer = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_phoneController.text.length >= 3) {
        _searchCustomers(_phoneController.text);
      } else {
        setState(() {
          _filteredCustomers = [];
          _isSearching = false;
          _isNewCustomer = false;
        });
      }
    });
  }

  Future<void> _searchCustomers(String query) async {
    setState(() => _isSearching = true);
    try {
      // Search in both customers and clients collections
      final customersSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('phone', isGreaterThanOrEqualTo: query)
          .where('phone', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(10)
          .get();

      final clientsSnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('phone', isGreaterThanOrEqualTo: query)
          .where('phone', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(10)
          .get();

      // Combine results from both collections
      final allResults = [
        ...customersSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}),
        ...clientsSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}),
      ];

      setState(() {
        _filteredCustomers = allResults;

        _isNewCustomer = _filteredCustomers.isEmpty ||
            !_filteredCustomers.any((customer) => customer['phone'] == query);
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching customers: $e');
      setState(() => _isSearching = false);
    }
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _phoneController.text = customer['phone'];
      _nameController.text = customer['name'];
      _filteredCustomers = [];
      _isNewCustomer = false;
    });
  }

  Future<void> _navigateToSearchPlaces({bool isPickup = true}) async {
    if (_phoneController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رقم الهاتف واسم الزبون')),
      );
      return;
    }

    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (context) => SearchPlacesScreen(
          customerName: _nameController.text,
          customerPhone: _phoneController.text,
        ),
      ),
    );

    if (place != null) {
      setState(() {
        if (isPickup) {
          _pickupLocation = place;
        } else {
          _dropoffLocation = place;
        }
      });
    }
  }

  void _navigateToRideDetails({required bool isOpenRide}) {
    if (isOpenRide && _pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار موقع الانطلاق')),
      );
      return;
    }

    if (!isOpenRide && (_pickupLocation == null || _dropoffLocation == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار موقعي الانطلاق والوصول')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewRideScreen(
          key: const ValueKey('preview_ride_screen'),
          customerName: _nameController.text,
          customerPhone: _phoneController.text,
          pickupLocation: _pickupLocation!,
          dropoffLocation: isOpenRide ? null : _dropoffLocation,
          isOpenRide: isOpenRide,
        ),
      ),
    ).then((success) {
      if (success == true) {
        setState(() {
          _nameController.clear();
          _phoneController.clear();
          _pickupLocation = null;
          _dropoffLocation = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لوحة التحكم',
          style: AppTextStyles.arabicTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: AppColors.primary),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: AppDecorations.cardDecoration.copyWith(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.05),
                      AppColors.background,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_add_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'رحلة جديدة',
                                  style: AppTextStyles.arabicBodySmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'معلومات الزبون',
                            style: AppTextStyles.arabicHeadline.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        style: AppTextStyles.arabicBody,
                        decoration: InputDecoration(
                          labelText: 'رقم هاتف الزبون',
                          prefixIcon: Icon(Icons.phone_rounded,
                              color: AppColors.primary),
                          suffixIcon: _isSearching
                              ? Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary),
                                  ),
                                )
                              : null,
                          hintText: 'أدخل رقم هاتف الزبون',
                        ),
                      ),
                      if (_filteredCustomers.isNotEmpty || _isNewCustomer)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
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
                              if (_isNewCustomer)
                                ListTile(
                                  onTap: () {
                                    setState(() {
                                      _nameController.text = '';
                                      _filteredCustomers = [];
                                      FocusScope.of(context)
                                          .requestFocus(FocusNode());
                                    });
                                  },
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.person_add_rounded,
                                      color: AppColors.success,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    "زبون جديد",
                                    style: AppTextStyles.arabicBody.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  subtitle: Text(
                                    "الرقم: ${_phoneController.text}",
                                    style:
                                        AppTextStyles.arabicBodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  trailing: Icon(
                                    Icons.add_circle_rounded,
                                    color: AppColors.success,
                                    size: 24,
                                  ),
                                ),
                              ..._filteredCustomers.map((customer) {
                                return ListTile(
                                  onTap: () => _selectCustomer(customer),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    customer['name'] ?? '',
                                    textDirection: TextDirection.rtl,
                                    style: AppTextStyles.arabicBody.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        customer['phone'] ?? '',
                                        textDirection: TextDirection.ltr,
                                        style: AppTextStyles.arabicBodySmall
                                            .copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star_rounded,
                                            color: AppColors.warning,
                                            size: 16,
                                          ),
                                          Text(
                                            ' ${customer['rating']?.toStringAsFixed(1) ?? '5.0'} ',
                                            style: AppTextStyles.arabicCaption
                                                .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            ' | ${customer['ridesCount'] ?? 0} رحلة',
                                            style: AppTextStyles.arabicCaption
                                                .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        textDirection: TextDirection.rtl,
                        style: AppTextStyles.arabicBody,
                        decoration: InputDecoration(
                          labelText: 'اسم الزبون',
                          prefixIcon: Icon(Icons.person_rounded,
                              color: AppColors.primary),
                          hintText: 'أدخل اسم الزبون',
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _navigateToSearchPlaces(isPickup: true),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          'متابعة',
                          style: AppTextStyles.arabicBody.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          elevation: 2,
                          shadowColor: AppColors.primary.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_pickupLocation != null) ...[
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.trip_origin_rounded,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'موقع الانطلاق',
                                      style: AppTextStyles.arabicBodySmall
                                          .copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _pickupLocation!.name,
                                      style: AppTextStyles.arabicBody.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => _navigateToSearchPlaces(isPickup: false),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _dropoffLocation != null
                                  ? AppColors.error.withOpacity(0.1)
                                  : AppColors.textSecondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _dropoffLocation != null
                                    ? AppColors.error.withOpacity(0.2)
                                    : AppColors.textSecondary.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (_dropoffLocation != null
                                            ? AppColors.error
                                            : AppColors.textSecondary)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: _dropoffLocation != null
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _dropoffLocation != null
                                            ? 'موقع الوصول'
                                            : 'اختر موقع الوصول',
                                        style: AppTextStyles.arabicBodySmall
                                            .copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (_dropoffLocation != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _dropoffLocation!.name,
                                          style:
                                              AppTextStyles.arabicBody.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _navigateToRideDetails(isOpenRide: true),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: AppColors.warning,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 2,
                                  shadowColor:
                                      AppColors.warning.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.watch_later_rounded),
                                label: Text(
                                  'رحلة مفتوحة',
                                  style: AppTextStyles.arabicBody.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            if (_dropoffLocation != null) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _navigateToRideDetails(isOpenRide: false),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    elevation: 2,
                                    shadowColor:
                                        AppColors.primary.withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: Text(
                                    'تأكيد',
                                    style: AppTextStyles.arabicBody.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}