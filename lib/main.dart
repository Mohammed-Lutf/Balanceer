import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/theme.dart';
import 'services/supabase_service.dart';
import 'screens/auth/login_screen.dart';

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
  
  runApp(const YouthBudgetApp());
}

class YouthBudgetApp extends StatelessWidget {
  const YouthBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ميزانيتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const LoginScreen(),
    );
  }
}
