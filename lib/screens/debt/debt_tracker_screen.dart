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
import '../../services/connectivity_service.dart';
import 'add_debt_screen.dart';

class DebtTrackerScreen extends StatefulWidget {
  const DebtTrackerScreen({super.key});

  @override
  State<DebtTrackerScreen> createState() => _DebtTrackerScreenState();
}

class _DebtTrackerScreenState extends State<DebtTrackerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DebtModel> _debts = [];
  bool _isLoading = true;
  String? _userId;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    await _getUserId();
    await _loadDebts();
    _checkConnectivity();
  }

  Future<void> _getUserId() async {
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    final localStorage = Provider.of<LocalStorageService>(context, listen: false);
    
    // Try Supabase user first
    final user = supabase.currentUser;
    if (user != null) {
      _userId = user.id;
      return;
    }
    
    // Fallback to local session (guest user)
    final session = await localStorage.getUserSession();
    if (session != null) {
      _userId = session['user_id'] as String?;
    }
  }

  void _checkConnectivity() {
    final connectivity = Provider.of<ConnectivityService>(context, listen: false);
    setState(() {
      _isConnected = connectivity.isConnected;
    });
  }

  Future<void> _loadDebts() async {
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final syncService = Provider.of<SyncService>(context, listen: false);
      final debts = await syncService.getDebts(_userId!);
      setState(() {
        _debts = debts;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to direct local storage if sync service fails
      try {
        final localStorage = Provider.of<LocalStorageService>(context, listen: false);
        final debts = await localStorage.getDebts(_userId!);
        setState(() {
          _debts = debts;
          _isLoading = false;
        });
      } catch (e2) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _getTotalAmount(DebtType type, {bool paidOnly = false}) {
    return _debts
        .where((d) => d.type == type && (paidOnly ? d.isPaid : !d.isPaid))
        .fold(0, (sum, d) => sum + d.amount);
  }

  int _getCount(DebtType type, {bool paidOnly = false}) {
    return _debts.where((d) => d.type == type && (paidOnly ? d.isPaid : !d.isPaid)).length;
  }

  Future<void> _markAsPaid(DebtModel debt) async {
    final syncService = Provider.of<SyncService>(context, listen: false);
    final updatedDebt = debt.copyWith(
      isPaid: true,
      paidDate: DateTime.now(),
      isSynced: false,
    );
    await syncService.updateDebt(updatedDebt);
    await _loadDebts();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل سداد ${debt.personName}'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    }
  }

  Future<void> _deleteDebt(DebtModel debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('حذف السجل'),
        content: Text('هل أنت متأكد من حذف الدين الخاص بـ ${debt.personName}؟'),
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
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.deleteDebt(debt.id);
      await _loadDebts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('مدير الديون'),
        actions: [
          // Sync status indicator
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(
              _isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? AppTheme.secondaryColor : AppTheme.accentOrange,
              size: 20,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              icon: const Icon(Iconsax.arrow_down_2, size: 20),
              text: 'ديون لي (${_getCount(DebtType.credit)})',
            ),
            Tab(
              icon: const Icon(Iconsax.arrow_up_1, size: 20),
              text: 'ديون علي (${_getCount(DebtType.debt)})',
            ),
          ],
        ),
      ),
      body: _userId == null
          ? _buildNoUserMessage()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadDebts,
                  child: Column(
                    children: [
                      _buildSummaryCards().animate().fadeIn(duration: 300.ms),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDebtList(DebtType.credit),
                            _buildDebtList(DebtType.debt),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _userId != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final initialType = _tabController.index == 0 ? DebtType.credit : DebtType.debt;
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddDebtScreen(initialType: initialType)),
                );
                if (result == true) _loadDebts();
              },
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('إضافة', style: TextStyle(color: Colors.white)),
            ).animate().scale(delay: 200.ms)
          : null,
    );
  }

  Widget _buildNoUserMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.user_remove, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'يرجى تسجيل الدخول لاستخدام هذه الميزة',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final creditTotal = _getTotalAmount(DebtType.credit);
    final debtTotal = _getTotalAmount(DebtType.debt);
    final balance = creditTotal - debtTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'إجمالي لي',
                  amount: creditTotal,
                  icon: Iconsax.arrow_down_2,
                  color: AppTheme.secondaryColor,
                  subtitle: '${_getCount(DebtType.credit)} سجل',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'إجمالي علي',
                  amount: debtTotal,
                  icon: Iconsax.arrow_up_1,
                  color: AppTheme.accentRed,
                  subtitle: '${_getCount(DebtType.debt)} سجل',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Net balance card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: balance >= 0
                  ? const LinearGradient(colors: [Color(0xFF00D9A5), Color(0xFF10B981)])
                  : const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      balance >= 0 ? 'الرصيد لصالحك' : 'الرصيد عليك',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${balance.abs().toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  balance >= 0 ? Iconsax.chart_success : Iconsax.chart_fail,
                  color: Colors.white,
                  size: 40,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount.toStringAsFixed(2),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildDebtList(DebtType type) {
    final activeDebts = _debts.where((d) => d.type == type && !d.isPaid).toList();
    final paidDebts = _debts.where((d) => d.type == type && d.isPaid).toList();

    if (activeDebts.isEmpty && paidDebts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == DebtType.credit ? Iconsax.wallet_money : Iconsax.wallet_minus,
              size: 64,
              color: AppTheme.textMuted.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              type == DebtType.credit ? 'لا توجد ديون لك حالياً' : 'لا توجد ديون عليك حالياً',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeDebts.isNotEmpty) ...[
          _buildSectionHeader('نشطة', activeDebts.length, type == DebtType.credit ? AppTheme.secondaryColor : AppTheme.accentRed),
          ...activeDebts.map((d) => _buildDebtCard(d, type)).toList(),
        ],
        if (paidDebts.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('مسددة', paidDebts.length, AppTheme.textMuted),
          ...paidDebts.map((d) => _buildDebtCard(d, type, isPaidSection: true)).toList(),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(DebtModel debt, DebtType type, {bool isPaidSection = false}) {
    final color = type == DebtType.credit ? AppTheme.secondaryColor : AppTheme.accentRed;
    final isOverdue = debt.dueDate != null && debt.dueDate!.isBefore(DateTime.now()) && !debt.isPaid;

    return Dismissible(
      key: Key(debt.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete
          await _deleteDebt(debt);
          return false;
        } else if (direction == DismissDirection.startToEnd && !debt.isPaid) {
          // Mark as paid
          await _markAsPaid(debt);
          return false;
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('تم السداد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentRed,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isPaidSection ? AppTheme.cardBackground.withOpacity(0.5) : AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isOverdue
              ? const BorderSide(color: AppTheme.accentOrange, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddDebtScreen(debt: debt)),
            );
            if (result == true) _loadDebts();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            radius: 20,
                            child: Text(
                              debt.personName.isNotEmpty ? debt.personName[0].toUpperCase() : '?',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  debt.personName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: isPaidSection ? TextDecoration.lineThrough : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd MMM yyyy', 'ar').format(debt.debtDate),
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          debt.amount.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isPaidSection ? AppTheme.textMuted : color,
                            decoration: isPaidSection ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (!debt.isSynced)
                          const Icon(Icons.cloud_upload, size: 14, color: AppTheme.accentOrange),
                      ],
                    ),
                  ],
                ),
                if (debt.dueDate != null || debt.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (debt.dueDate != null)
                        _buildInfoChip(
                          icon: isOverdue ? Icons.warning_amber : Iconsax.timer_1,
                          label: 'استحقاق: ${DateFormat('dd/MM').format(debt.dueDate!)}',
                          color: isOverdue ? AppTheme.accentOrange : AppTheme.textMuted,
                        ),
                      if (debt.isPaid && debt.paidDate != null)
                        _buildInfoChip(
                          icon: Icons.check_circle,
                          label: 'سداد: ${DateFormat('dd/MM').format(debt.paidDate!)}',
                          color: AppTheme.secondaryColor,
                        ),
                    ],
                  ),
                ],
                if (debt.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    debt.notes!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
