import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/core/utils/responsive.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/transactions/screens/add_transaction_screen.dart';
import 'package:mizaan/features/transactions/widgets/transaction_detail_sheet.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class WalletDetailsScreen extends StatelessWidget {
  final String walletId;

  const WalletDetailsScreen({super.key, required this.walletId});

  void _showDeleteConfirmation(BuildContext context, Wallet wallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد حذف المحفظة'),
        content: Text(
          'هل أنت متأكد من حذف محفظة "${wallet.name}"؟\nسيتم حذفها محلياً ومن السحابة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<WalletsCubit>().deleteWallet(wallet.id);
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showReconciliationDialog(BuildContext context, Wallet wallet, double currentBalance) {
    final controller = TextEditingController(text: currentBalance.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('تحديث الرصيد الفعلي', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل الرصيد الفعلي الحالي لمحفظتك (كما يظهر في تطبيق البنك أو رسائل SMS)، وسيتم إنشاء حركة تسوية تلقائياً للفارق:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'الرصيد الفعلي',
                suffixText: 'ر.ي',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newBalance = double.tryParse(controller.text.trim());
              if (newBalance != null) {
                final delta = newBalance - currentBalance;
                Navigator.pop(ctx);
                if (delta != 0) {
                  context.read<TransactionsCubit>().addTransaction(
                        walletId: wallet.id,
                        type: 'adjustment',
                        amount: delta,
                        category: 'أخرى',
                        note: 'تسوية وتحديث الرصيد الفعلي',
                        date: DateTime.now(),
                        source: 'adjustment',
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تمت تسوية الرصيد بفارق: ${AppConstants.formatCurrency(delta)}'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                }
              }
            },
            child: const Text('تأكيد التسوية'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletsCubit, WalletsState>(
      builder: (context, walletsState) {
        if (walletsState is! WalletsLoaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final wallet = walletsState.wallets.cast<Wallet?>().firstWhere(
              (w) => w?.id == walletId,
              orElse: () => null,
            );

        if (wallet == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل المحفظة')),
            body: const Center(child: Text('المحفظة غير موجودة أو تم حذفها')),
          );
        }

        final walletColor = Color(wallet.colorValue);

        return BlocBuilder<TransactionsCubit, TransactionsState>(
          builder: (context, txState) {
            final allTx = txState is TransactionsLoaded ? txState.transactions : <TransactionModel>[];
            final walletTransactions =
                allTx.where((tx) => tx.walletId == wallet.id).toList();

            final liveBalance = BalanceCalculator.calculateWalletBalance(
              openingBalance: wallet.openingBalance,
              transactions: walletTransactions,
            );

            return Scaffold(
              appBar: AppBar(
                title: Text(wallet.name),
                actions: [
                  IconButton(
                    icon: Icon(
                      wallet.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: wallet.isFavorite ? Colors.amber : null,
                      size: 28,
                    ),
                    tooltip: wallet.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                    onPressed: () => context.read<WalletsCubit>().toggleFavorite(wallet.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    tooltip: 'حذف المحفظة',
                    onPressed: () => _showDeleteConfirmation(context, wallet),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: walletColor,
                foregroundColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(initialWalletId: wallet.id),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('➕ حركة لهذه المحفظة'),
              ),
              body: SafeArea(
                child: ResponsiveConstraint(
                  maxWidth: 850,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                    // Wallet Balance Card
                    Container(
                      margin: const EdgeInsets.all(16.0),
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: walletColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: walletColor.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      AppConstants.getWalletIcon(wallet.iconCodePoint),
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        wallet.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${AppConstants.walletTypes[wallet.type] ?? "محفظة"} (${AppConstants.currencySymbols[wallet.currencyCode] ?? wallet.currencyCode})',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'الرصيد المحسوب الحالي',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              AppConstants.formatCurrency(liveBalance, wallet.currencyCode),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Reconciliation action button
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('تحديث الرصيد الفعلي (تسوية)'),
                            onPressed: () =>
                                _showReconciliationDialog(context, wallet, liveBalance),
                          ),
                        ],
                      ),
                    ),

                    // Section Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'سجل الحركات (${walletTransactions.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // Transactions List
                    Expanded(
                      child: walletTransactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 54,
                                    color: Colors.grey.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'لا توجد حركات مسجلة لهذه المحفظة بعد',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              itemCount: walletTransactions.length,
                              itemBuilder: (context, index) {
                                final tx = walletTransactions[index];
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
                                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
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
                                        Flexible(
                                          child: Text(
                                            tx.category,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (tx.source == 'sms') ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
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
                                       '${AppConstants.formatDate(tx.date)}  ${AppConstants.formatTime(tx.date)}${tx.note != null && tx.note!.isNotEmpty ? " • ${tx.note}" : ""}',
                                       style: const TextStyle(fontSize: 12),
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
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }
}
