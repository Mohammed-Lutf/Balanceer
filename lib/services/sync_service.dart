import 'dart:async';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';
import '../models/expense_model.dart';
import '../models/budget_model.dart';
import '../models/debt_model.dart';
import '../models/custom_category_model.dart';

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
      await _syncDebts(user.id);
      await _syncCustomCategories(user.id);
    } catch (e) {
      // Log error but don't throw
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncCustomCategories(String userId) async {
    // Step 1: Process pending deletions first
    final pendingDeletes = await _localStorage.getPendingDeletes('custom_categories');
    for (final recordId in pendingDeletes) {
      try {
        await _supabase.deleteCustomCategory(recordId);
        await _localStorage.removePendingDelete('custom_categories', recordId);
      } catch (e) {
        print('Failed to sync delete for custom category $recordId: $e');
      }
    }
    
    // Step 2: Get unsynced categories and upload
    final unsyncedCategories = await _localStorage.getUnsyncedCustomCategories(userId);
    
    if (unsyncedCategories.isNotEmpty) {
      // Upload to Supabase
      await _supabase.upsertCustomCategories(unsyncedCategories);
      
      // Mark as synced locally
      for (final category in unsyncedCategories) {
        await _localStorage.markCustomCategoryAsSynced(category.id);
      }
    }
    
    // Step 3: Download from Supabase (only items not in pending deletes)
    final remainingPendingDeletes = await _localStorage.getPendingDeletes('custom_categories');
    final cloudCategories = await _supabase.getCustomCategories(userId);
    for (final category in cloudCategories) {
      // Skip if this category is pending deletion
      if (!remainingPendingDeletes.contains(category.id)) {
        await _localStorage.insertCustomCategory(category.copyWith(isSynced: true));
      }
    }
  }

  // ==================== CUSTOM CATEGORY OPERATIONS ====================

  Future<void> addCustomCategory(CustomCategoryModel category) async {
    await _localStorage.insertCustomCategory(category);
    
    if (_connectivity.isConnected) {
      try {
        await _supabase.insertCustomCategory(category);
        await _localStorage.markCustomCategoryAsSynced(category.id);
      } catch (e) {
        print('Failed to sync custom category: $e');
      }
    }
  }

  Future<void> deleteCustomCategory(String id) async {
    await _localStorage.deleteCustomCategory(id);
    
    if (_connectivity.isConnected) {
      try {
        await _supabase.deleteCustomCategory(id);
      } catch (e) {
        await _localStorage.addPendingDelete('custom_categories', id);
        print('Failed to delete custom category from cloud: $e');
      }
    } else {
      await _localStorage.addPendingDelete('custom_categories', id);
    }
  }
  
  Future<List<CustomCategoryModel>> getCustomCategories(String userId) async {
    return await _localStorage.getCustomCategories(userId);
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
    
    // Auto-create missing custom categories from denormalized expense data
    final existingCategories = await _localStorage.getCustomCategories(userId);
    final existingCategoryIds = existingCategories.map((c) => c.id).toSet();
    
    for (final expense in cloudExpenses) {
      await _localStorage.insertExpense(expense.copyWith(isSynced: true));
      
      // Check if this expense has a custom category that doesn't exist locally
      if (expense.customCategoryId != null && 
          !existingCategoryIds.contains(expense.customCategoryId) &&
          expense.customCategoryName != null &&
          expense.customCategoryIcon != null &&
          expense.customCategoryColor != null) {
            
        final newCategory = CustomCategoryModel(
          id: expense.customCategoryId!,
          userId: userId,
          name: expense.customCategoryName!,
          iconName: expense.customCategoryIcon!,
          colorValue: expense.customCategoryColor!,
          createdAt: DateTime.now(), // Approximate
          isSynced: true, // It came from cloud expense, so effectively synced
        );
        
        await _localStorage.insertCustomCategory(newCategory);
        existingCategoryIds.add(expense.customCategoryId!);
      }
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
  
  Future<void> _syncDebts(String userId) async {
    // Step 1: Process pending deletions first
    final pendingDeletes = await _localStorage.getPendingDeletes('debts');
    for (final recordId in pendingDeletes) {
      try {
        await _supabase.deleteDebt(recordId);
        await _localStorage.removePendingDelete('debts', recordId);
      } catch (e) {
        print('Failed to sync delete for debt $recordId: $e');
      }
    }
    
    // Step 2: Get unsynced debts and upload
    final unsyncedDebts = await _localStorage.getUnsyncedDebts(userId);
    
    if (unsyncedDebts.isNotEmpty) {
      // Upload to Supabase
      await _supabase.upsertDebts(unsyncedDebts);
      
      // Mark as synced locally
      for (final debt in unsyncedDebts) {
        await _localStorage.markDebtAsSynced(debt.id);
      }
    }
    
    // Step 3: Download from Supabase (only items not in pending deletes)
    final remainingPendingDeletes = await _localStorage.getPendingDeletes('debts');
    final cloudDebts = await _supabase.getDebts(userId);
    for (final debt in cloudDebts) {
      // Skip if this debt is pending deletion
      if (!remainingPendingDeletes.contains(debt.id)) {
        await _localStorage.insertDebt(debt.copyWith(isSynced: true));
      }
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
  
  Future<void> updateExpense(ExpenseModel expense) async {
    // Always save locally first (insert acts as upsert in SQLite with conflict algorithm)
    await _localStorage.insertExpense(expense);
    
    // If connected, sync immediately
    if (_connectivity.isConnected) {
      try {
        await _supabase.upsertExpenses([expense]);
        await _localStorage.markExpenseAsSynced(expense.id);
      } catch (e) {
        print('Failed to sync updated expense: $e');
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
  
  // ==================== DEBT OPERATIONS ====================
  
  Future<void> addDebt(DebtModel debt) async {
    await _localStorage.insertDebt(debt);
    
    if (_connectivity.isConnected) {
      try {
        await _supabase.insertDebt(debt);
        await _localStorage.markDebtAsSynced(debt.id);
      } catch (e) {
        print('Failed to sync debt: $e');
      }
    }
  }
  
  Future<void> updateDebt(DebtModel debt) async {
    await _localStorage.insertDebt(debt);
    
    if (_connectivity.isConnected) {
      try {
        await _supabase.upsertDebts([debt]);
        await _localStorage.markDebtAsSynced(debt.id);
      } catch (e) {
        print('Failed to sync updated debt: $e');
      }
    }
  }
  
  Future<List<DebtModel>> getDebts(String userId) async {
    return await _localStorage.getDebts(userId);
  }
  
  Future<void> deleteDebt(String id) async {
    // Always delete locally first
    await _localStorage.deleteDebt(id);
    
    if (_connectivity.isConnected) {
      // If connected, delete from cloud immediately
      try {
        await _supabase.deleteDebt(id);
      } catch (e) {
        // If cloud delete fails, add to pending deletes
        await _localStorage.addPendingDelete('debts', id);
        print('Failed to delete debt from cloud, added to pending: $e');
      }
    } else {
      // If offline, add to pending deletes for later sync
      await _localStorage.addPendingDelete('debts', id);
    }
  }
  
  void dispose() {
    _connectionSubscription?.cancel();
  }
}
