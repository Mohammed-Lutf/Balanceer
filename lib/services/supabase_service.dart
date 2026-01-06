import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/expense_model.dart';
import '../models/budget_model.dart';
import '../models/debt_model.dart';
import '../models/custom_category_model.dart';

/// Supabase Service for cloud operations
class SupabaseService {
  static SupabaseClient? _client;
  
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }
  
  // ==================== AUTH ====================
  
  Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }
  
  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signInWithIdToken({
    required String idToken,
    required String accessToken,
  }) async {
    return await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }
  
  Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  User? get currentUser => client.auth.currentUser;
  
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> sendWelcomeEmail({required String email, required String name}) async {
    try {
      await client.functions.invoke(
        'welcome-email',
        body: {'email': email, 'name': name},
      );
    } catch (e) {
      // Fail silently or log error, don't crash the app flow
      print('Error sending welcome email: $e');
    }
  }
  
  // ==================== EXPENSES ====================
  
  Future<void> insertExpense(ExpenseModel expense) async {
    await client.from('expenses').insert(expense.toJson());
  }
  
  Future<void> upsertExpenses(List<ExpenseModel> expenses) async {
    if (expenses.isEmpty) return;
    await client.from('expenses').upsert(
      expenses.map((e) => e.toJson()).toList(),
    );
  }
  
  Future<List<ExpenseModel>> getExpenses(String userId) async {
    final response = await client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .order('expense_date', ascending: false);
    
    return (response as List)
        .map((e) => ExpenseModel.fromJson(e))
        .toList();
  }
  
  Future<List<ExpenseModel>> getExpensesByMonth(
    String userId,
    int month,
    int year,
  ) async {
    final startDate = DateTime(year, month, 1).toIso8601String().split('T')[0];
    final endDate = DateTime(year, month + 1, 0).toIso8601String().split('T')[0];
    
    final response = await client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .gte('expense_date', startDate)
        .lte('expense_date', endDate)
        .order('expense_date', ascending: false);
    
    return (response as List)
        .map((e) => ExpenseModel.fromJson(e))
        .toList();
  }
  
  Future<void> deleteExpense(String id) async {
    await client.from('expenses').delete().eq('id', id);
  }
  
  // ==================== BUDGETS ====================
  
  Future<void> insertBudget(BudgetModel budget) async {
    await client.from('budgets').upsert(budget.toJson());
  }
  
  Future<void> upsertBudgets(List<BudgetModel> budgets) async {
    if (budgets.isEmpty) return;
    await client.from('budgets').upsert(
      budgets.map((e) => e.toJson()).toList(),
    );
  }
  
  Future<List<BudgetModel>> getBudgets(String userId, int month, int year) async {
    final response = await client
        .from('budgets')
        .select()
        .eq('user_id', userId)
        .eq('month', month)
        .eq('year', year);
    
    return (response as List)
        .map((e) => BudgetModel.fromJson(e))
        .toList();
  }
  
  Future<void> deleteBudget(String id) async {
    await client.from('budgets').delete().eq('id', id);
  }
  
  // ==================== DEBTS ====================
  
  Future<void> insertDebt(DebtModel debt) async {
    await client.from('debts').upsert(debt.toJson());
  }
  
  Future<void> upsertDebts(List<DebtModel> debts) async {
    if (debts.isEmpty) return;
    await client.from('debts').upsert(
      debts.map((e) => e.toJson()).toList(),
    );
  }
  
  Future<List<DebtModel>> getDebts(String userId) async {
    final response = await client
        .from('debts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((e) => DebtModel.fromJson(e))
        .toList();
  }
  
  Future<void> deleteDebt(String id) async {
    await client.from('debts').delete().eq('id', id);
  }
  
  // ==================== CUSTOM CATEGORIES ====================
  
  Future<void> insertCustomCategory(CustomCategoryModel category) async {
    await client.from('custom_categories').upsert(category.toJson());
  }
  
  Future<void> upsertCustomCategories(List<CustomCategoryModel> categories) async {
    if (categories.isEmpty) return;
    await client.from('custom_categories').upsert(
      categories.map((e) => e.toJson()).toList(),
    );
  }
  
  Future<List<CustomCategoryModel>> getCustomCategories(String userId) async {
    final response = await client
        .from('custom_categories')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((e) => CustomCategoryModel.fromJson(e))
        .toList();
  }
  
  Future<void> deleteCustomCategory(String id) async {
    await client.from('custom_categories').delete().eq('id', id);
  }
  
  // ==================== REAL-TIME ====================
  
  RealtimeChannel subscribeToExpenses(
    String userId,
    void Function(List<ExpenseModel>) onData,
  ) {
    return client
        .channel('expenses_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            final expenses = await getExpenses(userId);
            onData(expenses);
          },
        )
        .subscribe();
  }
  
  // ==================== ACCOUNT MANAGMENT ====================

  Future<void> deleteAllData(String userId) async {
    // Delete all user related data from all tables
    try {
      await client.from('expenses').delete().eq('user_id', userId);
      await client.from('budgets').delete().eq('user_id', userId);
      await client.from('debts').delete().eq('user_id', userId);
      await client.from('custom_categories').delete().eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete user data: $e');
    }
  }

  void unsubscribe(RealtimeChannel channel) {
    client.removeChannel(channel);
  }
}
