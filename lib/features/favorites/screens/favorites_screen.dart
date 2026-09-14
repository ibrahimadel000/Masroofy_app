import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/transactions/screens/add_transaction_screen.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';
import 'package:mizaan/features/wallets/screens/wallet_details_screen.dart';
import 'package:mizaan/features/transactions/widgets/transaction_detail_sheet.dart';

class FavoritesScreen extends StatelessWidget {
  final bool isEmbedded;

  const FavoritesScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final content = BlocBuilder<WalletsCubit, WalletsState>(
      builder: (context, walletsState) {
        final wallets = walletsState is WalletsLoaded ? walletsState.wallets : <Wallet>[];
        final favorites = wallets.where((w) => w.isFavorite).toList();

        return BlocBuilder<TransactionsCubit, TransactionsState>(
          builder: (context, txState) {
            final transactions =
                txState is TransactionsLoaded ? txState.transactions : <TransactionModel>[];

            if (favorites.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 72,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'لا توجد محافظ في المفضلة بعد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'اضغط على رمز النجمة ⭐ في بطاقة أي محفظة لتثبيتها هنا للوصول السريع إلى حركاتها وتفاصيلها.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final wallet = favorites[index];
                final walletColor = Color(wallet.colorValue);
                final walletTxs = transactions.where((tx) => tx.walletId == wallet.id).toList();
                final liveBalance = BalanceCalculator.calculateWalletBalance(
                  openingBalance: wallet.openingBalance,
                  transactions: walletTxs,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: walletColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header card with wallet info
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              walletColor,
                              walletColor.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white24,
                              radius: 24,
                              child: Icon(
                                AppConstants.getWalletIcon(wallet.iconCodePoint),
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wallet.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppConstants.walletTypes[wallet.type] ?? 'محفظة',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                              tooltip: 'إزالة من المفضلة',
                              onPressed: () {
                                context.read<WalletsCubit>().toggleFavorite(wallet.id);
                              },
                            ),
                          ],
                        ),
                      ),

                      // Balance & Quick Actions
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'الرصيد المتاح:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  AppConstants.formatCurrency(liveBalance, wallet.currencyCode),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: liveBalance >= 0 ? AppTheme.primaryColor : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // Quick Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('➕ حركة'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AddTransactionScreen(initialWalletId: wallet.id),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: walletColor,
                                      side: BorderSide(color: walletColor, width: 1.2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                                    label: const Text('تفاصيل'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => WalletDetailsScreen(walletId: wallet.id),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // Enriched: Latest transactions in this favorite wallet
                            if (walletTxs.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              ...walletTxs.take(2).map((tx) {
                                final isIncome = tx.type == 'income';
                                final isAdj = tx.type == 'adjustment';
                                final clr = isIncome
                                    ? AppTheme.primaryColor
                                    : isAdj
                                        ? Colors.blue.shade700
                                        : Colors.red.shade700;
                                final pfx = isIncome ? '+' : isAdj ? (tx.amount >= 0 ? '+' : '') : '-';

                                return InkWell(
                                  onTap: () => TransactionDetailSheet.show(context, tx),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          AppConstants.getCategoryIcon(tx.category),
                                          size: 16,
                                          color: clr,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                            child: Text(
                                              '${tx.category} • ${AppConstants.formatDate(tx.date)}  ${AppConstants.formatTime(tx.date)}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ),
                                        Text(
                                          '$pfx${AppConstants.formatCurrency(tx.amount.abs())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: clr,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('المفضلة ⭐'),
      ),
      body: content,
    );
  }
}
