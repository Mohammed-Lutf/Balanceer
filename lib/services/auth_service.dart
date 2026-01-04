import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/expense_model.dart';
import '../models/budget_model.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

/// Auth Service - Handles authentication with offline support
class AuthService {
  final SupabaseService _supabase;
  final LocalStorageService _localStorage;
  final ConnectivityService _connectivity;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  AuthService({
    required SupabaseService supabase,
    required LocalStorageService localStorage,
    required ConnectivityService connectivity,
  })  : _supabase = supabase,
        _localStorage = localStorage,
        _connectivity = connectivity;
  
  User? get currentUser => _supabase.currentUser;
  
  Stream<AuthState> get authStateChanges => _supabase.authStateChanges;
  
  /// Sign up new user
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!_connectivity.isConnected) {
      return AuthResult.error('لا يوجد اتصال بالإنترنت. يرجى الاتصال لإنشاء حساب جديد.');
    }
    
    try {
      final response = await _supabase.signUp(email, password);
      
      if (response.user != null) {
        // Save session locally
        await _localStorage.saveUserSession(
          response.user!.id,
          email,
          displayName,
        );
        
        // Save credentials securely for offline login
        await _secureStorage.write(key: 'email', value: email);
        await _secureStorage.write(key: 'password', value: password);
        
        // Migrate guest data if exists
        await migrateGuestDataToAccount(response.user!.id);
        
        return AuthResult.success(response.user!);
      }
      
      return AuthResult.error('فشل في إنشاء الحساب');
    } on AuthException catch (e) {
      return AuthResult.error(_getArabicError(e.message));
    } catch (e) {
      return AuthResult.error('حدث خطأ غير متوقع');
    }
  }
  
  /// Sign in existing user
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (_connectivity.isConnected) {
      // Online login
      try {
        final response = await _supabase.signIn(email, password);
        
        if (response.user != null) {
          await _localStorage.saveUserSession(
            response.user!.id,
            email,
            null,
          );
          
          await _secureStorage.write(key: 'email', value: email);
          await _secureStorage.write(key: 'password', value: password);
          
          // Migrate guest data if exists
          await migrateGuestDataToAccount(response.user!.id);
          
          return AuthResult.success(response.user!);
        }
        
        return AuthResult.error('فشل في تسجيل الدخول');
      } on AuthException catch (e) {
        return AuthResult.error(_getArabicError(e.message));
      } catch (e) {
        return AuthResult.error('حدث خطأ غير متوقع');
      }
    } else {
      // Offline login - verify against stored credentials
      final storedEmail = await _secureStorage.read(key: 'email');
      final storedPassword = await _secureStorage.read(key: 'password');
      
      if (storedEmail == email && storedPassword == password) {
        final session = await _localStorage.getUserSession();
        if (session != null) {
          return AuthResult.offlineSuccess(
            session['user_id'] as String,
            session['email'] as String,
          );
        }
      }
      
      return AuthResult.error('بيانات الدخول غير صحيحة أو لا توجد جلسة محفوظة');
    }
  }


  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    if (!_connectivity.isConnected) {
      return AuthResult.error('لا يوجد اتصال بالإنترنت');
    }

    try {
      const webClientId = '187480947340-bnmkng158jgb396h9oqq9q6g8g9gm1p1.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('تم إلغاء تسجيل الدخول');
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return AuthResult.error('فشل في الحصول على معرف Google');
      }

      final response = await _supabase.signInWithIdToken(
        idToken: idToken,
        accessToken: accessToken ?? '',
      );

      if (response.user != null) {
        await _localStorage.saveUserSession(
          response.user!.id,
          response.user!.email ?? '',
          response.user!.userMetadata?['full_name'],
        );

        // Send welcome email (fire and forget)
        _supabase.sendWelcomeEmail(
          email: response.user!.email ?? '', 
          name: response.user!.userMetadata?['full_name'] ?? 'User'
        );
        
        // Migrate guest data if exists
        await migrateGuestDataToAccount(response.user!.id);
        
        return AuthResult.success(response.user!);
      }

      return AuthResult.error('فشل في تسجيل الدخول عبر Google');

    } on AuthException catch (e) {
      return AuthResult.error(_getArabicError(e.message));
    } catch (e) {
      return AuthResult.error('حدث خطأ: $e');
    }
  }

  /// Sign in as Guest (Offline only, no sync)
  Future<AuthResult> signInAsGuest() async {
    // Generate a local ID for guest
    final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    
    // Save guest session
    await _localStorage.saveUserSession(
      guestId,
      'guest@local',
      'زائر',
    );
    
    // Mark as guest in secure storage to remember preference
    await _secureStorage.write(key: 'is_guest', value: 'true');
    
    return AuthResult.guest(guestId);
  }
  
  /// Check if current session is a guest session
  Future<bool> isGuestSession() async {
    return await _secureStorage.read(key: 'is_guest') == 'true';
  }
  
  /// Get guest user ID if exists
  Future<String?> getGuestUserId() async {
    final session = await _localStorage.getUserSession();
    final userId = session?['user_id'] as String?;
    if (userId != null && userId.startsWith('guest_')) {
      return userId;
    }
    return null;
  }
  
  /// Migrate guest data to a new authenticated account
  /// Call this after successful login/signup when user was previously a guest
  Future<void> migrateGuestDataToAccount(String newUserId) async {
    final guestId = await getGuestUserId();
    if (guestId == null) return;
    
    try {
      // Get current month for budgets
      final now = DateTime.now();
      
      // Get all guest expenses
      final expenses = await _localStorage.getExpenses(guestId);
      
      // Get all guest budgets for current month
      final budgets = await _localStorage.getBudgets(guestId, now.month, now.year);
      
      // Update expenses with new user ID and mark as unsynced
      for (final expense in expenses) {
        final updatedExpense = ExpenseModel(
          id: expense.id,
          userId: newUserId,
          category: expense.category,
          amount: expense.amount,
          notes: expense.notes,
          expenseDate: expense.expenseDate,
          createdAt: expense.createdAt,
          isSynced: false,
        );
        await _localStorage.insertExpense(updatedExpense);
      }
      
      // Update budgets with new user ID and mark as unsynced
      for (final budget in budgets) {
        final updatedBudget = BudgetModel(
          id: budget.id,
          userId: newUserId,
          category: budget.category,
          amount: budget.amount,
          month: budget.month,
          year: budget.year,
          createdAt: budget.createdAt,
          isSynced: false,
        );
        await _localStorage.insertBudget(updatedBudget);
      }
      
      // Delete old guest data
      for (final expense in expenses) {
        if (expense.userId == guestId) {
          await _localStorage.deleteExpense(expense.id);
        }
      }
      
      // Clear guest flag
      await _secureStorage.delete(key: 'is_guest');
      
    } catch (e) {
      // Log error but don't fail the login process
      print('Error migrating guest data: $e');
    }
  }

  
  /// Sign out
  Future<void> signOut() async {
    // Check if guest
    final isGuest = await _secureStorage.read(key: 'is_guest') == 'true';
    
    if (!isGuest && _connectivity.isConnected) {
      await _supabase.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        // Ignore if not signed in with Google
      }
    }
    
    await _localStorage.clearUserSession();
    await _secureStorage.delete(key: 'email');
    await _secureStorage.delete(key: 'password');
    await _secureStorage.delete(key: 'is_guest');
  }
  
  /// Check if user has saved session
  Future<bool> hasSession() async {
    if (_connectivity.isConnected && currentUser != null) {
      return true;
    }
    
    final session = await _localStorage.getUserSession();
    return session != null;
  }
  
  /// Get user ID (works offline)
  Future<String?> getUserId() async {
    if (currentUser != null) {
      return currentUser!.id;
    }
    
    final session = await _localStorage.getUserSession();
    return session?['user_id'] as String?;
  }
  
  String _getArabicError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (message.contains('Email not confirmed')) {
      return 'يرجى تأكيد البريد الإلكتروني أولاً';
    }
    if (message.contains('User already registered') || 
        message.contains('Identity already exists') ||
        message.contains('Database error saving new user')) {
      return 'هذا البريد الإلكتروني مسجل مسبقاً';
    }
    if (message.contains('Password should be')) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (message.contains('Signups not allowed for this instance')) {
      return 'التسجيل مغلق حالياً';
    }
    return message;
  }
}

/// Auth Result
class AuthResult {
  final bool success;
  final User? user;
  final String? userId;
  final String? email;
  final String? error;
  final bool isOffline;
  final bool isGuest;

  AuthResult._({
    required this.success,
    this.user,
    this.userId,
    this.email,
    this.error,
    this.isOffline = false,
    this.isGuest = false,
  });
  
  factory AuthResult.success(User user) => AuthResult._(
    success: true,
    user: user,
    userId: user.id,
    email: user.email,
  );
  
  factory AuthResult.offlineSuccess(String userId, String email) => AuthResult._(
    success: true,
    userId: userId,
    email: email,
    isOffline: true,
  );

  factory AuthResult.guest(String userId) => AuthResult._(
    success: true,
    userId: userId,
    isGuest: true,
  );
  
  factory AuthResult.error(String message) => AuthResult._(
    success: false,
    error: message,
  );
}
