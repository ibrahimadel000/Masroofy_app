import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? initialWalletId;

  const AddTransactionScreen({super.key, this.initialWalletId});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedType = 'expense'; // 'expense' or 'income'
  String? _selectedWalletId;
  String _selectedCategory = AppConstants.categories[0];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submitTransaction(List<Wallet> wallets) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المحفظة أولاً')),
      );
      return;
    }

    final selectedWallet = wallets.firstWhere((w) => w.id == _selectedWalletId);
    final allTransactions = context.read<TransactionsCubit>().state is TransactionsLoaded
        ? (context.read<TransactionsCubit>().state as TransactionsLoaded).transactions
        : <TransactionModel>[];
    final walletTransactions =
        allTransactions.where((tx) => tx.walletId == selectedWallet.id).toList();

    final currentBalance = BalanceCalculator.calculateWalletBalance(
      openingBalance: selectedWallet.openingBalance,
      transactions: walletTransactions,
    );

    // If expense exceeds wallet balance -> show warning dialog with override option
    if (_selectedType == 'expense' && amount > currentBalance) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('تنبيه تجاوز الرصيد', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Text(
            'مبلغ الصرف (${AppConstants.formatCurrency(amount)}) يتجاوز رصيد محفظة "${selectedWallet.name}" الحالي (${AppConstants.formatCurrency(currentBalance)})!\n\nهل ترغب في تسجيل الحركة على أية حال؟',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تعديل المبلغ', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeSave(amount);
              },
              child: const Text('المتابعة على كل حال'),
            ),
          ],
        ),
      );
    } else {
      _executeSave(amount);
    }
  }

  void _executeSave(double amount) {
    context.read<TransactionsCubit>().addTransaction(
          walletId: _selectedWalletId!,
          type: _selectedType,
          amount: amount,
          category: _selectedCategory,
          note: _noteController.text.isEmpty ? null : _noteController.text.trim(),
          date: _selectedDate,
          source: 'manual',
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل حركة مالية'),
      ),
      body: BlocBuilder<WalletsCubit, WalletsState>(
        builder: (context, walletsState) {
          final wallets = walletsState is WalletsLoaded ? walletsState.wallets : <Wallet>[];

          if (wallets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wallet_rounded, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد محافظ مسجلة بعد',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يرجى إضافة محفظة واحدة على الأقل قبل تسجيل الحركات المالية',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('العودة'),
                    ),
                  ],
                ),
              ),
            );
          }

          _selectedWalletId ??= wallets.first.id;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Income / Expense Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedType = 'expense'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedType == 'expense'
                                      ? Colors.red.shade700
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'صرف (مصروف)',
                                  style: TextStyle(
                                    color: _selectedType == 'expense'
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedType = 'income'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedType == 'income'
                                      ? AppTheme.primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'دخل (إيداع)',
                                  style: TextStyle(
                                    color: _selectedType == 'income'
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'يرجى إدخال المبلغ';
                        }
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'يرجى إدخال مبلغ صحيح أكبر من الصفر';
                        }
                        return null;
                      },
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'المبلغ',
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                        suffixText: 'ر.ي',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Wallet Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedWalletId,
                      items: wallets.map((w) {
                        return DropdownMenuItem<String>(
                          value: w.id,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Color(w.colorValue),
                                child: Icon(
                                  AppConstants.getWalletIcon(w.iconCodePoint),
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(w.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedWalletId = val);
                      },
                      decoration: InputDecoration(
                        labelText: 'المحفظة المعنية',
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Category Chips
                    const Text(
                      'الفئة',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: AppConstants.categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          avatar: Icon(
                            AppConstants.getCategoryIcon(cat),
                            size: 18,
                            color: isSelected ? Colors.white : AppTheme.primaryColor,
                          ),
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedCategory = cat);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Note Field
                    TextFormField(
                      controller: _noteController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'ملاحظة (اختياري)',
                        hintText: 'تفاصيل إضافية عن الحركة',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date Picker
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text(
                              'التاريخ: ${AppConstants.formatDate(_selectedDate)}',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: () => _submitTransaction(wallets),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedType == 'expense'
                            ? Colors.red.shade700
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        _selectedType == 'expense' ? 'تسجيل المصروف' : 'تسجيل الدخل',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
