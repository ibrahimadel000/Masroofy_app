import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/responsive.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/transactions/screens/add_transaction_screen.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class TransactionDetailSheet extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailSheet({super.key, required this.transaction});

  static Future<void> show(BuildContext context, TransactionModel transaction) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(transaction: transaction),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 8),
            Text('تأكيد حذف الحركة', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف حركة "${transaction.category}" بمبلغ ${AppConstants.formatCurrency(transaction.amount.abs())}؟\nسيتم تحديث رصيد المحفظة فوراً.',
          style: const TextStyle(fontSize: 14, height: 1.4),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close bottom sheet
              context.read<TransactionsCubit>().deleteTransaction(transaction.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تم حذف الحركة بنجاح (${AppConstants.formatCurrency(transaction.amount.abs())})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: const Text('حذف الحركة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final isAdjustment = transaction.type == 'adjustment';

    final Color amountColor = isIncome
        ? AppTheme.primaryColor
        : isAdjustment
            ? Colors.blue.shade700
            : Colors.red.shade700;

    final String prefix = isIncome
        ? '+'
        : isAdjustment
            ? (transaction.amount >= 0 ? '+' : '')
            : '-';

    // Look up wallet details
    final walletsState = context.read<WalletsCubit>().state;
    final wallets = walletsState is WalletsLoaded ? walletsState.wallets : <Wallet>[];
    final wallet = wallets.cast<Wallet?>().firstWhere(
          (w) => w?.id == transaction.walletId,
          orElse: () => null,
        );

    final walletColor = wallet != null ? Color(wallet.colorValue) : AppTheme.primaryColor;

    // Detect raw SMS content
    final bool isSms = transaction.source == 'sms';
    final String? smsBody = transaction.rawSmsBody ??
        (isSms && transaction.note != null && transaction.note!.isNotEmpty
            ? transaction.note
            : null);
    final String? smsSender = transaction.rawSmsSender;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: ResponsiveConstraint(
          maxWidth: 550,
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row with Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تفاصيل الحركة المالية',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: amountColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: amountColor.withValues(alpha: 0.15),
                      child: Icon(
                        AppConstants.getCategoryIcon(transaction.category),
                        color: amountColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$prefix${AppConstants.formatCurrency(transaction.amount.abs(), wallet?.currencyCode ?? 'YER')}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      transaction.category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSms
                            ? Colors.blue.shade50
                            : isAdjustment
                                ? Colors.purple.shade50
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSms
                              ? Colors.blue.shade200
                              : isAdjustment
                                  ? Colors.purple.shade200
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSms ? '📩' : (isAdjustment ? '⚖️' : '✍️'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSms
                                ? 'مستوردة من رسالة SMS بنكية'
                                : (isAdjustment ? 'حركة تسوية رصيد' : 'تسجيل يدوي'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSms
                                  ? Colors.blue.shade800
                                  : (isAdjustment ? Colors.purple.shade800 : Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Details Information Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    // Wallet row
                    ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: walletColor.withValues(alpha: 0.15),
                        child: Icon(
                          wallet != null
                              ? AppConstants.getWalletIcon(wallet.iconCodePoint)
                              : Icons.account_balance_wallet_rounded,
                          color: walletColor,
                          size: 20,
                        ),
                      ),
                      title: const Text('المحفظة', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Text(
                        wallet?.name ?? 'محفظة غير محددة',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      trailing: wallet != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: walletColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppConstants.walletTypes[wallet.type] ?? 'محفظة',
                                style: TextStyle(
                                  color: walletColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const Divider(height: 1),

                    // Date & Time row
                    ListTile(
                      leading: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.access_time_rounded, color: Colors.white, size: 20),
                      ),
                      title: const Text('التاريخ والوقت', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Text(
                        AppConstants.formatDateTime(transaction.date),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),

                    // Note row (if available and not just the raw sms duplicate)
                    if (transaction.note != null &&
                        transaction.note!.trim().isNotEmpty &&
                        transaction.note != smsBody) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.amber,
                          child: Icon(Icons.notes_rounded, color: Colors.white, size: 20),
                        ),
                        title: const Text('الملاحظة', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        subtitle: Text(
                          transaction.note!,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Original SMS Box (if SMS)
              if (smsBody != null && smsBody.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.mark_email_read_rounded, size: 18, color: Colors.blue.shade800),
                              const SizedBox(width: 8),
                              Text(
                                smsSender != null && smsSender.isNotEmpty
                                    ? 'نص رسالة الـ SMS الأصلية ($smsSender)'
                                    : 'نص رسالة الـ SMS الأصلية',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'نسخ نص الرسالة',
                            color: Colors.blue.shade800,
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: smsBody));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ نص رسالة SMS إلى الحافظة 📋'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        smsBody,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          height: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 5),
                          Text(
                            'وقت استلام الرسالة: ${AppConstants.formatTime(transaction.date)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Actions: Edit & Delete
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('حذف الحركة', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _confirmDelete(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('تعديل الحركة', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(context); // Close bottom sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTransactionScreen(transactionToEdit: transaction),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
