import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/debt_model.dart';
import '../../services/sync_service.dart';
import '../../services/supabase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    setState(() => _isLoading = true);
    final syncService = Provider.of<SyncService>(context, listen: false);
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    final user = supabase.currentUser;
    
    if (user != null) {
      final debts = await syncService.getDebts(user.id);
      setState(() {
        _debts = debts;
        _isLoading = false;
      });
    } else {
       setState(() => _isLoading = false);
    }
  }

  double _getTotalAmount(DebtType type) {
    return _debts
        .where((d) => d.type == type && !d.isPaid)
        .fold(0, (sum, d) => sum + d.amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.darkTheme;
    
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('مدير الديون'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'ديون لي (Credit)'),
            Tab(text: 'ديون علي (Debt)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCards(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDebtScreen()),
          );
          if (result == true) _loadDebts();
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final creditTotal = _getTotalAmount(DebtType.credit);
    final debtTotal = _getTotalAmount(DebtType.debt);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              'إجمالي لي',
              creditTotal,
              AppTheme.secondaryColor,
              Iconsax.arrow_down_1,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryItem(
              'إجمالي علي',
              debtTotal,
              AppTheme.accentRed,
              Iconsax.arrow_up_3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color, IconData icon) {
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
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtList(DebtType type) {
    final filteredDebts = _debts.where((d) => d.type == type).toList();

    if (filteredDebts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.document_text, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('لا يوجد سجلات هنا بعد', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredDebts.length,
      itemBuilder: (context, index) {
        final debt = filteredDebts[index];
        return _buildDebtCard(debt);
      },
    );
  }

  Widget _buildDebtCard(DebtModel debt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  Text(
                    debt.personName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${debt.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: debt.isPaid ? AppTheme.textMuted : (debt.type == DebtType.credit ? AppTheme.secondaryColor : AppTheme.accentRed),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Iconsax.calendar, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'تاريخ الدين: ${DateFormat('yyyy-MM-dd').format(debt.debtDate)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              if (debt.dueDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Iconsax.timer_1, size: 14, color: AppTheme.accentOrange),
                    const SizedBox(width: 4),
                    Text(
                      'موعد السداد: ${DateFormat('yyyy-MM-dd').format(debt.dueDate!)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.accentOrange),
                    ),
                  ],
                ),
              ],
              if (debt.isPaid && debt.paidDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppTheme.secondaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'تم السداد في: ${DateFormat('yyyy-MM-dd').format(debt.paidDate!)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.secondaryColor),
                    ),
                  ],
                ),
              ],
              if (debt.notes != null && debt.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  debt.notes!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
