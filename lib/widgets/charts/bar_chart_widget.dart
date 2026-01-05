import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../models/expense_model.dart';
import '../../utils/constants.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ExpenseBarChart extends StatefulWidget {
  final Map<ExpenseCategory, double> expenses;
  final Map<String, double> budgets;
  final AppCurrency? currency;
  
  const ExpenseBarChart({
    super.key,
    required this.expenses,
    required this.budgets,
    this.currency,
  });

  @override
  State<ExpenseBarChart> createState() => _ExpenseBarChartState();
}

class _ExpenseBarChartState extends State<ExpenseBarChart> {
  int? _touchedIndex;
  
  @override
  Widget build(BuildContext context) {
    if (widget.expenses.isEmpty && widget.budgets.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد بيانات',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    
    final currencySymbol = widget.currency?.symbol ?? 'ر.س';

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('المصروف', AppTheme.primaryColor),
            const SizedBox(width: 24),
            _buildLegendItem('الميزانية', AppTheme.secondaryColor),
          ],
        ),
        const SizedBox(height: 16),
        
        // Chart
        Expanded(
          child: BarChart(
            BarChartData(
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => AppTheme.cardBackground,
                  tooltipRoundedRadius: 12,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final category = ExpenseCategory.values[group.x];
                    final value = rod.toY;
                    final isExpense = rodIndex == 0;
                    
                    return BarTooltipItem(
                      '${category.arabicName}\n${isExpense ? "المصروف" : "الميزانية"}: ${value.toStringAsFixed(0)} $currencySymbol',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions || response == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = response.spot?.touchedBarGroupIndex;
                  });
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < ExpenseCategory.values.length) {
                        final category = ExpenseCategory.values[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _getShortName(category),
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    reservedSize: 28,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _buildBarGroups(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  );
                },
              ),
            ),
          )
          .animate()
          .slideY(
            begin: 0.2, 
            end: 0, 
            duration: 600.ms, 
            curve: Curves.easeOut,
          )
          .fadeIn(duration: 400.ms),
        ),
      ],
    );
  }
  
  List<BarChartGroupData> _buildBarGroups() {
    final groups = <BarChartGroupData>[];
    
    for (var i = 0; i < ExpenseCategory.values.length; i++) {
      final category = ExpenseCategory.values[i];
      final expenseValue = widget.expenses[category] ?? 0;
      final budgetValue = widget.budgets[category.key] ?? 0;
      
      if (expenseValue == 0 && budgetValue == 0) continue;
      
      final isTouched = _touchedIndex == i;
      final color = AppTheme.categoryColors[category.key] ?? AppTheme.textMuted;
      
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: expenseValue,
              color: color,
              width: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: budgetValue,
                color: color.withValues(alpha: 0.2),
              ),
            ),
          ],
          showingTooltipIndicators: isTouched ? [0] : [],
        ),
      );
    }
    
    return groups;
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  String _getShortName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return 'طعام';
      case ExpenseCategory.transport:
        return 'نقل';
      case ExpenseCategory.entertainment:
        return 'ترفيه';
      case ExpenseCategory.shopping:
        return 'تسوق';
      case ExpenseCategory.bills:
        return 'فواتير';
      case ExpenseCategory.health:
        return 'صحة';
      case ExpenseCategory.education:
        return 'تعليم';
      case ExpenseCategory.other:
        return 'أخرى';
    }
  }
}
