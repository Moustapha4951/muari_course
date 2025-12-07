import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'drivers_screen.dart';
import 'customers_screen.dart';
import 'rides_screen.dart';
import 'cities_screen.dart';
import '../utils/sharedpreferences_helper.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'places_screen.dart';
import 'prices_screen.dart';
import 'pin_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateToScreen(Widget? screen) {
    Navigator.pop(context);
    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const DriversScreen(),
    const CustomersScreen(),
    const RidesScreen(),
  ];

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          decoration: AppDecorations.cardDecoration,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'تسجيل الخروج',
                style: AppTextStyles.arabicHeadline.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'هل أنت متأكد من تسجيل الخروج؟',
                style: AppTextStyles.arabicBody.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await SharedPreferencesHelper.clearAdminData();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      child: const Text('تأكيد'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        elevation: 0,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 40,
                        color: AppColors.surface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rim App- الإدارة',
                      style: AppTextStyles.arabicTitle.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'لوحة التحكم',
                      style: AppTextStyles.arabicBodySmall.copyWith(
                        color: AppColors.surface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.dashboard_rounded,
              title: 'لوحة التحكم',
              isSelected: _currentIndex == 0,
              onTap: () {
                setState(() => _currentIndex = 0);
                Navigator.pop(context);
              },
            ),
            _buildDrawerItem(
              icon: Icons.location_city_rounded,
              title: 'إدارة المدن',
              onTap: () => _navigateToScreen(const CitiesScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.place_rounded,
              title: 'إدارة الأماكن',
              onTap: () => _navigateToScreen(const PlacesScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.attach_money_rounded,
              title: 'إدارة الأسعار',
              onTap: () => _navigateToScreen(const PricesScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.bar_chart_rounded,
              title: 'الإحصائيات',
              onTap: () => _navigateToScreen(const PinScreen()),
            ),
            const Divider(height: 32),
            _buildDrawerItem(
              icon: Icons.logout_rounded,
              title: 'تسجيل الخروج',
              textColor: AppColors.error,
              iconColor: AppColors.error,
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: const Offset(0, -8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavBarItem(0, Icons.dashboard_rounded, 'الرئيسية'),
                _buildNavBarItem(1, Icons.drive_eta_rounded, 'السائقون'),
                _buildNavBarItem(2, Icons.people_rounded, 'الزبناء'),
                _buildNavBarItem(3, Icons.route_rounded, 'الرحلات'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ??
            (isSelected ? AppColors.primary : AppColors.textSecondary),
        size: 24,
      ),
      title: Text(
        title,
        textAlign: TextAlign.right,
        style: AppTextStyles.arabicBody.copyWith(
          color: textColor ??
              (isSelected ? AppColors.primary : AppColors.textPrimary),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.arabicBodySmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
