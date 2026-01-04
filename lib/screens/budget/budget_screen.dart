import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/expense_model.dart';
import '../../models/budget_model.dart';
import '../../services/sync_service.dart';
import '../../widgets/charts/bar_chart_widget.dart';
import '../../utils/constants.dart';

class BudgetScreen extends StatefulWidget {
  final String userId;
  final SyncService syncService;
  final AppCurrency currency;
  final VoidCallback? onRefresh;
  
  const BudgetScreen({
    super.key,
    required this.userId,
    required this.syncService,
    required this.currency,
    this.onRefresh,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<BudgetModel> _budgets = [];
  Map<ExpenseCategory, double> _expenses = {};
  bool _isLoading = true;
  
  final _numberFormat = NumberFormat('#,##0', 'ar');
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _budgets = await widget.syncService.getBudgets(
      widget.userId,
      _selectedMonth,
      _selectedYear,
    );
    
    final expensesList = await widget.syncService.getExpensesByMonth(
      widget.userId,
      _selectedMonth,
      _selectedYear,
    );
    
    _expenses = {};
    for (final expense in expensesList) {
      _expenses[expense.category] = 
          (_expenses[expense.category] ?? 0) + expense.amount;
    }
    
    setState(() => _isLoading = false);
  }
  
  double get _totalBudget => _budgets.fold(0, (sum, b) => sum + b.amount);
  double get _totalExpenses => _expenses.values.fold(0, (sum, e) => sum + e);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), AppTheme.scaffoldBackground],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSummaryCard()),
              SliverToBoxAdapter(child: _buildChart()),
              SliverToBoxAdapter(child: _buildCategoryBudgets()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الميزانية',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: _showAddBudgetDialog,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.add,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Month Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(12, (index) {
                final month = index + 1;
                final isSelected = month == _selectedMonth;
                final monthDate = DateTime(_selectedYear, month);
                
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedMonth = month);
                    _loadData();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppTheme.primaryColor 
                          : AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      DateFormat('MMM', 'ar').format(monthDate),
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
  
  Widget _buildSummaryCard() {
    final remaining = _totalBudget - _totalExpenses;
    final percentage = _totalBudget > 0 ? (_totalExpenses / _totalBudget * 100) : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
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
                _buildSummaryItem(
                  'الميزانية',
                  '${_numberFormat.format(_totalBudget)} ${widget.currency.symbol}',
                  Iconsax.wallet,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _buildSummaryItem(
                  'المصروف',
                  '${_numberFormat.format(_totalExpenses)} ${widget.currency.symbol}',
                  Iconsax.money_send,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _buildSummaryItem(
                  'المتبقي',
                  '${_numberFormat.format(remaining.abs())} ${widget.currency.symbol}',
                  Iconsax.money_recive,
                  isNegative: remaining < 0,
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Progress
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0, 1).toDouble(),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(
                  percentage > 100 ? Colors.red : Colors.white,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تم استخدام ${percentage.toStringAsFixed(1)}% من الميزانية',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon, {
    bool isNegative = false,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: isNegative ? Colors.red[300] : Colors.white70,
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isNegative ? Colors.red[300] : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildChart() {
    if (_budgets.isEmpty && _expenses.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final budgetMap = <String, double>{};
    for (final budget in _budgets) {
      budgetMap[budget.category] = budget.amount;
    }
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مقارنة النفقات بالميزانية',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassDecoration,
            child: ExpenseBarChart(
              expenses: _expenses,
              budgets: budgetMap,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
  
  Widget _buildCategoryBudgets() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ميزانية الفئات',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_budgets.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: AppTheme.glassDecoration,
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Iconsax.wallet_add,
                      size: 48,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'لا توجد ميزانية محددة',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddBudgetDialog,
                      icon: const Icon(Iconsax.add),
                      label: const Text('إضافة ميزانية'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...ExpenseCategory.values.map((category) {
              final budget = _budgets.where((b) => b.category == category.key).firstOrNull;
              final expense = _expenses[category] ?? 0;
              
              if (budget == null && expense == 0) return const SizedBox.shrink();
              
              return _buildCategoryBudgetItem(
                category,
                budget!.amount,
                expense,
                budget,
              );
            }),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
  
  Widget _buildCategoryBudgetItem(
    ExpenseCategory category,
    double budget,
    double expense,
    BudgetModel? budgetModel,
  ) {
    final color = AppTheme.categoryColors[category.key] ?? AppTheme.textMuted;
    final percentage = budget > 0 ? (expense / budget * 100) : 0;
    final isOverBudget = percentage > 100;
    
    return GestureDetector(
      onTap: () => _showAddBudgetDialog(existingBudget: budgetModel),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverBudget 
              ? AppTheme.accentRed.withValues(alpha: 0.5) 
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.arabicName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'الميزانية: ${_numberFormat.format(budget)} ${widget.currency.symbol}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_numberFormat.format(expense)} ${widget.currency.symbol}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isOverBudget ? AppTheme.accentRed : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Edit Icon
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.edit,
                          size: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverBudget ? AppTheme.accentRed : color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0, 1).toDouble(),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                isOverBudget ? AppTheme.accentRed : color,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
      ),
    );
  }
  
  void _showAddBudgetDialog({BudgetModel? existingBudget}) {
    ExpenseCategory selectedCategory = existingBudget != null 
        ? ExpenseCategory.values.firstWhere(
            (c) => c.key == existingBudget.category,
            orElse: () => ExpenseCategory.food
          )
        : ExpenseCategory.food;
        
    final amountController = TextEditingController(
      text: existingBudget != null ? existingBudget.amount.toString() : '',
    );
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Text(
                    existingBudget != null ? 'تعديل الميزانية' : 'إضافة ميزانية',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Category Selector
                  const Text(
                    'الفئة',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExpenseCategory.values.map((category) {
                      final isSelected = selectedCategory == category;
                      final color = AppTheme.categoryColors[category.key]!;
                      
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => selectedCategory = category);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? color.withValues(alpha: 0.3) 
                                : AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            category.arabicName,
                            style: TextStyle(
                              color: isSelected ? color : AppTheme.textSecondary,
                              fontWeight: isSelected 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  
                  // Amount Field
                  const Text(
                    'المبلغ',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      suffixText: widget.currency.symbol,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Button
                  ElevatedButton(
                    onPressed: () async {
                      if (amountController.text.isEmpty) return;
                      
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) return;
                      
                      final budget = existingBudget != null
                          ? existingBudget!.copyWith(
                              amount: amount,
                              category: selectedCategory.key,
                              isSynced: false,
                            )
                          : BudgetModel.create(
                              userId: widget.userId,
                              category: selectedCategory.key,
                              amount: amount,
                              month: _selectedMonth,
                              year: _selectedYear,
                            );
                      
                      await widget.syncService.addBudget(budget);
                      
                      if (!context.mounted) return;

                      if (mounted) {
                        Navigator.pop(context);
                        _loadData();
                        widget.onRefresh?.call();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(existingBudget != null ? 'تحديث' : 'حفظ الميزانية'),
                  ),
                ],
              ),
            ),
          );
        },
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
}
