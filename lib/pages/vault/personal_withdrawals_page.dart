import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/personal_withdrawal.dart';
import '../../../repositories/vault_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_dialog.dart';
import '../../../widgets/common/app_text_field.dart';

import '../../../models/hotel.dart';
import '../../../widgets/common/hotel_identity_title.dart';

class PersonalWithdrawalsPage extends StatefulWidget {
  final Hotel hotel;
  const PersonalWithdrawalsPage({super.key, required this.hotel});

  @override
  State<PersonalWithdrawalsPage> createState() => _PersonalWithdrawalsPageState();
}

class _PersonalWithdrawalsPageState extends State<PersonalWithdrawalsPage> {
  final _repository = VaultRepository();
  List<PersonalWithdrawal> _withdrawals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repository.getPersonalWithdrawals(widget.hotel.id!);
    setState(() {
      _withdrawals = data;
      _isLoading = false;
    });
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddWithdrawalSheet(hotel: widget.hotel),
    ).then((value) {
      if (value == true) _loadData();
    });
  }

  String _formatCurrency(double amount) {
    return NumberFormat("#,##0.##").format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "المركز المالي - السحب الشخصي", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _withdrawals.isEmpty
              ? const Center(child: Text("لا توجد عمليات سحب سابقة"))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _withdrawals.length,
                  itemBuilder: (context, index) {
                    final item = _withdrawals[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.md),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSizes.sm),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(Icons.money_off, color: AppColors.danger),
                            ),
                            const SizedBox(width: AppSizes.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.statement, style: AppTextStyles.bodyBold),
                                  Text("${item.date} | ${item.time}", style: AppTextStyles.caption),
                                  Text("طريقة السحب: ${item.method}", style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            Text(
                              _formatCurrency(item.amount),
                              style: AppTextStyles.title.copyWith(color: AppColors.danger, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddWithdrawalSheet extends StatefulWidget {
  final Hotel hotel;
  const AddWithdrawalSheet({super.key, required this.hotel});

  @override
  State<AddWithdrawalSheet> createState() => _AddWithdrawalSheetState();
}

class _AddWithdrawalSheetState extends State<AddWithdrawalSheet> {
  final _amountController = TextEditingController();
  final _statementController = TextEditingController();
  final _amountFocus = FocusNode();
  final _repository = VaultRepository();
  String? _selectedMethod;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocus.requestFocus();
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final statement = _statementController.text;

    if (amount <= 0 || statement.isEmpty || _selectedMethod == null) {
      String message = "يرجى إدخال جميع البيانات المطلوبة";
      if (_selectedMethod == null) message = "يرجى اختيار طريقة الخصم";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد السحب",
      message: "هل تريد تسجيل سحب شخصي بقيمة ${NumberFormat("#,##0.##").format(amount)}؟",
      onConfirm: () => _performSave(amount, statement),
    );
  }

  Future<void> _performSave(double amount, String statement) async {
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final withdrawal = PersonalWithdrawal(
        hotelId: widget.hotel.id!,
        amount: amount,
        statement: statement,
        method: _selectedMethod!,
        date: DateFormat('yyyy-MM-dd').format(now),
        time: DateFormat('HH:mm').format(now),
        createdAt: now.toIso8601String(),
      );

      await _repository.addPersonalWithdrawal(withdrawal);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("إضافة سحب شخصي جديد", style: AppTextStyles.title),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.lg),
            AppTextField(
              controller: _amountController,
              hint: "المبلغ",
              formatThousands: true,
              focusNode: _amountFocus,
              icon: Icons.attach_money,
            ),
            const SizedBox(height: AppSizes.md),
            AppTextField(
              controller: _statementController,
              hint: "البيان",
              icon: Icons.description,
            ),
            const SizedBox(height: AppSizes.lg),
            const Text("طريقة الخصم", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Expanded(child: _buildMethodButton("نقد", Icons.money)),
                const SizedBox(width: AppSizes.md),
                Expanded(child: _buildMethodButton("شبكة", Icons.credit_card)),
              ],
            ),
            const SizedBox(height: AppSizes.xl),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedMethod != null ? identityColor : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  elevation: 0,
                ),
                child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text("حفظ العملية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodButton(String method, IconData icon) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: 2),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 28),
                const SizedBox(height: 8),
                Text(
                  method,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (isSelected)
              const Positioned(
                top: 5,
                right: 10,
                child: Icon(Icons.check_circle, color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
