import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../models/expense_model.dart';
import '../../services/sync_service.dart';
import '../../utils/constants.dart';

class ReportsScreen extends StatefulWidget {
  final String userId;
  final SyncService syncService;
  final AppCurrency currency;
  
  const ReportsScreen({
    super.key,
    required this.userId,
    required this.syncService,
    required this.currency,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<ExpenseModel> _monthlyExpenses = [];
  Map<int, double> _yearlyExpenses = {};
  bool _isLoading = true;
  
  final _numberFormat = NumberFormat('#,##0', 'ar');
  int _selectedYear = DateTime.now().year;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final now = DateTime.now();
    
    // Load monthly expenses
    _monthlyExpenses = await widget.syncService.getExpensesByMonth(
      widget.userId,
      now.month,
      now.year,
    );
    
    // Load yearly expenses (aggregate by month)
    _yearlyExpenses = {};
    for (int month = 1; month <= 12; month++) {
      final expenses = await widget.syncService.getExpensesByMonth(
        widget.userId,
        month,
        _selectedYear,
      );
      _yearlyExpenses[month] = expenses.fold(0, (sum, e) => sum + e.amount);
    }
    
    setState(() => _isLoading = false);
  }
  
  double get _totalMonthly => _monthlyExpenses.fold(0, (sum, e) => sum + e.amount);
  double get _totalYearly => _yearlyExpenses.values.fold(0, (sum, e) => sum + e);
  
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
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMonthlyReport(),
                  _buildYearlyReport(),
                ],
              ),
            ),
          ],
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
          Text(
            'التقارير',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_selectedYear',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
  
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textMuted,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'شهري'),
          Tab(text: 'سنوي'),
        ],
      ),
    );
  }
  
  Widget _buildMonthlyReport() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Group by category
    final categoryTotals = <ExpenseCategory, double>{};
    for (final expense in _monthlyExpenses) {
      categoryTotals[expense.category] = 
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }
    
    // Sort by amount
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Monthly Total Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.glowShadow,
            ),
            child: Column(
              children: [
                const Text(
                  'إجمالي الشهر',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_numberFormat.format(_totalMonthly)} ${widget.currency.symbol}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMMM yyyy', 'ar').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 24),
          
          // Pie Chart
          if (categoryTotals.isNotEmpty) ...[
            const Text(
              'توزيع حسب الفئة',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassDecoration,
              child: _buildPieChart(categoryTotals),
            ).animate().fadeIn(delay: 200.ms),
          ],
          
          const SizedBox(height: 24),
          
          // Category Breakdown
          const Text(
            'تفصيل الفئات',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          
          if (sortedCategories.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: AppTheme.glassDecoration,
              child: const Center(
                child: Text(
                  'لا توجد نفقات هذا الشهر',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            )
          else
            ...sortedCategories.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final percentage = (_totalMonthly > 0) 
                  ? (item.value / _totalMonthly * 100) 
                  : 0;
              
              return _buildCategoryItem(
                item.key,
                item.value,
                percentage.toDouble(),
              ).animate().fadeIn(delay: (300 + index * 50).ms);
            }),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }
  
  Widget _buildPieChart(Map<ExpenseCategory, double> data) {
    final entries = data.entries.toList();
    
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 35,
        sections: entries.map((entry) {
          final color = AppTheme.categoryColors[entry.key.key] ?? AppTheme.textMuted;
          final percentage = (entry.value / _totalMonthly * 100);
          
          return PieChartSectionData(
            color: color,
            value: entry.value,
            title: percentage >= 10 ? '${percentage.toStringAsFixed(0)}%' : '',
            radius: 45,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildCategoryItem(
    ExpenseCategory category,
    double amount,
    double percentage,
  ) {
    final color = AppTheme.categoryColors[category.key] ?? AppTheme.textMuted;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: color,
              size: 22,
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
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0, 1),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_numberFormat.format(amount)} ${widget.currency.symbol}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildYearlyReport() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Yearly Total Card
          Container(
            padding: const EdgeInsets.all(24),
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
            child: Column(
              children: [
                const Text(
                  'إجمالي السنة',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_numberFormat.format(_totalYearly)} ${widget.currency.symbol}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_selectedYear',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 24),
          
          // Monthly Bar Chart
          const Text(
            'النفقات الشهرية',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassDecoration,
            child: _buildYearlyBarChart(),
          ).animate().fadeIn(delay: 200.ms),
          
          const SizedBox(height: 24),
          
          // Monthly Breakdown
          const Text(
            'تفصيل الأشهر',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          
          ...List.generate(12, (index) {
            final month = index + 1;
            final amount = _yearlyExpenses[month] ?? 0;
            if (amount == 0) return const SizedBox.shrink();
            
            return _buildMonthItem(month, amount)
                .animate()
                .fadeIn(delay: (300 + index * 30).ms);
          }),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }
  
  Widget _buildYearlyBarChart() {
    final maxValue = _yearlyExpenses.values.isEmpty 
        ? 1000.0 
        : _yearlyExpenses.values.reduce((a, b) => a > b ? a : b);
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppTheme.cardBackground,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = group.x + 1;
              final monthName = DateFormat('MMM', 'ar')
                  .format(DateTime(_selectedYear, month));
              return BarTooltipItem(
                '$monthName\n${_numberFormat.format(rod.toY)} ${widget.currency.symbol}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final month = value.toInt() + 1;
                if (month < 1 || month > 12) return const SizedBox.shrink();
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('M', 'ar').format(DateTime(_selectedYear, month)),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(12, (index) {
          final month = index + 1;
          final amount = _yearlyExpenses[month] ?? 0;
          final isCurrentMonth = month == DateTime.now().month;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: amount,
                color: isCurrentMonth 
                    ? AppTheme.primaryColor 
                    : AppTheme.secondaryColor.withValues(alpha: 0.7),
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
  
  Widget _buildMonthItem(int month, double amount) {
    final monthName = DateFormat('MMMM', 'ar').format(DateTime(_selectedYear, month));
    final isCurrentMonth = month == DateTime.now().month;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentMonth 
            ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isCurrentMonth ? AppTheme.primaryColor : AppTheme.secondaryColor)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$month',
                style: TextStyle(
                  color: isCurrentMonth ? AppTheme.primaryColor : AppTheme.secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              monthName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${_numberFormat.format(amount)} ${widget.currency.symbol}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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
}
