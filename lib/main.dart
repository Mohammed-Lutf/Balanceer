import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'services/supabase_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.scaffoldBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Initialize date formatting for Arabic
  await initializeDateFormatting('ar', null);
  
  // Initialize Supabase
  await SupabaseService.initialize();

  // Check if first run
  final prefs = await SharedPreferences.getInstance();
  final bool showOnboarding = prefs.getBool('onboarding_complete') != true;
  
  runApp(YouthBudgetApp(showOnboarding: showOnboarding));
}

class YouthBudgetApp extends StatelessWidget {
  final bool showOnboarding;
  
  const YouthBudgetApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanceer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: showOnboarding ? const OnboardingScreen() : const LoginScreen(),
    );
  }
}
