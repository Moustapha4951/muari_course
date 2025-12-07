import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rimapp_admin/utils/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'utils/sharedpreferences_helper.dart';
import 'firebase_options.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Check if user is already logged in
    final isLoggedIn = await SharedPreferencesHelper.isLoggedIn();
    final adminData = await SharedPreferencesHelper.getAdminData();

    runApp(MyApp(isLoggedIn: isLoggedIn, adminId: adminData['adminId']));
  } catch (e) {
    debugPrint('Error in main: $e');
    runApp(const MyApp(isLoggedIn: false, adminId: null));
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? adminId;

  const MyApp({super.key, required this.isLoggedIn, this.adminId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muari Course - الإدارة',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
      ],
      locale: const Locale('ar', ''),
      theme: AppTheme.lightTheme,
      home: isLoggedIn && adminId != null
          ? const MainScreen()
          : const LoginScreen(),
      routes: {},
    );
  }
}
