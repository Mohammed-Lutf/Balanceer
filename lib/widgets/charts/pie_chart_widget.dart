import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../models/expense_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ExpensePieChart extends StatefulWidget {
  final Map<ExpenseCategory, double> categoryTotals;
  final double totalExpenses;
  
  const ExpensePieChart({
    super.key,
    required this.categoryTotals,
    required this.totalExpenses,
  });

  @override
  State<ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<ExpensePieChart> {
  int? _touchedIndex;
  
  @override
  Widget build(BuildContext context) {
    if (widget.categoryTotals.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد بيانات',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: _buildSections(),
            ),
          )
          .animate()
          .scale(
            duration: 600.ms, 
            curve: Curves.easeOutBack,
          )
          .fadeIn(duration: 400.ms),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLegend(),
        ),
      ],
    );
  }
  
  List<PieChartSectionData> _buildSections() {
    final entries = widget.categoryTotals.entries.toList();
    
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final categoryEntry = entry.value;
      final isTouched = index == _touchedIndex;
      final percentage = (categoryEntry.value / widget.totalExpenses * 100);
      final color = AppTheme.categoryColors[categoryEntry.key.key] ?? AppTheme.textMuted;
      
      return PieChartSectionData(
        color: color,
        value: categoryEntry.value,
        title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 55 : 45,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: isTouched ? _buildBadge(categoryEntry.key) : null,
        badgePositionPercentageOffset: 1.2,
      );
    }).toList();
  }
  
  Widget _buildBadge(ExpenseCategory category) {
    final color = AppTheme.categoryColors[category.key] ?? AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(
        _getCategoryIcon(category),
        color: Colors.white,
        size: 14,
      ),
    );
  }
  
  Widget _buildLegend() {
    final entries = widget.categoryTotals.entries.toList();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.take(5).map((entry) {
        final color = AppTheme.categoryColors[entry.key.key] ?? AppTheme.textMuted;
        final percentage = (entry.value / widget.totalExpenses * 100);
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key.arabicName,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transport:
        return Icons.directions_car;
      case ExpenseCategory.entertainment:
        return Icons.sports_esports;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag;
      case ExpenseCategory.bills:
        return Icons.receipt;
      case ExpenseCategory.health:
        return Icons.health_and_safety;
      case ExpenseCategory.education:
        return Icons.school;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }
}
