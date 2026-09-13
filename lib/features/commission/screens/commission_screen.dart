import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class WalletRateInfo {
  final String name;
  double feePercentage;
  double minFee;

  WalletRateInfo({
    required this.name,
    required this.feePercentage,
    required this.minFee,
  });
}

class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  final NumberFormat _fmt = NumberFormat('#,##0.##', 'ar');
  final TextEditingController _amountController = TextEditingController(text: '10000');

  final List<WalletRateInfo> _rates = [
    WalletRateInfo(name: 'الكريمي (كريمي كاش)', feePercentage: 0.5, minFee: 100),
    WalletRateInfo(name: 'محفظة جيب (التضامن)', feePercentage: 1.0, minFee: 100),
    WalletRateInfo(name: 'محفظة كاش (MTN/يو)', feePercentage: 1.0, minFee: 150),
    WalletRateInfo(name: 'محفظتي (بنك اليمن والكويت)', feePercentage: 1.5, minFee: 150),
    WalletRateInfo(name: 'جوالي (يمن موبايل)', feePercentage: 1.5, minFee: 150),
    WalletRateInfo(name: 'ون كاش (OneCash)', feePercentage: 1.2, minFee: 100),
    WalletRateInfo(name: 'فلوسك (بنك اليمن والبحرين)', feePercentage: 1.0, minFee: 100),
  ];

  late WalletRateInfo _selectedFromWallet;
  late WalletRateInfo _selectedToWallet;
  bool _senderPaysFee = true; // true: sender pays fee on top; false: fee deducted from transfer

  @override
  void initState() {
    super.initState();
    _selectedFromWallet = _rates[0];
    _selectedToWallet = _rates[1];
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _currentAmount {
    return double.tryParse(_amountController.text.trim()) ?? 0.0;
  }

  double get _feeAmount {
    final amount = _currentAmount;
    if (amount <= 0) return 0.0;
    final computed = amount * (_selectedFromWallet.feePercentage / 100.0);
    return computed < _selectedFromWallet.minFee ? _selectedFromWallet.minFee : computed;
  }

  double get _totalDeducted {
    final amount = _currentAmount;
    if (amount <= 0) return 0.0;
    return _senderPaysFee ? (amount + _feeAmount) : amount;
  }

  double get _netReceived {
    final amount = _currentAmount;
    if (amount <= 0) return 0.0;
    return _senderPaysFee ? amount : (amount - _feeAmount);
  }

  void _editFeeDialog() {
    final controller = TextEditingController(
      text: _selectedFromWallet.feePercentage.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل نسبة عمولة ${_selectedFromWallet.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل النسبة المئوية المعتمدة للتحويل من هذه المحفظة:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'نسبة العمولة (%)',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              final newFee = double.tryParse(controller.text.trim());
              if (newFee != null && newFee >= 0) {
                setState(() {
                  _selectedFromWallet.feePercentage = newFee;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _recordAsTransaction() async {
    final walletsState = context.read<WalletsCubit>().state;
    final wallets = walletsState is WalletsLoaded ? walletsState.wallets : <Wallet>[];

    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد لديك محافظ مسجلة لحفظ الحركة فيها')),
      );
      return;
    }

    // Pick wallet to record in
    final selectedWallet = await showDialog<Wallet>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر المحفظة لخصم المبلغ'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: wallets.length,
            itemBuilder: (ctx, i) {
              final w = wallets[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(w.colorValue),
                  child: Icon(AppConstants.getWalletIcon(w.iconCodePoint), color: Colors.white, size: 20),
                ),
                title: Text(w.name),
                onTap: () => Navigator.pop(ctx, w),
              );
            },
          ),
        ),
      ),
    );

    if (selectedWallet != null && mounted) {
      await context.read<TransactionsCubit>().addTransaction(
            walletId: selectedWallet.id,
            type: 'expense',
            amount: _totalDeducted,
            category: 'تحويل',
            note: 'تحويل إلى ${_selectedToWallet.name} (عمولة: ${_fmt.format(_feeAmount)} ر.ي)',
            date: DateTime.now(),
            source: 'manual',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryColor,
            content: Text('تم تسجيل حركة تحويل بمبلغ ${_fmt.format(_totalDeducted)} ر.ي بنجاح!'),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حاسبة عمولات المحافظ'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wallets Selection Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // From Wallet
                  Row(
                    children: [
                      const Icon(Icons.outbox_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text(
                        'من محفظة:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<WalletRateInfo>(
                          isExpanded: true,
                          value: _selectedFromWallet,
                          items: _rates.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text(
                                '${r.name} (${r.feePercentage}%)',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedFromWallet = val);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'تعديل نسبة العمولة',
                        onPressed: _editFeeDialog,
                      ),
                    ],
                  ),
                  const Divider(),
                  // To Wallet
                  Row(
                    children: [
                      const Icon(Icons.move_to_inbox_rounded, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'إلى محفظة:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<WalletRateInfo>(
                          isExpanded: true,
                          value: _selectedToWallet,
                          items: _rates.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text(
                                r.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedToWallet = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المبلغ المراد تحويله',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppTheme.primaryColor),
                      suffixText: 'ر.ي',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quick Amount Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5000, 10000, 25000, 50000, 100000].map((amt) {
                      return ActionChip(
                        label: Text('${_fmt.format(amt)} ر.ي', style: const TextStyle(fontSize: 11)),
                        backgroundColor: _currentAmount == amt.toDouble()
                            ? AppTheme.primaryColor.withValues(alpha: 0.2)
                            : null,
                        onPressed: () {
                          setState(() {
                            _amountController.text = amt.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Fee Mode Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryColor,
                title: const Text(
                  'المرسل يتحمل العمولة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _senderPaysFee
                      ? 'يصل كامل المبلغ للمستلم (${_fmt.format(_currentAmount)} ر.ي) وتُضاف العمولة على المرسل'
                      : 'تُخصم العمولة من المبلغ المحول ويصل المستلم الصافي',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _senderPaysFee,
                onChanged: (val) => setState(() => _senderPaysFee = val),
              ),
            ),
            const SizedBox(height: 20),

            // Calculation Results Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    Colors.teal.shade900,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildResultRow('نسبة العمولة', '${_selectedFromWallet.feePercentage}% (حد أدنى ${_fmt.format(_selectedFromWallet.minFee)} ر.ي)', Colors.white70),
                  const Divider(color: Colors.white24, height: 20),
                  _buildResultRow('مبلغ العمولة', '${_fmt.format(_feeAmount)} ر.ي', Colors.amber),
                  const Divider(color: Colors.white24, height: 20),
                  _buildResultRow(
                    'المبلغ الإجمالي المخصوم',
                    '${_fmt.format(_totalDeducted)} ر.ي',
                    Colors.white,
                    isBold: true,
                    fontSize: 16,
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  _buildResultRow(
                    'صافي المبلغ الواصل للمستلم',
                    '${_fmt.format(_netReceived)} ر.ي',
                    Colors.lightGreenAccent,
                    isBold: true,
                    fontSize: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Record Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _currentAmount > 0 ? _recordAsTransaction : null,
              icon: const Icon(Icons.bookmark_add_rounded),
              label: const Text(
                'تسجيل كحركة في محفظتي',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor, {bool isBold = false, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
