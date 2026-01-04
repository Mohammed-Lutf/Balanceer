import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/supabase_service.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _connectivity.dispose();
    super.dispose();
  }
  
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_connectivity.isConnected) {
      setState(() {
        _errorMessage = 'يجب الاتصال بالإنترنت لإنشاء حساب جديد';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final result = await _authService.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
    );
    
    setState(() => _isLoading = false);
    
    if (result.success) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } else {
      setState(() => _errorMessage = result.error);
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
          child: Column(
            children: [
              // Back Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Iconsax.arrow_right_3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Form
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 32),
                        _buildRegisterForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppTheme.successGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Iconsax.user_add,
            size: 40,
            color: Colors.white,
          ),
        ).animate()
          .fadeIn(duration: 500.ms)
          .scale(delay: 200.ms),
        
        const SizedBox(height: 20),
        
        Text(
          'إنشاء حساب جديد',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate()
          .fadeIn(delay: 300.ms),
        
        const SizedBox(height: 8),
        
        Text(
          'ابدأ رحلتك في إدارة ميزانيتك',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ).animate()
          .fadeIn(delay: 400.ms),
      ],
    );
  }
  
  Widget _buildRegisterForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassDecoration,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Iconsax.user, color: AppTheme.primaryColor),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال الاسم';
                }
                return null;
              },
            ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1, end: 0),
            
            const SizedBox(height: 16),
            
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
                if (!value.contains('@') || !value.contains('.')) {
                  return 'بريد إلكتروني غير صالح';
                }
                return null;
              },
            ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1, end: 0),
            
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
            ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.1, end: 0),
            
            const SizedBox(height: 16),
            
            // Confirm Password Field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: const Icon(Iconsax.lock_1, color: AppTheme.primaryColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Iconsax.eye_slash : Iconsax.eye,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى تأكيد كلمة المرور';
                }
                if (value != _passwordController.text) {
                  return 'كلمتا المرور غير متطابقتين';
                }
                return null;
              },
            ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.1, end: 0),
            
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
            
            // Register Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
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
                        'إنشاء حساب',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ).animate().fadeIn(delay: 900.ms).scale(delay: 900.ms),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }
}
