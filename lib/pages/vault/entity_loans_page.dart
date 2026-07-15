import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/entity_loan.dart';
import '../../../repositories/vault_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_dialog.dart';
import '../../../widgets/common/app_text_field.dart';

import '../../../models/hotel.dart';
import '../../../widgets/common/hotel_identity_title.dart';

class EntityLoansPage extends StatefulWidget {
  final Hotel hotel;
  const EntityLoansPage({super.key, required this.hotel});

  @override
  State<EntityLoansPage> createState() => _EntityLoansPageState();
}

class _EntityLoansPageState extends State<EntityLoansPage> {
  final _repository = VaultRepository();
  List<EntityLoan> _loans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repository.getEntityLoans(widget.hotel.id!);
    setState(() {
      _loans = data;
      _isLoading = false;
    });
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddLoanSheet(hotel: widget.hotel),
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
        title: HotelIdentityTitle(title: "المركز المالي - قرض المنشأة", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loans.isEmpty
              ? const Center(child: Text("لا توجد قروض سابقة"))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _loans.length,
                  itemBuilder: (context, index) {
                    final item = _loans[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.md),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSizes.sm),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(Icons.add_card, color: Colors.green),
                            ),
                            const SizedBox(width: AppSizes.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.statement, style: AppTextStyles.bodyBold),
                                  Text("${item.date} | ${item.time}", style: AppTextStyles.caption),
                                  Text("مصدر المبلغ: ${item.source}", style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            Text(
                              _formatCurrency(item.amount),
                              style: AppTextStyles.title.copyWith(color: Colors.green, fontSize: 18),
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

class AddLoanSheet extends StatefulWidget {
  final Hotel hotel;
  const AddLoanSheet({super.key, required this.hotel});

  @override
  State<AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<AddLoanSheet> {
  final _amountController = TextEditingController();
  final _statementController = TextEditingController();
  final _amountFocus = FocusNode();
  final _repository = VaultRepository();
  String? _selectedSource;
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

    if (amount <= 0 || statement.isEmpty || _selectedSource == null) {
      String message = "يرجى إدخال جميع البيانات المطلوبة";
      if (_selectedSource == null) message = "يرجى اختيار جهة الإيداع";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد إضافة القرض",
      message: "هل تريد تسجيل قرض بقيمة ${NumberFormat("#,##0.##").format(amount)} على المنشأة؟",
      onConfirm: () => _performSave(amount, statement),
    );
  }

  Future<void> _performSave(double amount, String statement) async {
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final loan = EntityLoan(
        hotelId: widget.hotel.id!,
        amount: amount,
        statement: statement,
        source: _selectedSource!,
        date: DateFormat('yyyy-MM-dd').format(now),
        time: DateFormat('HH:mm').format(now),
        createdAt: now.toIso8601String(),
      );

      await _repository.addEntityLoan(loan);
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
                Text("إضافة قرض جديد على المنشأة", style: AppTextStyles.title),
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
            const Text("جهة الإيداع", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Expanded(child: _buildSourceButton("نقد", Icons.money)),
                const SizedBox(width: AppSizes.md),
                Expanded(child: _buildSourceButton("حساب بنكي", Icons.account_balance)),
              ],
            ),
            const SizedBox(height: AppSizes.xl),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedSource != null ? identityColor : Colors.grey,
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

  Widget _buildSourceButton(String source, IconData icon) {
    final isSelected = _selectedSource == source;
    return GestureDetector(
      onTap: () => setState(() => _selectedSource = source),
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
                  source,
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
