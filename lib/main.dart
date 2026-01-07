import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'services/supabase_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/update_password_screen.dart';

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

  // Initialize Notifications
  await NotificationService().init();

  // Check if first run
  final prefs = await SharedPreferences.getInstance();
  final bool showOnboarding = prefs.getBool('onboarding_complete') != true;
  
  // Check for existing session (guest or authenticated user)
  final bool hasSession = await _checkExistingSession();
  
  runApp(YouthBudgetApp(
    showOnboarding: showOnboarding,
    hasSession: hasSession,
  ));
}

/// Check if user has an existing valid session (guest or authenticated)
Future<bool> _checkExistingSession() async {
  const secureStorage = FlutterSecureStorage();
  
  // Check for guest session
  final isGuest = await secureStorage.read(key: 'is_guest') == 'true';
  
  if (isGuest) {
    // Verify guest session exists and is not expired (7 days)
    final localStorage = LocalStorageService();
    final session = await localStorage.getUserSession();
    
    if (session != null) {
      final createdAt = DateTime.tryParse(session['created_at'] as String? ?? '');
      if (createdAt != null) {
        final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
        // Session valid for 7 days
        if (daysSinceCreation <= 7) {
          return true;
        }
      }
    }
    return false;
  }
  
  // Check for Supabase authenticated session
  try {
    final supabaseUser = SupabaseService.client.auth.currentUser;
    return supabaseUser != null;
  } catch (e) {
    return false;
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class YouthBudgetApp extends StatefulWidget {
  final bool showOnboarding;
  final bool hasSession;
  
  const YouthBudgetApp({
    super.key, 
    required this.showOnboarding,
    required this.hasSession,
  });

  @override
  State<YouthBudgetApp> createState() => _YouthBudgetAppState();
}

class _YouthBudgetAppState extends State<YouthBudgetApp> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }
  
  void _setupAuthListener() {
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      
      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const UpdatePasswordScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Initialize services
    final localStorageService = LocalStorageService();
    final supabaseService = SupabaseService();
    final connectivityService = ConnectivityService();
    
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: localStorageService),
        Provider<SupabaseService>.value(value: supabaseService),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<SyncService>(
          create: (_) => SyncService(
            connectivity: connectivityService,
            localStorage: localStorageService,
            supabase: supabaseService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Balanceer',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        locale: const Locale('ar'),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        home: _getInitialScreen(),
      ),
    );
  }
  
  Widget _getInitialScreen() {
    if (widget.showOnboarding) {
      return const OnboardingScreen();
    }
    if (widget.hasSession) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
