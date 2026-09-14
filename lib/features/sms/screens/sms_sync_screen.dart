import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/router/app_router.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/sms/cubit/sms_cubit.dart';
import 'package:mizaan/features/sms/cubit/sms_state.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class SmsSyncScreen extends StatefulWidget {
  const SmsSyncScreen({super.key});

  @override
  State<SmsSyncScreen> createState() => _SmsSyncScreenState();
}

class _SmsSyncScreenState extends State<SmsSyncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  void _startScan() {
    final walletsState = context.read<WalletsCubit>().state;
    final wallets = walletsState is WalletsLoaded ? walletsState.wallets : <Wallet>[];
    context.read<SmsCubit>().scanSms(wallets: wallets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_unread_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('استيراد الحركات من الرسائل 📩'),
          ],
        ),
      ),
      body: BlocConsumer<SmsCubit, SmsState>(
        listener: (context, state) {
          if (state is SmsImportSuccess) {
            context.read<TransactionsCubit>().loadTransactions();
            context.read<WalletsCubit>().loadWallets();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Text('تم استيراد ${state.importedCount} حركات بنجاح! 🎉'),
                  ],
                ),
              ),
            );
            Navigator.pop(context);
          } else if (state is SmsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                content: Text(state.message),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is SmsPermissionRequired) {
            return _buildPermissionRequest();
          }

          if (state is SmsScanning || state is SmsImporting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 20),
                  Text(
                    state is SmsImporting
                        ? 'جاري حفظ الحركات في المحافظ...'
                        : 'جاري فحص رسائل المحافظ في صندوق الوارد...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          if (state is SmsLoaded) {
            if (state.items.isEmpty) {
              return _buildEmptyState();
            }
            return _buildCandidatesList(state);
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security_rounded,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'مزامنة حركات المحافظ تلقائياً',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'يتعرف ميزان تلقائياً على رسائل البنوك والمحافظ اليمنية (الكريمي، جيب، كاش، محفظتي، جوالي) لتسجيل مصاريفك وإيداعاتك بضغطة واحدة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: Colors.blue.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🔒 خصوصيتك خط أحمر: نقرأ رسائل المحافظ فقط لتسجيل حركاتك تلقائياً — رسائلك الشخصية لا تُقرأ أبداً وتبقى بياناتك على جهازك فقط.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'منح الإذن وبدء الفحص',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _startScan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mark_email_read_rounded, size: 64, color: Colors.green.shade700),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد رسائل جديدة غير مستوردة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'تمت مزامنة جميع رسائل المحافظ السابقة أو لم تصل رسائل جديدة مؤخراً.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة الفحص'),
              onPressed: _startScan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesList(SmsLoaded state) {
    final walletsState = context.watch<WalletsCubit>().state;
    final wallets = walletsState is WalletsLoaded ? walletsState.wallets : <Wallet>[];
    final allSelected = state.items.every((i) => i.isSelected);

    return Column(
      children: [
        // Top action bar: Select All + Count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          color: Theme.of(context).cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تم العثور على ${state.items.length} حركة جديدة',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: Icon(
                  allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                label: Text(
                  allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
                onPressed: () => context.read<SmsCubit>().toggleSelectAll(!allSelected),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Banner if user has no wallets added yet
        if (wallets.isEmpty)
          Container(
            margin: const EdgeInsets.all(12.0),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'يجب إضافة محفظة واحدة على الأقل لربط الحركات بها.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.addWallet),
                  child: const Text('إضافة محفظة', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        // List of candidate transactions
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              final isExpense = item.data.type == 'expense';

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.6)
                        : Colors.grey.withValues(alpha: 0.2),
                    width: item.isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: item.isSelected,
                            activeColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            onChanged: (_) => context.read<SmsCubit>().toggleSelect(index),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isExpense
                                  ? Colors.red.withValues(alpha: 0.12)
                                  : Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isExpense ? 'خصم / سداد' : 'إيداع / استلام',
                              style: TextStyle(
                                color: isExpense ? Colors.red.shade800 : Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Category chip
                          Chip(
                            label: Text(
                              item.data.category,
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                          const Spacer(),
                          Text(
                            AppConstants.formatCurrency(item.data.amount),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Assigned Wallet Picker
                      Padding(
                        padding: const EdgeInsets.only(right: 48.0, left: 8.0),
                        child: Row(
                          children: [
                            const Text('المحفظة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: item.targetWalletId,
                                underline: const SizedBox.shrink(),
                                hint: const Text('اختر المحفظة', style: TextStyle(fontSize: 13)),
                                items: wallets.map((w) {
                                  return DropdownMenuItem<String>(
                                    value: w.id,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 10,
                                          backgroundColor: Color(w.colorValue),
                                          child: Icon(
                                            AppConstants.getWalletIcon(w.iconCodePoint),
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(w.name, style: const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    context.read<SmsCubit>().setTargetWallet(index, val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Date & sender
                      Padding(
                        padding: const EdgeInsets.only(right: 48.0, left: 8.0, top: 4.0),
                        child: Row(
                          children: [
                            Text(
                              '${AppConstants.formatDate(item.data.date)}  ${AppConstants.formatTime(item.data.date)}  •  ${item.data.rawSender}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const Spacer(),
                            const Text('📩', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Sticky Bottom Confirm Button
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.download_done_rounded),
                label: Text(
                  wallets.isEmpty
                      ? 'يرجى إضافة محفظة أولاً'
                      : 'استيراد الحركات المحددة (${state.selectedCount}) 📥',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: (state.selectedCount == 0 || wallets.isEmpty)
                    ? null
                    : () => context.read<SmsCubit>().importSelected(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
