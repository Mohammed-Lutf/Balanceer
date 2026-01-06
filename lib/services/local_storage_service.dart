import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense_model.dart';
import '../models/budget_model.dart';
import '../models/debt_model.dart';
import '../models/custom_category_model.dart';

/// Local Storage Service using SQLite
class LocalStorageService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'youth_budget.db');
    
    return await openDatabase(
      path,
      version: 6, // Incremented for denormalized custom categories (tables merged)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDebtsTable(db);
    }
    if (oldVersion < 3) {
      await _createPendingDeletesTable(db);
    }
    if (oldVersion < 4) {
      await _createCustomCategoriesTable(db);
    }
    if (oldVersion < 5) {
      await _addCustomCategoryIdToExpenses(db);
    }
    if (oldVersion < 6) {
      await _addDenormalizedCategoryFields(db);
    }
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category TEXT NOT NULL,
        custom_category_id TEXT,
        custom_category_name TEXT,
        custom_category_icon TEXT,
        custom_category_color INTEGER,
        amount REAL NOT NULL,
        notes TEXT,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    
    // Budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        UNIQUE(user_id, category, month, year)
      )
    ''');
    
    // User session table
    await db.execute('''
      CREATE TABLE user_session (
        id INTEGER PRIMARY KEY,
        user_id TEXT NOT NULL,
        email TEXT NOT NULL,
        display_name TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Debts table
    await _createDebtsTable(db);
    
    // Pending deletes table
    await _createPendingDeletesTable(db);
    
    // Custom categories table
    await _createCustomCategoriesTable(db);
  }

  Future<void> _createDebtsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        person_name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        debt_date TEXT NOT NULL,
        due_date TEXT,
        paid_date TEXT,
        is_paid INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }
  
  Future<void> _createPendingDeletesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_deletes (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }
  
  // ==================== PENDING DELETES ====================
  
  Future<void> addPendingDelete(String tableName, String recordId) async {
    final db = await database;
    await db.insert(
      'pending_deletes',
      {
        'id': '${tableName}_$recordId',
        'table_name': tableName,
        'record_id': recordId,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<String>> getPendingDeletes(String tableName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pending_deletes',
      where: 'table_name = ?',
      whereArgs: [tableName],
    );
    return maps.map((e) => e['record_id'] as String).toList();
  }
  
  Future<void> removePendingDelete(String tableName, String recordId) async {
    final db = await database;
    await db.delete(
      'pending_deletes',
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
    );
  }
  
  Future<void> _addCustomCategoryIdToExpenses(Database db) async {
    try {
      await db.execute('ALTER TABLE expenses ADD COLUMN custom_category_id TEXT');
    } catch (e) {
      // Column might already exist
      print('Error adding custom_category_id column: $e');
    }
  }

  Future<void> _addDenormalizedCategoryFields(Database db) async {
    try {
      await db.execute('ALTER TABLE expenses ADD COLUMN custom_category_name TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN custom_category_icon TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN custom_category_color INTEGER');
    } catch (e) {
      // Columns might already exist
      print('Error adding denormalized category fields: $e');
    }
  }

  Future<void> clearPendingDeletes(String tableName) async {
    final db = await database;
    await db.delete(
      'pending_deletes',
      where: 'table_name = ?',
      whereArgs: [tableName],
    );
  }
  
  // ==================== CUSTOM CATEGORIES ====================
  
  Future<void> _createCustomCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_categories (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }
  
  Future<void> insertCustomCategory(CustomCategoryModel category) async {
    final db = await database;
    await db.insert(
      'custom_categories',
      category.toLocalJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<CustomCategoryModel>> getCustomCategories(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_categories',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => CustomCategoryModel.fromLocalJson(e)).toList();
  }
  
  Future<List<CustomCategoryModel>> getUnsyncedCustomCategories(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_categories',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return maps.map((e) => CustomCategoryModel.fromLocalJson(e)).toList();
  }
  
  Future<void> markCustomCategoryAsSynced(String id) async {
    final db = await database;
    await db.update(
      'custom_categories',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> deleteCustomCategory(String id) async {
    final db = await database;
    await db.delete(
      'custom_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ==================== EXPENSES ====================
  
  Future<void> insertExpense(ExpenseModel expense) async {
    final db = await database;
    await db.insert(
      'expenses',
      expense.toLocalJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<ExpenseModel>> getExpenses(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'expense_date DESC',
    );
    return maps.map((e) => ExpenseModel.fromLocalJson(e)).toList();
  }
  
  Future<List<ExpenseModel>> getExpensesByMonth(
    String userId,
    int month,
    int year,
  ) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String().split('T')[0];
    final endDate = DateTime(year, month + 1, 0).toIso8601String().split('T')[0];
    
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'user_id = ? AND expense_date >= ? AND expense_date <= ?',
      whereArgs: [userId, startDate, endDate],
      orderBy: 'expense_date DESC',
    );
    return maps.map((e) => ExpenseModel.fromLocalJson(e)).toList();
  }
  
  Future<List<ExpenseModel>> getUnsyncedExpenses(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return maps.map((e) => ExpenseModel.fromLocalJson(e)).toList();
  }
  
  Future<void> markExpenseAsSynced(String id) async {
    final db = await database;
    await db.update(
      'expenses',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ==================== BUDGETS ====================
  
  Future<void> insertBudget(BudgetModel budget) async {
    final db = await database;
    await db.insert(
      'budgets',
      budget.toLocalJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<BudgetModel>> getBudgets(String userId, int month, int year) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'user_id = ? AND month = ? AND year = ?',
      whereArgs: [userId, month, year],
    );
    return maps.map((e) => BudgetModel.fromLocalJson(e)).toList();
  }
  
  Future<List<BudgetModel>> getUnsyncedBudgets(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return maps.map((e) => BudgetModel.fromLocalJson(e)).toList();
  }
  
  Future<void> markBudgetAsSynced(String id) async {
    final db = await database;
    await db.update(
      'budgets',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ==================== USER SESSION ====================
  
  Future<void> saveUserSession(String oderId, String email, String? displayName) async {
    final db = await database;
    await db.delete('user_session');
    await db.insert('user_session', {
      'id': 1,
      'user_id': oderId,
      'email': email,
      'display_name': displayName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  Future<Map<String, dynamic>?> getUserSession() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('user_session');
    if (maps.isEmpty) return null;
    return maps.first;
  }
  
  Future<void> clearUserSession() async {
    final db = await database;
    await db.delete('user_session');
  }
  
  // ==================== DEBTS ====================
  
  Future<void> insertDebt(DebtModel debt) async {
    final db = await database;
    await db.insert(
      'debts',
      debt.toLocalJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<DebtModel>> getDebts(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'debts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => DebtModel.fromLocalJson(e)).toList();
  }
  
  Future<List<DebtModel>> getUnsyncedDebts(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'debts',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return maps.map((e) => DebtModel.fromLocalJson(e)).toList();
  }
  
  Future<void> markDebtAsSynced(String id) async {
    final db = await database;
    await db.update(
      'debts',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> deleteDebt(String id) async {
    final db = await database;
    await db.delete(
      'debts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ==================== CLEAR ALL ====================
  
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('expenses');
    await db.delete('budgets');
    await db.delete('debts');
    await db.delete('user_session');
  }
  // ==================== SETTINGS (Currency) ====================

  Future<void> saveCurrency(String currencyCode) async {
    final db = await database;
    // We'll use user_session table to store app settings for simplicity or create a new one
    // But since session might be cleared on logout, and settings should persist, 
    // let's use shared_preferences logic or just a simple key-value table. 
    // For now, let's CREATE a simple settings table if not exists.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    
    await db.insert(
      'settings',
      {'key': 'currency', 'value': currencyCode},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getCurrency() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['currency'],
      );
      if (maps.isNotEmpty) {
        return maps.first['value'] as String;
      }
    } catch (e) {
      // Table might not exist yet
    }
    return null;
  }
}
