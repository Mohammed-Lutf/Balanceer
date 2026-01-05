import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/debt_model.dart';
import '../../services/sync_service.dart';
import '../../services/supabase_service.dart';

class AddDebtScreen extends StatefulWidget {
  final DebtModel? debt;
  const AddDebtScreen({super.key, this.debt});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late DebtType _selectedType;
  late DateTime _debtDate;
  DateTime? _dueDate;
  DateTime? _paidDate;
  late bool _isPaid;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.debt?.personName ?? '');
    _amountController = TextEditingController(text: widget.debt?.amount.toString() ?? '');
    _notesController = TextEditingController(text: widget.debt?.notes ?? '');
    _selectedType = widget.debt?.type ?? DebtType.credit;
    _debtDate = widget.debt?.debtDate ?? DateTime.now();
    _dueDate = widget.debt?.dueDate;
    _paidDate = widget.debt?.paidDate;
    _isPaid = widget.debt?.isPaid ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDebtDate, bool isDueDate, bool isPaidDate) async {
    final current = isDebtDate ? _debtDate : (isDueDate ? (_dueDate ?? DateTime.now()) : (_paidDate ?? DateTime.now()));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme.copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.cardBackground,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDebtDate) _debtDate = picked;
        if (isDueDate) _dueDate = picked;
        if (isPaidDate) _paidDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final syncService = Provider.of<SyncService>(context, listen: false);
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    final user = supabase.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final amount = double.parse(_amountController.text);
    
    DebtModel debt;
    if (widget.debt == null) {
      debt = DebtModel.create(
        userId: user.id,
        personName: _nameController.text,
        amount: amount,
        type: _selectedType,
        debtDate: _debtDate,
        dueDate: _dueDate,
        notes: _notesController.text,
      );
    } else {
      debt = widget.debt!.copyWith(
        personName: _nameController.text,
        amount: amount,
        type: _selectedType,
        debtDate: _debtDate,
        dueDate: _dueDate,
        paidDate: _isPaid ? (_paidDate ?? DateTime.now()) : null,
        isPaid: _isPaid,
        notes: _notesController.text,
        isSynced: false,
      );
    }

    try {
      if (widget.debt == null) {
        await syncService.addDebt(debt);
      } else {
        await syncService.updateDebt(debt);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السجل'),
        content: const Text('هل أنت متأكد من حذف هذا الدين؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.deleteDebt(widget.debt!.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text(widget.debt == null ? 'إضافة سجل جديد' : 'تعديل السجل'),
        actions: [
          if (widget.debt != null)
            IconButton(
              onPressed: _isLoading ? null : _delete,
              icon: const Icon(Iconsax.trash, color: AppTheme.accentRed),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: 'اسم الشخص',
                icon: Iconsax.user,
                validator: (value) => value == null || value.isEmpty ? 'يرجى إدخال الاسم' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _amountController,
                label: 'المبلغ',
                icon: Iconsax.money_2,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'يرجى إدخال المبلغ';
                  if (double.tryParse(value) == null) return 'يرجى إدخال رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildDatePickerRow('تاريخ الدين', _debtDate, () => _pickDate(true, false, false)),
              const SizedBox(height: 16),
              _buildDatePickerRow(
                'تاريخ الاستحقاق (اختياري)', 
                _dueDate, 
                () => _pickDate(false, true, false),
                isClearable: true,
                onClear: () => setState(() => _dueDate = null),
              ),
              const SizedBox(height: 24),
              _buildPaidStatusToggle(),
              if (_isPaid) ...[
                const SizedBox(height: 16),
                _buildDatePickerRow('تم السداد في', _paidDate ?? DateTime.now(), () => _pickDate(false, false, true)),
              ],
              const SizedBox(height: 24),
              _buildTextField(
                controller: _notesController,
                label: 'ملاحظات إضافية',
                icon: Iconsax.note,
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('حفظ السجل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeButton(DebtType.credit, Colors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTypeButton(DebtType.debt, Colors.red),
        ),
      ],
    );
  }

  Widget _buildTypeButton(DebtType type, Color color) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Center(
          child: Text(
            type.arabicName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      ),
      validator: validator,
    );
  }

  Widget _buildDatePickerRow(String label, DateTime? date, VoidCallback onTap, {bool isClearable = false, VoidCallback? onClear}) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.calendar_1, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      Text(
                        date == null ? 'لم يحدد' : DateFormat('yyyy-MM-dd').format(date),
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isClearable && date != null) ...[
          const SizedBox(width: 12),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, color: AppTheme.accentRed, size: 20),
          ),
        ],
      ],
    );
  }

  Widget _buildPaidStatusToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isPaid ? Icons.check_circle : Icons.pending_actions,
                color: _isPaid ? AppTheme.secondaryColor : AppTheme.accentOrange,
              ),
              const SizedBox(width: 12),
              const Text('تم السداد بالكامل'),
            ],
          ),
          Switch(
            value: _isPaid,
            onChanged: (value) => setState(() => _isPaid = value),
            activeColor: AppTheme.secondaryColor,
          ),
        ],
      ),
    );
  }
}
