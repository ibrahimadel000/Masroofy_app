import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/core/utils/responsive.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';
import 'package:mizaan/features/wallets/screens/add_wallet_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? initialWalletId;
  final TransactionModel? transactionToEdit;

  const AddTransactionScreen({
    super.key,
    this.initialWalletId,
    this.transactionToEdit,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _customCategoryController = TextEditingController();

  String _selectedType = 'expense'; // 'expense' or 'income'
  String? _selectedWalletId;
  String _selectedCategory = AppConstants.categories[0];
  DateTime _selectedDate = DateTime.now();
  bool get _isEditing => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final tx = widget.transactionToEdit!;
      _selectedType = tx.type == 'adjustment' ? 'expense' : tx.type;
      _selectedWalletId = tx.walletId;
      _selectedDate = tx.date;
      final amt = tx.amount.abs();
      _amountController.text = amt % 1 == 0
          ? amt.toInt().toString()
          : amt.toString();
      if (AppConstants.categories.contains(tx.category)) {
        _selectedCategory = tx.category;
      } else {
        _selectedCategory = 'أخرى';
        _customCategoryController.text = tx.category;
      }
      _noteController.text = tx.note ?? '';
    } else {
      _selectedWalletId = widget.initialWalletId;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  String _normalizeNumber(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String res = input.replaceAll(',', '').replaceAll(' ', '').trim();
    for (int i = 0; i < arabic.length; i++) {
      res = res.replaceAll(arabic[i], english[i]);
    }
    return res;
  }

  void _addQuickAmount(double value) {
    final currentStr = _normalizeNumber(_amountController.text);
    final current = double.tryParse(currentStr) ?? 0.0;
    final updated = current + value;
    setState(() {
      _amountController.text = updated % 1 == 0
          ? updated.toInt().toString()
          : updated.toString();
    });
  }

  Future<void> _pickDate() async {
    try {
      final now = DateTime.now();
      DateTime tempDate = _selectedDate;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (modalContext, setModalState) {
              final isToday =
                  tempDate.year == now.year &&
                  tempDate.month == now.month &&
                  tempDate.day == now.day;
              final isYesterday =
                  tempDate.year == now.subtract(const Duration(days: 1)).year &&
                  tempDate.month ==
                      now.subtract(const Duration(days: 1)).month &&
                  tempDate.day == now.subtract(const Duration(days: 1)).day;
              final isDayBefore =
                  tempDate.year == now.subtract(const Duration(days: 2)).year &&
                  tempDate.month ==
                      now.subtract(const Duration(days: 2)).month &&
                  tempDate.day == now.subtract(const Duration(days: 2)).day;

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.event_note_rounded,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'تحديد تاريخ ووقت الحركة',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Quick Date Chips
                      const Text(
                        'اختصارات سريعة للتاريخ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                            label: const Text('الآن فوراً'),
                            onPressed: () {
                              setModalState(() => tempDate = DateTime.now());
                            },
                          ),
                          ChoiceChip(
                            avatar: const Icon(Icons.today_rounded, size: 16),
                            label: const Text('اليوم'),
                            selected: isToday,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: isToday ? Colors.white : null,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) {
                              setModalState(() {
                                tempDate = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  tempDate.hour,
                                  tempDate.minute,
                                );
                              });
                            },
                          ),
                          ChoiceChip(
                            avatar: const Icon(Icons.history_rounded, size: 16),
                            label: const Text('أمس'),
                            selected: isYesterday,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: isYesterday ? Colors.white : null,
                              fontWeight: isYesterday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) {
                              final y = now.subtract(const Duration(days: 1));
                              setModalState(() {
                                tempDate = DateTime(
                                  y.year,
                                  y.month,
                                  y.day,
                                  tempDate.hour,
                                  tempDate.minute,
                                );
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('قبل يومين'),
                            selected: isDayBefore,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: isDayBefore ? Colors.white : null,
                              fontWeight: isDayBefore
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) {
                              final d = now.subtract(const Duration(days: 2));
                              setModalState(() {
                                tempDate = DateTime(
                                  d.year,
                                  d.month,
                                  d.day,
                                  tempDate.hour,
                                  tempDate.minute,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Current Selected Date & Time interactive cards
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  try {
                                    final picked = await showDatePicker(
                                      context: modalContext,
                                      initialDate: tempDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                      locale: const Locale('ar'),
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        tempDate = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          tempDate.hour,
                                          tempDate.minute,
                                        );
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint('DatePicker error: $e');
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month_rounded,
                                            size: 16,
                                            color: AppTheme.primaryColor,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'التاريخ (اضغط للتقويم)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        AppConstants.formatDate(tempDate),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 45,
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  try {
                                    final picked = await showTimePicker(
                                      context: modalContext,
                                      initialTime: TimeOfDay.fromDateTime(
                                        tempDate,
                                      ),
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        tempDate = DateTime(
                                          tempDate.year,
                                          tempDate.month,
                                          tempDate.day,
                                          picked.hour,
                                          picked.minute,
                                        );
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint('TimePicker error: $e');
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 16,
                                            color: AppTheme.primaryColor,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'الوقت (اضغط للتغيير)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        AppConstants.formatTime(tempDate),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Confirm Button
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _selectedDate = tempDate);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          'اعتماد التاريخ والوقت',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error opening date picker modal: $e');
    }
  }

  void _submitTransaction(List<Wallet> wallets) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final normalized = _normalizeNumber(_amountController.text);
    final amount = double.tryParse(normalized) ?? 0.0;
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المحفظة أولاً')),
      );
      return;
    }

    final selectedWallet = wallets.firstWhere(
      (w) => w.id == _selectedWalletId,
      orElse: () => wallets.first,
    );

    final finalCategory =
        (_selectedCategory == 'أخرى' &&
            _customCategoryController.text.trim().isNotEmpty)
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    final allTransactions =
        context.read<TransactionsCubit>().state is TransactionsLoaded
        ? (context.read<TransactionsCubit>().state as TransactionsLoaded)
              .transactions
        : <TransactionModel>[];
    final walletTransactions = allTransactions
        .where((tx) => tx.walletId == selectedWallet.id)
        .toList();

    final currentBalance = BalanceCalculator.calculateWalletBalance(
      openingBalance: selectedWallet.openingBalance,
      transactions: walletTransactions,
    );

    // If expense exceeds wallet balance -> show warning dialog with override option
    if (_selectedType == 'expense' && amount > currentBalance) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
              child: const Text(
                'تعديل المبلغ',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeSave(amount, finalCategory);
              },
              child: const Text('المتابعة على كل حال'),
            ),
          ],
        ),
      );
    } else {
      _executeSave(amount, finalCategory);
    }
  }

  void _executeSave(double amount, String category) {
    if (_isEditing) {
      final updatedTx = widget.transactionToEdit!.copyWith(
        walletId: _selectedWalletId!,
        type: _selectedType,
        amount: amount,
        category: category,
        note: _noteController.text.isEmpty ? null : _noteController.text.trim(),
        date: _selectedDate,
      );
      context.read<TransactionsCubit>().updateTransaction(updatedTx);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تم حفظ تعديلات الحركة (${AppConstants.formatCurrency(amount)}) بنجاح 🎉',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );

      Navigator.pop(context, updatedTx);
      return;
    }

    context.read<TransactionsCubit>().addTransaction(
      walletId: _selectedWalletId!,
      type: _selectedType,
      amount: amount,
      category: category,
      note: _noteController.text.isEmpty ? null : _noteController.text.trim(),
      date: _selectedDate,
      source: 'manual',
    );

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
                _selectedType == 'expense'
                    ? 'تم تسجيل المصروف بنجاح (${AppConstants.formatCurrency(amount)}) 🎉'
                    : 'تم تسجيل الدخل بنجاح (${AppConstants.formatCurrency(amount)}) 🎉',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل الحركة المالية' : 'تسجيل حركة مالية'),
      ),
      body: BlocBuilder<WalletsCubit, WalletsState>(
        builder: (context, walletsState) {
          final wallets = walletsState is WalletsLoaded
              ? walletsState.wallets
              : <Wallet>[];

          if (wallets.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28.0),
                child: ResponsiveConstraint(
                  maxWidth: 550,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 60,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'لا توجد محافظ مسجلة بعد',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'لتسجيل حركة مالية يدوية، يلزم وجود محفظة واحدة على الأقل لخصم أو إيداع المبلغ منها.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddWalletScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text(
                            'إضافة محفظة جديدة الآن',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await context.read<WalletsCubit>().addWallet(
                              name: 'كاش (نقداً)',
                              type: 'kash',
                              colorValue: 0xFF0E7C61,
                              iconCodePoint: Icons.payments_rounded.codePoint,
                              openingBalance: 0.0,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم إنشاء محفظة "كاش (نقداً)" بنجاح 🎉',
                                  ),
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(
                              color: AppTheme.primaryColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.flash_on_rounded),
                          label: const Text(
                            'إنشاء محفظة "كاش" سريعة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          _selectedWalletId ??= wallets.first.id;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ResponsiveConstraint(
                maxWidth: 600,
                alignment: Alignment.topCenter,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isEditing) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.07,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppTheme.primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تلميح: العمليات البنكية تُسجل تلقائياً عبر الرسائل، استخدم هذا النموذج للمصاريف النقدية (الكاش) 💵',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                                onTap: () =>
                                    setState(() => _selectedType = 'expense'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
                                onTap: () =>
                                    setState(() => _selectedType = 'income'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
                      const SizedBox(height: 20),

                      // Amount Field
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى إدخال المبلغ';
                          }
                          final normalized = _normalizeNumber(val);
                          final parsed = double.tryParse(normalized);
                          if (parsed == null || parsed <= 0) {
                            return 'يرجى إدخال مبلغ صحيح أكبر من الصفر';
                          }
                          return null;
                        },
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'المبلغ',
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                          suffixText: 'ر.ي',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick Amount Chips
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [500.0, 1000.0, 2000.0, 5000.0, 10000.0].map((
                          val,
                        ) {
                          return ActionChip(
                            avatar: const Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: AppTheme.primaryColor,
                            ),
                            label: Text(
                              AppConstants.formatCurrency(val),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () => _addQuickAmount(val),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Wallet Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedWalletId,
                        items: wallets.map((w) {
                          final txs =
                              (context.read<TransactionsCubit>().state
                                  is TransactionsLoaded)
                              ? (context.read<TransactionsCubit>().state
                                        as TransactionsLoaded)
                                    .transactions
                                    .where((t) => t.walletId == w.id)
                                    .toList()
                              : <TransactionModel>[];
                          final bal = BalanceCalculator.calculateWalletBalance(
                            openingBalance: w.openingBalance,
                            transactions: txs,
                          );
                          return DropdownMenuItem<String>(
                            value: w.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
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
                                Text(
                                  w.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '(${AppConstants.formatCurrency(bal, w.currencyCode)})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: bal < 0
                                        ? Colors.red
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedWalletId = val);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'المحفظة المعنية',
                          prefixIcon: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Category Chips
                      const Text(
                        'الفئة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
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
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                            ),
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCategory = cat);
                              }
                            },
                          );
                        }).toList(),
                      ),

                      // Custom category input if "أخرى" is selected
                      if (_selectedCategory == 'أخرى') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customCategoryController,
                          decoration: InputDecoration(
                            labelText: 'اسم الفئة المخصصة (اختياري)',
                            hintText: 'مثال: سلفة، هدايا، صيانة',
                            prefixIcon: const Icon(Icons.label_outline_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Note / Description Field
                      TextFormField(
                        controller: _noteController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'بيان أو وصف الحركة (اختياري)',
                          hintText: 'مثال: غداء عمل، مقاضي البيت، تاكسي',
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date Picker
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 20,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'التاريخ والوقت',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${AppConstants.formatDate(_selectedDate)}  •  ${AppConstants.formatTime(_selectedDate)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'تغيير',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
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
                          _isEditing
                              ? 'حفظ التعديلات'
                              : (_selectedType == 'expense'
                                    ? 'تسجيل المصروف'
                                    : 'تسجيل الدخل'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
