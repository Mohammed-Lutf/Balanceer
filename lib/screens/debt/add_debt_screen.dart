import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/debt_model.dart';
import '../../services/sync_service.dart';
import '../../services/supabase_service.dart';
import '../../services/local_storage_service.dart';

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
  String? _userId;

  bool get _isEditing => widget.debt != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.debt?.personName ?? '');
    _amountController = TextEditingController(
      text: widget.debt != null ? widget.debt!.amount.toString() : '',
    );
    _notesController = TextEditingController(text: widget.debt?.notes ?? '');
    _selectedType = widget.debt?.type ?? DebtType.credit;
    _debtDate = widget.debt?.debtDate ?? DateTime.now();
    _dueDate = widget.debt?.dueDate;
    _paidDate = widget.debt?.paidDate;
    _isPaid = widget.debt?.isPaid ?? false;
    
    _initUserId();
  }

  Future<void> _initUserId() async {
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    final localStorage = Provider.of<LocalStorageService>(context, listen: false);
    
    final user = supabase.currentUser;
    if (user != null) {
      _userId = user.id;
    } else {
      final session = await localStorage.getUserSession();
      if (session != null) {
        _userId = session['user_id'] as String?;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required bool isDebtDate,
    required bool isDueDate,
    required bool isPaidDate,
  }) async {
    DateTime initialDate;
    if (isDebtDate) {
      initialDate = _debtDate;
    } else if (isDueDate) {
      initialDate = _dueDate ?? DateTime.now();
    } else {
      initialDate = _paidDate ?? DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme.copyWith(
            colorScheme: const ColorScheme.dark(
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
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final syncService = Provider.of<SyncService>(context, listen: false);
    final amount = double.parse(_amountController.text.trim());

    DebtModel debt;
    if (!_isEditing) {
      debt = DebtModel.create(
        userId: _userId!,
        personName: _nameController.text.trim(),
        amount: amount,
        type: _selectedType,
        debtDate: _debtDate,
        dueDate: _dueDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
    } else {
      debt = widget.debt!.copyWith(
        personName: _nameController.text.trim(),
        amount: amount,
        type: _selectedType,
        debtDate: _debtDate,
        dueDate: _dueDate,
        paidDate: _isPaid ? (_paidDate ?? DateTime.now()) : null,
        isPaid: _isPaid,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isSynced: false,
      );
    }

    try {
      if (!_isEditing) {
        await syncService.addDebt(debt);
      } else {
        await syncService.updateDebt(debt);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
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
        backgroundColor: AppTheme.cardBackground,
        title: const Text('حذف السجل'),
        content: const Text('هل أنت متأكد من حذف هذا الدين؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
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
        title: Text(_isEditing ? 'تعديل السجل' : 'إضافة سجل جديد'),
        actions: [
          if (_isEditing)
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
              // Type Selector Header
              const Text(
                'نوع السجل',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildTypeSelector().animate().fadeIn(delay: 100.ms),
              
              const SizedBox(height: 24),
              
              // Person Name
              _buildSectionTitle('اسم الشخص'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hint: 'أدخل اسم الشخص',
                icon: Iconsax.user,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال اسم الشخص';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 150.ms),
              
              const SizedBox(height: 20),
              
              // Amount
              _buildSectionTitle('المبلغ'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _amountController,
                hint: '0.00',
                icon: Iconsax.money_2,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال المبلغ';
                  }
                  if (double.tryParse(value.trim()) == null || double.parse(value.trim()) <= 0) {
                    return 'يرجى إدخال مبلغ صحيح';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 24),
              
              // Dates Section
              _buildSectionTitle('التواريخ'),
              const SizedBox(height: 12),
              
              _buildDateRow(
                label: 'تاريخ الدين',
                date: _debtDate,
                icon: Iconsax.calendar_1,
                color: AppTheme.primaryColor,
                onTap: () => _pickDate(isDebtDate: true, isDueDate: false, isPaidDate: false),
              ).animate().fadeIn(delay: 250.ms),
              
              const SizedBox(height: 12),
              
              _buildDateRow(
                label: 'تاريخ الاستحقاق (اختياري)',
                date: _dueDate,
                icon: Iconsax.timer_1,
                color: AppTheme.accentOrange,
                onTap: () => _pickDate(isDebtDate: false, isDueDate: true, isPaidDate: false),
                isClearable: true,
                onClear: () => setState(() => _dueDate = null),
              ).animate().fadeIn(delay: 300.ms),
              
              const SizedBox(height: 24),
              
              // Paid Status
              _buildPaidToggle().animate().fadeIn(delay: 350.ms),
              
              if (_isPaid) ...[
                const SizedBox(height: 12),
                _buildDateRow(
                  label: 'تاريخ السداد',
                  date: _paidDate ?? DateTime.now(),
                  icon: Icons.check_circle_outline,
                  color: AppTheme.secondaryColor,
                  onTap: () => _pickDate(isDebtDate: false, isDueDate: false, isPaidDate: true),
                ).animate().fadeIn(),
              ],
              
              const SizedBox(height: 24),
              
              // Notes
              _buildSectionTitle('ملاحظات (اختياري)'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _notesController,
                hint: 'أضف ملاحظات إن وجدت...',
                icon: Iconsax.note,
                maxLines: 3,
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: 40),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType == DebtType.credit
                        ? AppTheme.secondaryColor
                        : AppTheme.accentRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isEditing ? Iconsax.edit : Iconsax.add_circle,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isEditing ? 'حفظ التعديلات' : 'إضافة السجل',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _buildTypeButton(DebtType.credit)),
          Expanded(child: _buildTypeButton(DebtType.debt)),
        ],
      ),
    );
  }

  Widget _buildTypeButton(DebtType type) {
    final isSelected = _selectedType == type;
    final color = type == DebtType.credit ? AppTheme.secondaryColor : AppTheme.accentRed;
    final icon = type == DebtType.credit ? Iconsax.arrow_down_2 : Iconsax.arrow_up_1;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textMuted, size: 20),
            const SizedBox(width: 8),
            Text(
              type.arabicName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppTheme.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
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
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true,
        fillColor: AppTheme.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.accentRed),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isClearable = false,
    VoidCallback? onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date != null
                            ? DateFormat('dd MMMM yyyy', 'ar').format(date)
                            : 'لم يحدد',
                        style: TextStyle(
                          fontSize: 14,
                          color: date != null ? Colors.white : AppTheme.textMuted,
                          fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isClearable && date != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, color: AppTheme.accentRed, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaidToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isPaid ? AppTheme.secondaryColor.withOpacity(0.1) : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isPaid ? AppTheme.secondaryColor : Colors.white.withOpacity(0.1),
        ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'حالة السداد',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isPaid ? 'تم السداد بالكامل' : 'لم يتم السداد بعد',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isPaid ? AppTheme.secondaryColor : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
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
