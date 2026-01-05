import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../models/expense_model.dart';
import '../../services/sync_service.dart';
import '../../services/notification_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final String userId;
  final SyncService syncService;
  
  const AddExpenseScreen({
    super.key,
    required this.userId,
    required this.syncService,
    this.expense,
  });

  final ExpenseModel? expense;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _amountController.text = widget.expense!.amount.toString();
      _notesController.text = widget.expense!.notes ?? '';
      _selectedCategory = widget.expense!.category;
      _selectedDate = widget.expense!.expenseDate;
    }
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    final expense = widget.expense != null 
        ? widget.expense!.copyWith(
            category: _selectedCategory,
            amount: double.parse(_amountController.text),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            expenseDate: _selectedDate,
            isSynced: false,
          )
        : ExpenseModel.create(
            userId: widget.userId,
            category: _selectedCategory,
            amount: double.parse(_amountController.text),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            expenseDate: _selectedDate,
          );
    
    if (widget.expense != null) {
      await widget.syncService.updateExpense(expense);
    } else {
      await widget.syncService.addExpense(expense);
    }

    // Phase 2: Budget notifications
    _checkBudgetNotifications(expense.category, expense.expenseDate);
    
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _checkBudgetNotifications(ExpenseCategory category, DateTime date) async {
    try {
      // Get all budgets for the month
      final budgets = await widget.syncService.getBudgets(
        widget.userId,
        date.month,
        date.year,
      );
      
      // Find budget for selected category
      BudgetModel? categoryBudget;
      for (final b in budgets) {
        if (b.category == category) {
          categoryBudget = b;
          break;
        }
      }

      if (categoryBudget != null) {
        // Get all expenses for this category in the same month
        final expenses = await widget.syncService.getExpensesByMonth(
          widget.userId,
          date.month,
          date.year,
        );
        
        final categoryTotal = expenses
            .where((e) => e.category == category)
            .fold(0.0, (sum, e) => sum + e.amount);

        // Notify if threshold reached
        await NotificationService().checkAndNotifyBudgetThreshold(
          currentSpent: categoryTotal,
          totalBudget: categoryBudget.amount,
          categoryName: category.arabicName,
        );
      }
    } catch (e) {
      debugPrint('Error checking budget notifications: $e');
    }
  }
  
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.cardBackground,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAmountField(),
                        const SizedBox(height: 24),
                        _buildCategorySelector(),
                        const SizedBox(height: 24),
                        _buildDateSelector(),
                        const SizedBox(height: 24),
                        _buildNotesField(),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
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
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            widget.expense != null ? 'تعديل النفقة' : 'إضافة نفقة جديدة',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
  
  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المبلغ',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.glowShadow,
          ),
          child: Column(
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(9),
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  suffixText: 'ر.س',
                  suffixStyle: TextStyle(
                    fontSize: 20,
                    color: Colors.white70,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال المبلغ';
                  }
                  if (double.tryParse(value) == null) {
                    return 'مبلغ غير صالح';
                  }
                  if (double.parse(value) <= 0) {
                    return 'المبلغ يجب أن يكون أكبر من صفر';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الفئة',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ExpenseCategory.values.map((category) {
            final isSelected = _selectedCategory == category;
            final color = AppTheme.categoryColors[category.key] ?? AppTheme.textMuted;
            
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.3) : AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCategoryIcon(category),
                      color: isSelected ? color : AppTheme.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category.arabicName,
                      style: TextStyle(
                        color: isSelected ? color : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التاريخ',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.calendar_1,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Iconsax.arrow_down_1,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ملاحظات (اختياري)',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'أضف ملاحظات...',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: Icon(Iconsax.note, color: AppTheme.primaryColor),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveExpense,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.add_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.expense != null ? 'حفظ التعديلات' : 'حفظ النفقة',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 500.ms).scale(delay: 500.ms);
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
