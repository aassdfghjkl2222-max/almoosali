import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/contract.dart';
import '../../models/contract_payment.dart';
import '../../repositories/contract_repository.dart';
import '../../services/vault_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/trash_confirm_dialogs.dart';
import '../../widgets/vault/amount_source_selector.dart';
import 'add_contract_page.dart';
import '../../services/contract_report_service.dart';

import '../../models/hotel.dart';
import '../../widgets/common/hotel_identity_title.dart';

class ContractDetailsPage extends StatefulWidget {
  final Hotel hotel;
  final Contract contract;
  const ContractDetailsPage({super.key, required this.hotel, required this.contract});

  @override
  State<ContractDetailsPage> createState() => _ContractDetailsPageState();
}

class _ContractDetailsPageState extends State<ContractDetailsPage> {
  final _repository = ContractRepository();
  late Contract _contract;
  List<ContractPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _contract = widget.contract;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final payments = await _repository.getContractPayments(_contract.id!);
    setState(() {
      _payments = payments;
      _isLoading = false;
      _updateContractStatusIfNeeded();
    });
  }

  void _updateContractStatusIfNeeded() async {
    // Logic to check if all payments are paid, etc.
    // If all payments are paid and endDate has passed, maybe mark as completed.
    // But for now, let's keep it simple.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("تفاصيل العقد"),
        centerTitle: true,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddContractPage(hotel: widget.hotel, contract: _contract)),
              );
              if (result == true) {
                final updated = await _repository.getContractById(_contract.id!);
                if (updated != null) {
                  setState(() => _contract = updated);
                  _loadData();
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildMainInfoCard(),
                const SizedBox(height: AppSizes.md),
                _buildFinancialSummary(),
                const SizedBox(height: AppSizes.md),
                _buildActionButtons(),
                const SizedBox(height: AppSizes.lg),
                _buildPaymentsSection(),
              ],
            ),
    );
  }

  Widget _buildMainInfoCard() {
    Color statusColor;
    switch (_contract.status) {
      case 'ساري': statusColor = Colors.green; break;
      case 'يقترب من الانتهاء': statusColor = Colors.orange; break;
      case 'منتهي': statusColor = Colors.red; break;
      case 'مكتمل': statusColor = Colors.blue; break;
      default: statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_contract.name, style: AppTextStyles.headline.copyWith(color: Theme.of(context).colorScheme.primary, fontSize: 20)),
              _buildStatusBadge(_contract.status, statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text("المتعاقد: ${_contract.contractorName}", style: AppTextStyles.subtitle),
          const Divider(height: 32),
          _buildDetailRow("تاريخ البداية", _contract.startDate),
          _buildDetailRow("مدة العقد", "${_contract.duration} شهر"),
          _buildDetailRow("تاريخ النهاية", _contract.endDate),
          _buildDetailRow("طريقة السداد", _contract.paymentMethod),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    final totalPaid = _payments.where((p) => p.status == 'تم السداد').fold(0.0, (sum, p) => sum + p.amount);
    final totalRemaining = _contract.totalValue - totalPaid;
    final paidCount = _payments.where((p) => p.status == 'تم السداد').length;
    final nextPayment = _payments.where((p) => p.status != 'تم السداد').toList();
    nextPayment.sort((a, b) => a.date.compareTo(b.date));

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              _buildFinanceStat("إجمالي العقد", NumberFormat("#,##0.##").format(_contract.totalValue), Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSizes.sm),
              _buildFinanceStat("المدفوع", NumberFormat("#,##0.##").format(totalPaid), Colors.green),
              const SizedBox(width: AppSizes.sm),
              _buildFinanceStat("المتبقي", NumberFormat("#,##0.##").format(totalRemaining), Colors.orange),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("عدد الدفعات: ${_payments.length} ($paidCount مسددة)", style: AppTextStyles.caption),
              if (nextPayment.isNotEmpty)
                Text("أقرب دفعة: ${nextPayment.first.date}", style: AppTextStyles.caption.copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(Icons.picture_as_pdf_outlined, "تصدير PDF", () {
            ContractReportService.generateAndShareContractReport(_contract, _payments);
          }),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _actionButton(Icons.print_outlined, "طباعة", () {
            ContractReportService.printContractReport(_contract, _payments);
          }),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _actionButton(Icons.share_outlined, "مشاركة", () {
            ContractReportService.generateAndShareContractReport(_contract, _payments);
          }),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("جدول الدفعات", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
            Text("${_payments.length} دفعات", style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        if (_payments.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("لا توجد دفعات")))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payments.length,
            itemBuilder: (context, index) {
              final payment = _payments[index];
              return _buildPaymentRow(payment, index + 1);
            },
          ),
      ],
    );
  }

  Widget _buildPaymentRow(ContractPayment payment, int number) {
    Color statusColor;
    switch (payment.status) {
      case 'تم السداد': statusColor = Colors.green; break;
      case 'متأخرة': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1), child: Text("$number", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${NumberFormat("#,##0.##").format(payment.amount)} ريال", style: AppTextStyles.bodyBold),
                Text(payment.date, style: AppTextStyles.caption),
              ],
            ),
          ),
          Column(
            children: [
              _buildStatusBadge(payment.status, statusColor, mini: true),
              if (payment.status != 'تم السداد')
                TextButton(
                  onPressed: () => _markAsPaid(payment),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                  child: const Text("✔ تم السداد", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _markAsPaid(ContractPayment payment) async {
    // 1. اختيار مصدر المبلغ
    final source = await showDialog<String>(
      context: context,
      builder: (context) {
        String selected = 'خارج النظام';
        return StatefulBuilder(
          builder: (context, setDialogState) {
             return AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
               title: const Text("مصدر المبلغ", style: TextStyle(fontWeight: FontWeight.bold)),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Text("يرجى تحديد مصدر سداد هذه الدفعة:"),
                   const SizedBox(height: AppSizes.md),
                   AmountSourceSelector(
                     selectedSource: selected,
                     onSourceChanged: (val) => setDialogState(() => selected = val),
                   ),
                 ],
               ),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(context), child: Text("إلغاء", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                 TextButton(
                   onPressed: () => Navigator.pop(context, selected),
                   child: Text("تأكيد", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))
                 ),
               ],
             );
          }
        );
      }
    );

    if (source == null) return;

    if (!mounted) return;
    final vaultService = VaultService();
    final confirmed = await vaultService.checkBalanceAndConfirm(
      context: context,
      hotelId: widget.hotel.id!,
      amount: payment.amount,
      source: source,
    );

    if (!confirmed) return;

    final updated = payment.copyWith(status: 'تم السداد', amountSource: source);
    await _repository.updatePayment(updated);
    
    if (mounted) {
      await vaultService.processVaultTransaction(
        context: context,
        hotelId: widget.hotel.id!,
        amount: payment.amount,
        source: source,
        type: "دفعة عقد: ${_contract.name}",
        reference: "رقم العقد: ${_contract.id}",
      );
      _loadData();
    }
  }

  Widget _buildStatusBadge(String status, Color color, {bool mini = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: mini ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: mini ? 9 : 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _confirmDelete() {
    TrashConfirmDialogs.confirmMoveToTrash(context, () async {
      await _repository.deleteContract(_contract);
      if (!context.mounted) return;
      Navigator.pop(context, true); // Go back to list
    });
  }
}
