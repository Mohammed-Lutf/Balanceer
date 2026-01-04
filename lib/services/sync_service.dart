import 'dart:async';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';
import '../models/expense_model.dart';
import '../models/budget_model.dart';

/// Sync Service - Handles synchronization between local and cloud storage
class SyncService {
  final ConnectivityService _connectivity;
  final LocalStorageService _localStorage;
  final SupabaseService _supabase;
  
  StreamSubscription? _connectionSubscription;
  bool _isSyncing = false;
  
  SyncService({
    required ConnectivityService connectivity,
    required LocalStorageService localStorage,
    required SupabaseService supabase,
  })  : _connectivity = connectivity,
        _localStorage = localStorage,
        _supabase = supabase {
    _init();
  }
  
  void _init() {
    _connectionSubscription = _connectivity.connectionStream.listen((isConnected) {
      if (isConnected) {
        syncAll();
      }
    });
  }
  
  /// Sync all unsynced data when connection is available
  Future<void> syncAll() async {
    if (_isSyncing) return;
    if (!_connectivity.isConnected) return;
    
    final user = _supabase.currentUser;
    if (user == null || user.id.startsWith('guest_')) return;
    
    _isSyncing = true;
    
    try {
      await _syncExpenses(user.id);
      await _syncBudgets(user.id);
    } catch (e) {
      // Log error but don't throw
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  Future<void> _syncExpenses(String userId) async {
    // Get unsynced expenses
    final unsyncedExpenses = await _localStorage.getUnsyncedExpenses(userId);
    
    if (unsyncedExpenses.isNotEmpty) {
      // Upload to Supabase
      await _supabase.upsertExpenses(unsyncedExpenses);
      
      // Mark as synced locally
      for (final expense in unsyncedExpenses) {
        await _localStorage.markExpenseAsSynced(expense.id);
      }
    }
    
    // Download from Supabase and merge
    final cloudExpenses = await _supabase.getExpenses(userId);
    for (final expense in cloudExpenses) {
      await _localStorage.insertExpense(expense.copyWith(isSynced: true));
    }
  }
  
  Future<void> _syncBudgets(String userId) async {
    // Get unsynced budgets
    final unsyncedBudgets = await _localStorage.getUnsyncedBudgets(userId);
    
    if (unsyncedBudgets.isNotEmpty) {
      // Upload to Supabase
      await _supabase.upsertBudgets(unsyncedBudgets);
      
      // Mark as synced locally
      for (final budget in unsyncedBudgets) {
        await _localStorage.markBudgetAsSynced(budget.id);
      }
    }
    
    // Download from Supabase (for current month)
    final now = DateTime.now();
    final cloudBudgets = await _supabase.getBudgets(userId, now.month, now.year);
    for (final budget in cloudBudgets) {
      await _localStorage.insertBudget(budget.copyWith(isSynced: true));
    }
  }
  
  // ==================== EXPENSE OPERATIONS ====================
  
  Future<void> addExpense(ExpenseModel expense) async {
    // Always save locally first
    await _localStorage.insertExpense(expense);
    
    // If connected, sync immediately
    if (_connectivity.isConnected) {
      try {
        await _supabase.insertExpense(expense);
        await _localStorage.markExpenseAsSynced(expense.id);
      } catch (e) {
        print('Failed to sync expense: $e');
      }
    }
  }
  
  Future<List<ExpenseModel>> getExpenses(String userId) async {
    return await _localStorage.getExpenses(userId);
  }
  
  Future<List<ExpenseModel>> getExpensesByMonth(
    String userId,
    int month,
    int year,
  ) async {
    return await _localStorage.getExpensesByMonth(userId, month, year);
  }
  
  Future<void> deleteExpense(String id) async {
    await _localStorage.deleteExpense(id);
    
    if (_connectivity.isConnected) {
      try {
        await _supabase.deleteExpense(id);
      } catch (e) {
        print('Failed to delete expense from cloud: $e');
      }
    }
  }
  
  // ==================== BUDGET OPERATIONS ====================
  
  Future<void> addBudget(BudgetModel budget) async {
    await _localStorage.insertBudget(budget);
    
    if (_connectivity.isConnected) {
      try {
        await _supabase.insertBudget(budget);
        await _localStorage.markBudgetAsSynced(budget.id);
      } catch (e) {
        print('Failed to sync budget: $e');
      }
    }
  }
  
  Future<List<BudgetModel>> getBudgets(String userId, int month, int year) async {
    return await _localStorage.getBudgets(userId, month, year);
  }
  
  Future<void> deleteBudget(String id) async {
    await _localStorage.deleteBudget(id);
    
    if (_connectivity.isConnected) {
      try {
        await _supabase.deleteBudget(id);
      } catch (e) {
        print('Failed to delete budget from cloud: $e');
      }
    }
  }
  
  void dispose() {
    _connectionSubscription?.cancel();
  }
}
