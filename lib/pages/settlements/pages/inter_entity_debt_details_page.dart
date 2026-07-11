import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/formatters/thousands_separator_formatter.dart';
import '../../../models/settlement.dart';
import '../../../models/settlement_transaction.dart';
import '../../../models/hotel.dart';
import '../../../repositories/settlement_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../services/pdf_service.dart';
import '../../../services/vault_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/vault/amount_source_selector.dart';
import '../../../widgets/app_button.dart';
import '../../../core/hotel_visual_identity.dart';
import 'add_inter_entity_debt_page.dart';

class InterEntityDebtDetailsPage extends StatefulWidget {
  final Hotel hotel;
  final Settlement settlement;

  const InterEntityDebtDetailsPage({super.key, required this.hotel, required this.settlement});

  @override
  State<InterEntityDebtDetailsPage> createState() => _InterEntityDebtDetailsPageState();
}

class _InterEntityDebtDetailsPageState extends State<InterEntityDebtDetailsPage> {
  final _repository = SettlementRepository();
  final _hotelRepository = HotelRepository();
  
  late Settlement _settlement;
  List<SettlementTransaction> _transactions = [];
  List<Hotel> _hotels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _settlement = widget.settlement;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await _repository.getTransactions(_settlement.id!);
      final hotels = await _hotelRepository.getAllHotels();
      // Reload settlement to get latest totalPaid/status
      final allSettlements = await _repository.getSettlements(type: 'inter_entity');
      final updatedSettlement = allSettlements.firstWhere((s) => s.id == _settlement.id);
      
      setState(() {
        _transactions = transactions;
        _hotels = hotels;
        _settlement = updatedSettlement;
      });
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getHotelName(int? id) {
    if (id == null) return "غير معروف";
    final hotel = _hotels.firstWhere((h) => h.id == id, orElse: () => Hotel(arabicName: "غير معروف", englishName: "", city: ""));
    return hotel.arabicName;
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذه العملية؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _repository.deleteSettlement(_settlement.id!);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _addPayment() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String amountSource = 'خارج النظام';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: const Text("إضافة سداد", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: "المبلغ",
                      prefixIcon: Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  const Text("مصدر المبلغ:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AmountSourceSelector(
                    selectedSource: amountSource,
                    onSourceChanged: (val) => setDialogState(() => amountSource = val),
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: "ملاحظات (اختياري)",
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: AppColors.textSecondary))),
              TextButton(
                onPressed: () async {
                  final amount = ThousandsSeparatorInputFormatter.parse(amountController.text);
                  if (amount == null || amount <= 0) return;
                  
                  final vaultService = VaultService();
                  final confirmed = await vaultService.checkBalanceAndConfirm(
                    context: context,
                    hotelId: widget.hotel.id!,
                    amount: amount,
                    source: amountSource,
                  );

                  if (!confirmed) return;

                  if (context.mounted) Navigator.pop(context);

                  await _repository.addTransaction(SettlementTransaction(
                    settlementId: _settlement.id!,
                    amount: amount,
                    date: DateTime.now(),
                    notes: notesController.text,
                    amountSource: amountSource,
                  ));

                  if (context.mounted) {
                    await vaultService.processVaultTransaction(
                      context: context,
                      hotelId: widget.hotel.id!,
                      amount: amount,
                      source: amountSource,
                      type: "سداد تسوية: ${_settlement.description}",
                      reference: "رقم التسوية: ${_settlement.id}",
                      notes: notesController.text,
                    );
                    _loadData();
                  }
                },
                child: Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _shareDebt() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.lg))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text("تصدير PDF (رسمي)"),
            onTap: () {
              Navigator.pop(context);
              PdfService.shareSettlementPdf(
                settlement: _settlement,
                creditorName: _getHotelName(_settlement.creditorHotelId),
                debtorName: _getHotelName(_settlement.debtorHotelId),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.blue),
            title: const Text("نسخ كنص"),
            onTap: () {
              Navigator.pop(context);
              final text = """
التقرير المالي - مديونية
التاريخ: ${_settlement.date.day}/${_settlement.date.month}/${_settlement.date.year}
الدائن: ${_getHotelName(_settlement.creditorHotelId)}
المدين: ${_getHotelName(_settlement.debtorHotelId)}
المبلغ الأصلي: ${NumberFormat("#,##0.00").format(_settlement.amount)} ريال
المسدد: ${NumberFormat("#,##0.00").format(_settlement.totalPaid)} ريال
المتبقي: ${NumberFormat("#,##0.00").format(_settlement.remainingAmount)} ريال
الحالة: ${_settlement.status == 'paid' ? 'مسددة' : 'مفتوحة'}
الوصف: ${_settlement.description}
""";
              Share.share(text);
            },
          ),
          const SizedBox(height: AppSizes.md),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("تفاصيل المديونية", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareDebt,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              children: [
                _buildSummaryCard(),
                const SizedBox(height: AppSizes.md),
                _buildDetailsCard(),
                const SizedBox(height: AppSizes.md),
                if (_settlement.attachments.isNotEmpty) _buildAttachmentsCard(),
                const SizedBox(height: AppSizes.md),
                _buildPaymentsSection(),
                const SizedBox(height: AppSizes.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: "تعديل",
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddInterEntityDebtPage(hotel: widget.hotel, settlement: _settlement)),
                          );
                          if (result == true) _loadData();
                        },
                        backgroundColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: AppButton(
                        text: "حذف",
                        onPressed: _showDeleteConfirmation,
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      floatingActionButton: _settlement.status != 'paid' 
        ? FloatingActionButton.extended(
            onPressed: _addPayment,
            label: const Text("إضافة سداد"),
            icon: const Icon(Icons.payment),
            backgroundColor: identityColor,
          )
        : null,
    );
  }

  Widget _buildSummaryCard() {
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem("المبلغ الأصلي", "${NumberFormat("#,##0.00").format(_settlement.amount)} ريال", HotelVisualIdentity.colorForHotel(widget.hotel)),
              _buildStatusTag(_settlement.status),
            ],
          ),
          const Divider(height: AppSizes.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem("إجمالي المسدد", "${NumberFormat("#,##0.00").format(_settlement.totalPaid)} ريال", Colors.green),
              _buildInfoItem("المتبقي", "${NumberFormat("#,##0.00").format(_settlement.remainingAmount)} ريال", AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow("التاريخ", "${_settlement.date.day}/${_settlement.date.month}/${_settlement.date.year}"),
          const Divider(),
          _buildDetailRow("الدائن", _getHotelName(_settlement.creditorHotelId)),
          const Divider(),
          _buildDetailRow("المدين", _getHotelName(_settlement.debtorHotelId)),
          const Divider(),
          _buildDetailRow("الوصف", _settlement.description, isMultiLine: true),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("المرفقات", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _settlement.attachments.length,
              itemBuilder: (context, index) {
                final path = _settlement.attachments[index];
                final isPdf = path.toLowerCase().endsWith('.pdf');
                return GestureDetector(
                  onTap: () => OpenFilex.open(path),
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    width: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: isPdf 
                        ? const Icon(Icons.picture_as_pdf, color: Colors.red)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover),
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("سجل السداد", style: AppTextStyles.bodyBold),
        const SizedBox(height: AppSizes.sm),
        if (_transactions.isEmpty)
          const Text("لا توجد عمليات سداد مسجلة", style: TextStyle(color: Colors.grey))
        else
          ..._transactions.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.green, size: 16),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${NumberFormat("#,##0.00").format(t.amount)} ريال", style: AppTextStyles.bodyBold),
                            if (t.notes != null && t.notes!.isNotEmpty)
                              Text(t.notes!, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Text("${t.date.day}/${t.date.month}/${t.date.year}", style: AppTextStyles.caption),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _confirmDeleteTransaction(t),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  void _confirmDeleteTransaction(SettlementTransaction t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف عملية السداد هذه؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _repository.deleteTransaction(t.id!, _settlement.id!);
              if (context.mounted) _loadData();
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.title.copyWith(color: color, fontSize: 16)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: isMultiLine ? AppTextStyles.body : AppTextStyles.bodyBold),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    final isPaid = status == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.5)),
      ),
      child: Text(
        isPaid ? "مسددة" : "مفتوحة",
        style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
