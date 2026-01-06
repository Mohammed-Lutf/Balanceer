import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';

class ExpenseChartData {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const ExpenseChartData({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });
}

class ExpensePieChart extends StatefulWidget {
  final List<ExpenseChartData> data;
  final double totalExpenses;
  
  const ExpensePieChart({
    super.key,
    required this.data,
    required this.totalExpenses,
  });

  @override
  State<ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<ExpensePieChart> {
  int? _touchedIndex;
  
  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
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
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final isTouched = index == _touchedIndex;
      final percentage = widget.totalExpenses > 0 
          ? (data.amount / widget.totalExpenses * 100) 
          : 0.0;
      
      return PieChartSectionData(
        color: data.color,
        value: data.amount,
        title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 55 : 45,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: isTouched ? _buildBadge(data) : null,
        badgePositionPercentageOffset: 1.2,
      );
    }).toList();
  }
  
  Widget _buildBadge(ExpenseChartData data) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: data.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(
        data.icon,
        color: Colors.white,
        size: 14,
      ),
    );
  }
  
  Widget _buildLegend() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.data.take(5).map((data) {
        final percentage = widget.totalExpenses > 0
            ? (data.amount / widget.totalExpenses * 100)
            : 0.0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: data.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.label,
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
                  color: data.color,
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
}
