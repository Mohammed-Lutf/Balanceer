import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import 'register_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  
  late final AuthService _authService;
  late final ConnectivityService _connectivity;
  
  @override
  void initState() {
    super.initState();
    _connectivity = ConnectivityService();
    _authService = AuthService(
      supabase: SupabaseService(),
      localStorage: LocalStorageService(),
      connectivity: _connectivity,
    );
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _connectivity.dispose();
    super.dispose();
  }
  
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final result = await _authService.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    
    setState(() => _isLoading = false);
    
    if (result.success) {
      if (mounted) {
        // Sync data from cloud after successful login
        try {
          final syncService = Provider.of<SyncService>(context, listen: false);
          await syncService.syncAll();
        } catch (e) {
          // Sync error shouldn't block navigation
          debugPrint('Sync after login failed: $e');
        }
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInWithGoogle();
    
    setState(() => _isLoading = false);
    
    if (result.success && mounted) {
      // Sync data from cloud after successful Google login
      try {
        final syncService = Provider.of<SyncService>(context, listen: false);
        await syncService.syncAll();
      } catch (e) {
        debugPrint('Sync after Google login failed: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('أهلاً بك ${result.user?.userMetadata?['full_name'] ?? ''} 👋'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  Future<void> _loginAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInAsGuest();
    
    setState(() => _isLoading = false);
    
    if (result.success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.scaffoldBackground,
              Color(0xFF0D0D1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Title
                  _buildHeader(),
                  const SizedBox(height: 48),
                  
                  // Login Form
                  _buildLoginForm(),
                  const SizedBox(height: 24),
                  
                  // Register Link
                  _buildRegisterLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      children: [
        // Skip Button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loginAsGuest,
            icon: const Icon(Iconsax.arrow_circle_left, color: AppTheme.textSecondary),
            label: const Text(
              'تخطي (زائر)',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ).animate().fadeIn(),
        
        const SizedBox(height: 24),

        // App Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: AppTheme.glowShadow,
          ),
          child: const Icon(
            Iconsax.wallet_3,
            size: 50,
            color: Colors.white,
          ),
        ).animate()
          .fadeIn(duration: 600.ms)
          .scale(delay: 200.ms),
        
        const SizedBox(height: 24),
        
        // Title
        Text(
          'ميزانيتي',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate()
          .fadeIn(delay: 300.ms)
          .slideY(begin: 0.3, end: 0),
        
        const SizedBox(height: 8),
        
        Text(
          'إدارة ذكية لميزانيتك الشهرية',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ).animate()
          .fadeIn(delay: 400.ms),
      ],
    );
  }
  
  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassDecoration,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: const Icon(Iconsax.sms, color: AppTheme.primaryColor),
                hintText: 'example@email.com',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال البريد الإلكتروني';
                }
                if (!value.contains('@')) {
                  return 'بريد إلكتروني غير صالح';
                }
                return null;
              },
            ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1, end: 0),
            
            const SizedBox(height: 16),
            
            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Iconsax.lock, color: AppTheme.primaryColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال كلمة المرور';
                }
                if (value.length < 6) {
                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                }
                return null;
              },
            ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1, end: 0),
            
            const SizedBox(height: 24),
            
            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.warning_2, color: AppTheme.accentRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.accentRed),
                      ),
                    ),
                  ],
                ),
              ).animate().shake(),
            
            if (_errorMessage != null) const SizedBox(height: 16),
            
            // Login Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ).animate().fadeIn(delay: 700.ms).scale(delay: 700.ms),
            
            const SizedBox(height: 24),
            
            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('أو', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
              ],
            ).animate().fadeIn(delay: 800.ms),
            
            const SizedBox(height: 24),
            
            // Google Sign In Button
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Since we don't have a guaranteed Google icon asset or icon, using text with color
                    const Text(
                      'G',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto', // Google's font
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'تسجيل الدخول عبر Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 900.ms).scale(delay: 900.ms),
            
            // Offline Notice
            StreamBuilder<bool>(
              stream: _connectivity.connectionStream,
              builder: (context, snapshot) {
                if (snapshot.data == false) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.wifi_square,
                          size: 16,
                          color: AppTheme.accentOrange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'وضع عدم الاتصال',
                          style: TextStyle(
                            color: AppTheme.accentOrange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'ليس لديك حساب؟',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          child: const Text(
            'إنشاء حساب',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms);
  }
}
