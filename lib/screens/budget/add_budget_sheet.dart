import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../config/theme.dart';
import '../../models/budget_model.dart';
import '../../models/expense_model.dart';
import '../../services/sync_service.dart';
import '../../utils/constants.dart';

class AddBudgetSheet extends StatefulWidget {
  final String userId;
  final SyncService syncService;
  final AppCurrency currency;
  final BudgetModel? existingBudget;
  final VoidCallback onSave;

  const AddBudgetSheet({
    super.key,
    required this.userId,
    required this.syncService,
    required this.currency,
    required this.onSave,
    this.existingBudget,
  });

  @override
  State<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<AddBudgetSheet> {
  late ExpenseCategory _selectedCategory;
  late TextEditingController _amountController;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.existingBudget != null 
        ? ExpenseCategory.values.firstWhere(
            (c) => c.key == widget.existingBudget!.category,
            orElse: () => ExpenseCategory.food
          )
        : ExpenseCategory.food;
    
    _amountController = TextEditingController(
      text: widget.existingBudget != null ? widget.existingBudget!.amount.toString() : '',
    );

    if (widget.existingBudget != null) {
      _selectedMonth = widget.existingBudget!.month;
      _selectedYear = widget.existingBudget!.year;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: SingleChildScrollView(
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
                widget.existingBudget != null ? 'تعديل الميزانية' : 'إضافة ميزانية',
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
                  final isSelected = _selectedCategory == category;
                  final color = AppTheme.categoryColors[category.key]!;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = category);
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
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(9),
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText: '0.00',
                  suffixText: widget.currency.symbol,
                ),
              ),
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton(
                onPressed: _saveBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(widget.existingBudget != null ? 'تحديث' : 'حفظ الميزانية'),
              ),
              // Add padding at bottom to ensure content isn't right at the edge
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBudget() async {
    if (_amountController.text.isEmpty) return;
    
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    
    final budget = widget.existingBudget != null
        ? widget.existingBudget!.copyWith(
            amount: amount,
            category: _selectedCategory.key,
            isSynced: false,
          )
        : BudgetModel.create(
            userId: widget.userId,
            category: _selectedCategory.key,
            amount: amount,
            month: _selectedMonth,
            year: _selectedYear,
          );
    
    await widget.syncService.addBudget(budget);
    
    if (mounted) {
      Navigator.pop(context);
      widget.onSave();
    }
  }
}
