import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/transactions/screens/add_transaction_screen.dart';
import 'package:mizaan/features/transactions/widgets/transaction_detail_sheet.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  final bool isEmbedded;
  final String? initialWalletId;

  const TransactionsHistoryScreen({
    super.key,
    this.isEmbedded = false,
    this.initialWalletId,
  });

  @override
  State<TransactionsHistoryScreen> createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends State<TransactionsHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedTypeFilter = 'all'; // 'all' | 'expense' | 'income' | 'adjustment'
  String _selectedSourceFilter = 'all'; // 'all' | 'sms' | 'manual'
  String? _selectedWalletId;
  String _selectedDateRange = 'all'; // 'all' | 'today' | 'week' | 'month'

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> allTx) {
    return allTx.where((tx) {
      // 1. Search Query (note, category, amount)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCategory = tx.category.toLowerCase().contains(q);
        final matchNote = (tx.note ?? '').toLowerCase().contains(q);
        final matchAmount = tx.amount.toString().contains(q);
        if (!matchCategory && !matchNote && !matchAmount) {
          return false;
        }
      }

      // 2. Type Filter
      if (_selectedTypeFilter != 'all' && tx.type != _selectedTypeFilter) {
        return false;
      }

      // 3. Source Filter
      if (_selectedSourceFilter != 'all' && tx.source != _selectedSourceFilter) {
        return false;
      }

      // 4. Wallet Filter
      if (_selectedWalletId != null && tx.walletId != _selectedWalletId) {
        return false;
      }

      // 5. Date Range Filter
      final now = DateTime.now();
      if (_selectedDateRange == 'today') {
        final start = DateTime(now.year, now.month, now.day);
        if (tx.date.isBefore(start)) return false;
      } else if (_selectedDateRange == 'week') {
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        if (tx.date.isBefore(start)) return false;
      } else if (_selectedDateRange == 'month') {
        final start = DateTime(now.year, now.month, 1);
        if (tx.date.isBefore(start)) return false;
      }

      return true;
    }).toList();
  }

  Map<String, List<TransactionModel>> _groupTransactionsByDate(List<TransactionModel> list) {
    final Map<String, List<TransactionModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final tx in list) {
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
      String dateKey;
      if (txDate == today) {
        dateKey = 'اليوم';
      } else if (txDate == yesterday) {
        dateKey = 'أمس';
      } else {
        dateKey = AppConstants.formatDate(tx.date);
      }

      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final body = BlocBuilder<TransactionsCubit, TransactionsState>(
      builder: (context, txState) {
        final allTransactions =
            txState is TransactionsLoaded ? txState.transactions : <TransactionModel>[];

        return BlocBuilder<WalletsCubit, WalletsState>(
          builder: (context, walletsState) {
            final wallets = walletsState is WalletsLoaded ? walletsState.wallets : <Wallet>[];
            final filtered = _filterTransactions(allTransactions);

            // Compute summary metrics for filtered list
            double totalIncome = 0;
            double totalExpense = 0;
            for (final tx in filtered) {
              if (tx.type == 'income') {
                totalIncome += tx.amount;
              } else if (tx.type == 'expense') {
                totalExpense += tx.amount;
              }
            }

            return Column(
              children: [
                // Top Search & Filter Bar
                _buildSearchAndFiltersHeader(wallets),

                // Metrics Summary Strip for the filtered results
                if (filtered.isNotEmpty) _buildSummaryStrip(filtered.length, totalIncome, totalExpense),

                // Transaction Groups List
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(allTransactions.isEmpty)
                      : RefreshIndicator(
                          onRefresh: () async {
                            context.read<TransactionsCubit>().loadTransactions();
                            context.read<WalletsCubit>().loadWallets();
                          },
                          child: _buildGroupedList(filtered, wallets),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الحركات المالية'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('➕ إضافة حركة'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
        },
      ),
      body: body,
    );
  }

  Widget _buildSearchAndFiltersHeader(List<Wallet> wallets) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.only(top: 8, bottom: 10, left: 16, right: 16),
      child: Column(
        children: [
          // Search TextField
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'ابحث في الفئات، الملاحظات، أو المبالغ...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Type Filter: All / Expense / Income / Adjustment
                _buildFilterChip(
                  label: 'الكل',
                  isSelected: _selectedTypeFilter == 'all',
                  onSelected: () => setState(() => _selectedTypeFilter = 'all'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'مصروفات 🔴',
                  isSelected: _selectedTypeFilter == 'expense',
                  onSelected: () => setState(() => _selectedTypeFilter = 'expense'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'إيرادات 🟢',
                  isSelected: _selectedTypeFilter == 'income',
                  onSelected: () => setState(() => _selectedTypeFilter = 'income'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'رسائل SMS 📩',
                  isSelected: _selectedSourceFilter == 'sms',
                  onSelected: () => setState(() {
                    _selectedSourceFilter = _selectedSourceFilter == 'sms' ? 'all' : 'sms';
                  }),
                ),
                const SizedBox(width: 6),

                // Date Range Toggle
                DropdownButton<String>(
                  value: _selectedDateRange,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primaryColor),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('كل الفترات')),
                    DropdownMenuItem(value: 'today', child: Text('اليوم فقط')),
                    DropdownMenuItem(value: 'week', child: Text('آخر 7 أيام')),
                    DropdownMenuItem(value: 'month', child: Text('هذا الشهر')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDateRange = val);
                  },
                ),

                // Wallet Filter if multiple wallets exist
                if (wallets.length > 1) ...[
                  const SizedBox(width: 6),
                  DropdownButton<String?>(
                    value: _selectedWalletId,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.account_balance_wallet_rounded,
                        size: 18, color: AppTheme.primaryColor),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('كل المحافظ')),
                      ...wallets.map(
                        (w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedWalletId = val),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildSummaryStrip(int count, double totalIn, double totalOut) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.primaryColor.withValues(alpha: 0.06),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count حركة مطابقة',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          Row(
            children: [
              if (totalIn > 0) ...[
                Text(
                  '+${AppConstants.formatCurrency(totalIn)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (totalOut > 0)
                Text(
                  '-${AppConstants.formatCurrency(totalOut)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<TransactionModel> filtered, List<Wallet> wallets) {
    final grouped = _groupTransactionsByDate(filtered);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 4),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final txList = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateKey,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Transactions for this day
            ...txList.map((tx) {
              final wallet = wallets.cast<Wallet?>().firstWhere(
                    (w) => w?.id == tx.walletId,
                    orElse: () => null,
                  );

              final isIncome = tx.type == 'income';
              final isAdjustment = tx.type == 'adjustment';

              final Color amountColor = isIncome
                  ? AppTheme.primaryColor
                  : isAdjustment
                      ? Colors.blue.shade700
                      : Colors.red.shade700;
              final String prefix = isIncome
                  ? '+'
                  : isAdjustment
                      ? (tx.amount >= 0 ? '+' : '')
                      : '-';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  onTap: () => TransactionDetailSheet.show(context, tx),
                  leading: CircleAvatar(
                    backgroundColor: amountColor.withValues(alpha: 0.12),
                    child: Icon(
                      AppConstants.getCategoryIcon(tx.category),
                      color: amountColor,
                      size: 22,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        tx.category,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (tx.source == 'sms') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('📩', style: TextStyle(fontSize: 10)),
                              SizedBox(width: 2),
                              Text(
                                'SMS',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${wallet?.name ?? "محفظة"} • ${AppConstants.formatTime(tx.date)}${tx.note != null && tx.note!.isNotEmpty ? " • ${tx.note}" : ""}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '$prefix${AppConstants.formatCurrency(tx.amount.abs())}',
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(bool noDataAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noDataAtAll ? Icons.receipt_long_outlined : Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              noDataAtAll ? 'لا توجد حركات مسجلة بعد' : 'لا توجد نتائج تطابق خيارات البحث أو التصفية',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              noDataAtAll
                  ? 'سجّل حركاتك النقدية أو استورد رسائل البنوك والمحافظ لتراها هنا.'
                  : 'جرب تعديل كلمات البحث أو إلغاء فلاتر التصفية لعرض الحركات.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (!noDataAtAll) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedTypeFilter = 'all';
                    _selectedSourceFilter = 'all';
                    _selectedWalletId = null;
                    _selectedDateRange = 'all';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة ضبط الفلاتر'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
