import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/expense_model.dart';
import '../../models/budget_model.dart';
import '../../utils/constants.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../expenses/add_expense_screen.dart';
import '../budget/budget_screen.dart';
import '../reports/reports_screen.dart';
import '../auth/login_screen.dart';
import '../../services/export_service.dart';
import '../../widgets/charts/pie_chart_widget.dart';
import '../../widgets/expandable_fab.dart';
import '../debt/debt_tracker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  
  late final ConnectivityService _connectivity;
  late final LocalStorageService _localStorage;
  late final SupabaseService _supabase;
  late final SyncService _syncService;
  late final AuthService _authService;
  
  String? _userId;
  List<ExpenseModel> _expenses = [];
  List<BudgetModel> _budgets = [];
  double _totalExpenses = 0;
  double _monthlyBudget = 0;
  bool _isLoading = true;
  
  final _numberFormat = NumberFormat('#,##0.00', 'ar');
  

  
  AppCurrency _currency = AppCurrency.sar;
  bool _showAllExpenses = false;


  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }
  
  Future<void> _initServices() async {
    _connectivity = ConnectivityService();
    _localStorage = LocalStorageService();
    _supabase = SupabaseService();
    _authService = AuthService(
      supabase: _supabase,
      localStorage: _localStorage,
      connectivity: _connectivity,
    );
    _syncService = SyncService(
      connectivity: _connectivity,
      localStorage: _localStorage,
      supabase: _supabase,
    );
    
    _isGuest = await _authService.isGuestSession();
    _userId = await _authService.getUserId();
    
    // Load currency
    final savedCurrency = await _localStorage.getCurrency();
    if (savedCurrency != null) {
      _currency = AppCurrency.values.firstWhere(
        (c) => c.code == savedCurrency,
        orElse: () => AppCurrency.sar,
      );
    }
    
    // Schedule daily reminder at 9 PM
    await NotificationService().scheduleDailyReminder(
      title: 'مــيزانيتي 💰',
      body: 'لا تنسى تسجيل نفقاتك اليوم للمحافظة على ميزانيتك!',
      hour: 21,
      minute: 0,
    );
    
    await _loadData();
  }
  
  Future<void> _loadData() async {
    if (_userId == null) return;
    
    setState(() => _isLoading = true);
    
    final now = DateTime.now();
    _expenses = await _syncService.getExpensesByMonth(_userId!, now.month, now.year);
    _totalExpenses = _expenses.fold(0, (sum, e) => sum + e.amount);
    
    final budgets = await _syncService.getBudgets(_userId!, now.month, now.year);
    _budgets = budgets;
    _monthlyBudget = budgets.fold(0, (sum, b) => sum + b.amount);
    
    if (_connectivity.isConnected) {
      await _syncService.syncAll();
    }

    // Phase 1: Persistent Notification update
    _updatePersistentNotification();
    
    setState(() => _isLoading = false);
  }

  Future<void> _updatePersistentNotification() async {
    await NotificationService().showPersistentSummary(
      totalBudget: _monthlyBudget,
      totalSpent: _totalExpenses,
      currency: _currency.code,
    );
  }

  Future<void> _changeCurrency() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختر العملة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...AppCurrency.values.map((currency) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currency == currency 
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currency.symbol,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _currency == currency ? AppTheme.primaryColor : Colors.white,
                  ),
                ),
              ),
              title: Text(
                currency.name,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: _currency == currency 
                  ? const Icon(Iconsax.tick_circle, color: AppTheme.primaryColor)
                  : null,
              onTap: () async {
                await _localStorage.saveCurrency(currency.code);
                setState(() => _currency = currency);
                if (mounted) Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentIndex == 0 ? _buildFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
  
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return BudgetScreen(
          userId: _userId ?? '',
          syncService: _syncService,
          currency: _currency,
          onRefresh: _loadData,
        );
      case 2:
        return ReportsScreen(
          userId: _userId ?? '',
          syncService: _syncService,
          currency: _currency,
        );
      case 3:
        return _buildSettingsPage();
      default:
        return _buildHomePage();
    }
  }


  
  Widget _buildHomePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            AppTheme.scaffoldBackground,
          ],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              
              // Summary Cards
              SliverToBoxAdapter(
                child: _buildSummaryCards(),
              ),
              
              // Chart Section
              SliverToBoxAdapter(
                child: _buildChartSection(),
              ),
              
              // Recent Expenses
              SliverToBoxAdapter(
                child: _buildRecentExpenses(),
              ),
              
              // Spacer for FAB
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحباً! 👋',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMMM yyyy', 'ar').format(DateTime.now()),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          // Connection Status
          Row(
            children: [
              IconButton(
                icon: const Icon(Iconsax.document_download, color: Colors.white70),
                onPressed: _showExportOptions,
                tooltip: 'تصدير التقرير',
              ),
              const SizedBox(width: 8),
              StreamBuilder<bool>(
                stream: _connectivity.connectionStream,
                builder: (context, snapshot) {
                  final isConnected = snapshot.data ?? _connectivity.isConnected;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isConnected ? Colors.green : Colors.orange).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConnected ? Iconsax.wifi : Iconsax.wifi_square,
                          size: 16,
                          color: isConnected ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConnected ? 'متصل' : 'غير متصل',
                          style: TextStyle(
                            fontSize: 12,
                            color: isConnected ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
  
  Widget _buildSummaryCards() {
    final remaining = _monthlyBudget - _totalExpenses;
    final safeMonthlyBudget = _monthlyBudget.isFinite ? _monthlyBudget : 0.0;
    final percentage = (safeMonthlyBudget > 0) 
        ? (_totalExpenses / safeMonthlyBudget * 100) 
        : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Main Budget Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.glowShadow,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الميزانية الشهرية',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 200,
                          child: FittedBox(
                            alignment: Alignment.centerRight,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${_numberFormat.format(_monthlyBudget)} ${_currency.symbol}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Iconsax.wallet_3,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0, 1).toDouble(),
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(
                      percentage > 100 ? Colors.red : Colors.white,
                    ),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerRight,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'المصروف: ${_numberFormat.format(_totalExpenses)} ${_currency.symbol}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: percentage > 100 ? Colors.red[300] : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 16),
          
          // Small Cards Row
          Row(
            children: [
              Expanded(
                child: _buildSmallCard(
                  title: 'المتبقي',
                  value: '${_numberFormat.format(remaining.abs())} ${_currency.symbol}',
                  icon: Iconsax.money_recive,
                  color: remaining >= 0 ? AppTheme.secondaryColor : AppTheme.accentRed,
                  isNegative: remaining < 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallCard(
                  title: 'عدد النفقات',
                  value: '${_expenses.length}',
                  icon: Iconsax.receipt,
                  color: AppTheme.accentBlue,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
  
  Widget _buildSmallCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isNegative = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (isNegative)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'تجاوز',
                    style: TextStyle(fontSize: 10, color: AppTheme.accentRed),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChartSection() {
    if (_expenses.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Group expenses by category
    final categoryTotals = <ExpenseCategory, double>{};
    for (final expense in _expenses) {
      categoryTotals[expense.category] = 
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع النفقات',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassDecoration,
            child: SizedBox(
              height: 200,
              child: ExpensePieChart(
                categoryTotals: categoryTotals,
                totalExpenses: _totalExpenses,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
  
  Widget _buildRecentExpenses() {
    // If _showAllExpenses is true, show all expenses. Otherwise, show only the top 5.
    final displayedExpenses = _showAllExpenses ? _expenses : _expenses.take(5).toList();
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر النفقات',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllExpenses = !_showAllExpenses;
                  });
                },
                child: Text(_showAllExpenses ? 'عرض أقل' : 'عرض الكل'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (displayedExpenses.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: AppTheme.glassDecoration,
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Iconsax.empty_wallet,
                      size: 48,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد نفقات بعد',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اضغط + لإضافة نفقة جديدة',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayedExpenses.asMap().entries.map((entry) {
              final index = entry.key;
              final expense = entry.value;
              return _buildExpenseItem(expense)
                  .animate()
                  .fadeIn(delay: (100 + index * 50).ms)
                  .slideX(begin: 0.1, end: 0);
            }),
        ],
      ),
    );
  }
  
  Widget _buildExpenseItem(ExpenseModel expense) {
    final color = AppTheme.categoryColors[expense.category.key] ?? AppTheme.textMuted;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(expense.category),
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.category.arabicName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM', 'ar').format(expense.expenseDate),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_numberFormat.format(expense.amount)} ${_currency.symbol}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (!expense.isSynced)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'غير مزامن',
                    style: TextStyle(fontSize: 9, color: Colors.orange),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(
                    userId: _userId ?? '',
                    syncService: _syncService,
                    expense: expense,
                  ),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
            icon: const Icon(Iconsax.edit, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }
  
  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Iconsax.coffee;
      case ExpenseCategory.transport:
        return Iconsax.car;
      case ExpenseCategory.entertainment:
        return Iconsax.game;
      case ExpenseCategory.shopping:
        return Iconsax.shopping_bag;
      case ExpenseCategory.bills:
        return Iconsax.receipt_1;
      case ExpenseCategory.health:
        return Iconsax.health;
      case ExpenseCategory.education:
        return Iconsax.book;
      case ExpenseCategory.other:
        return Iconsax.more;
    }
  }
  
  Widget _buildSettingsPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), AppTheme.scaffoldBackground],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'الإعدادات',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSettingItem(
              icon: Iconsax.user,
              title: 'الحساب',
              subtitle: _isGuest ? 'زائر - اضغط للتسجيل' : (_authService.currentUser?.email ?? 'مستخدم'),
              onTap: _isGuest ? _navigateToLogin : () {},
            ),
            
            // Guest Mode Warning
            if (_authService.currentUser == null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.warning_2, color: AppTheme.accentOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'حساب زائر',
                            style: TextStyle(
                              color: AppTheme.accentOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'بياناتك محفوظة محلياً فقط. سجل الدخول لحفظ نسخة احتياطية.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            _buildSettingItem(
              icon: Iconsax.notification,
              title: 'الإشعارات',
              subtitle: 'تفعيل التنبيهات',
              onTap: () {},
            ),
            
              _buildSettingItem(
                icon: Iconsax.money_change,
                title: 'العملة',
                subtitle: _currency.name,
                onTap: _changeCurrency,
              ),

              _buildSettingItem(
                icon: Iconsax.refresh,
                title: 'مزامنة البيانات',
                subtitle: 'مزامنة مع السحابة',
                onTap: () {
                  _syncService.syncAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري المزامنة...')),
                  );
                },
              ),
            
            const SizedBox(height: 24),
            
            _buildSettingItem(
              icon: Iconsax.logout,
              title: 'تسجيل الخروج',
              subtitle: 'الخروج من الحساب',
              isDestructive: true,
              onTap: () async {
                await _authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isDestructive ? AppTheme.accentRed : AppTheme.primaryColor)
                .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isDestructive ? AppTheme.accentRed : AppTheme.primaryColor,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive ? AppTheme.accentRed : Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        trailing: Icon(
          Iconsax.arrow_left_2,
          color: AppTheme.textMuted,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
  
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Iconsax.home, 'الرئيسية'),
              _buildNavItem(1, Iconsax.wallet, 'الميزانية'),
              const SizedBox(width: 56), // Space for FAB
              _buildNavItem(2, Iconsax.chart, 'التقارير'),
              _buildNavItem(3, Iconsax.setting_2, 'الإعدادات'),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: 0.2) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFAB() {
    return ExpandableFab(
      onDebtPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DebtTrackerScreen()),
        ).then((_) => _loadData());
      },
      onExpensePressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddExpenseScreen(
              userId: _userId ?? '',
              syncService: _syncService,
            ),
          ),
        );
        if (result == true) {
          _loadData();
        }
      },
    );
  }
  
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تصدير التقرير',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            _buildSettingItem(
              icon: Iconsax.document_text,
              title: 'تصدير بصيغة PDF',
              subtitle: 'تقرير منسق قابل للطباعة والمشاركة',
              onTap: () async {
                Navigator.pop(context);
                try {
                  final monthName = DateFormat('MMMM', 'ar').format(DateTime.now());
                  await ExportService.exportToPdf(
                    userName: 'مستخدم Balanceer',
                    expenses: _expenses,
                    budgets: _budgets,
                    monthName: monthName,
                    year: DateTime.now().year,
                    totalBudget: _monthlyBudget,
                    totalSpent: _totalExpenses,
                    currency: _currency.code,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ في تصدير PDF: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              icon: Iconsax.document_1,
              title: 'تصدير بصيغة Excel',
              subtitle: 'ملف بيانات لفتحه عبر جداول البيانات',
              onTap: () async {
                Navigator.pop(context);
                try {
                  final monthName = DateFormat('MMMM', 'ar').format(DateTime.now());
                  await ExportService.exportToExcel(
                    expenses: _expenses,
                    monthName: monthName,
                    year: DateTime.now().year,
                    currency: _currency.code,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ في تصدير Excel: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _connectivity.dispose();
    _syncService.dispose();
    super.dispose();
  }
}
