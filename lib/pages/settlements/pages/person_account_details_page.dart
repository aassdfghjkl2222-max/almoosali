import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/settlement.dart';
import '../../../models/settlement_account.dart';
import '../../../repositories/settlement_repository.dart';
import '../../../services/pdf_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../models/hotel.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import '../../../core/hotel_visual_identity.dart';
import 'add_person_operation_page.dart';

class PersonAccountDetailsPage extends StatefulWidget {
  final Hotel hotel;
  final SettlementAccount account;

  const PersonAccountDetailsPage({super.key, required this.hotel, required this.account});

  @override
  State<PersonAccountDetailsPage> createState() => _PersonAccountDetailsPageState();
}

class _PersonAccountDetailsPageState extends State<PersonAccountDetailsPage> {
  final _repository = SettlementRepository();
  
  List<Settlement> _settlements = [];
  Map<String, dynamic> _summary = {
    'totalDueToMe': 0.0,
    'totalIOwe': 0.0,
    'opCount': 0,
    'remaining': 0.0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final settlements = await _repository.getSettlements(
        accountId: widget.account.id,
        hotelId: widget.hotel.id!,
      );
      final summary = await _repository.getAccountSummary(widget.hotel.id!, widget.account.id!);
      setState(() {
        _settlements = settlements;
        _summary = summary;
      });
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showOperationDetails(Settlement settlement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.lg))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppSizes.md),
              Text("تفاصيل العملية", style: AppTextStyles.title, textAlign: TextAlign.center),
              const Divider(),
              _buildDetailRow("التاريخ", "${settlement.date.day}/${settlement.date.month}/${settlement.date.year}"),
              _buildDetailRow("المبلغ", "${NumberFormat("#,##0.00").format(settlement.amount)} ريال"),
              _buildDetailRow("النوع", settlement.direction == 'to_me' ? "لك عليه" : "عليك له"),
              _buildDetailRow("الوصف", settlement.description),
              if (settlement.attachments.isNotEmpty) ...[
                const SizedBox(height: AppSizes.md),
                const Text("المرفقات", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSizes.sm),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: settlement.attachments.length,
                    itemBuilder: (context, i) {
                      final path = settlement.attachments[i];
                      final isPdf = path.toLowerCase().endsWith('.pdf');
                      return GestureDetector(
                        onTap: () => OpenFilex.open(path),
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 100,
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: Center(child: isPdf ? const Icon(Icons.picture_as_pdf, color: Colors.red) : Image.file(File(path), fit: BoxFit.cover)),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.xl),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmDeleteOperation(settlement),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("حذف"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteOperation(Settlement s) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذه العملية؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close bottom sheet
              await _repository.deleteSettlement(s.id!);
              _loadData();
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          Expanded(child: Text(value, style: AppTextStyles.body)),
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
        title: HotelIdentityTitle(title: widget.account.name, hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _showShareOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _settlements.isEmpty 
                ? const Center(child: Text("لا توجد عمليات مسجلة لهذا الحساب"))
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: _settlements.length,
                    itemBuilder: (context, index) {
                      final settlement = _settlements[index];
                      return _buildOperationCard(settlement);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddPersonOperationPage(hotel: widget.hotel, account: widget.account, type: widget.account.type)),
          );
          if (result == true) _loadData();
        },
        backgroundColor: identityColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final rem = _summary['remaining'] as double;
    final isPositive = rem >= 0;
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      margin: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: identityColor,
        borderRadius: BorderRadius.circular(AppSizes.lg),
        boxShadow: [BoxShadow(color: identityColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem("إجمالي العمليات", _summary['opCount'].toString(), Colors.white),
              _buildSummaryItem("المتبقي", "${NumberFormat("#,##0").format(rem.abs())} ريال", isPositive ? Colors.greenAccent : Colors.orangeAccent),
            ],
          ),
          const Divider(color: Colors.white24, height: AppSizes.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem("لك عليه", NumberFormat("#,##0").format(_summary['totalDueToMe']), Colors.white70),
              _buildSummaryItem("عليك له", NumberFormat("#,##0").format(_summary['totalIOwe']), Colors.white70),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(isPositive ? "صافي مستحق لك" : "صافي مستحق عليك", style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildOperationCard(Settlement s) {
    final isToMe = s.direction == 'to_me';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: AppCard(
        onTap: () => _showOperationDetails(s),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isToMe ? Colors.green : Colors.orange).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isToMe ? Icons.arrow_downward : Icons.arrow_upward, 
                          color: isToMe ? Colors.green : Colors.orange, size: 20),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.description, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text("${s.date.day}/${s.date.month}/${s.date.year}", style: AppTextStyles.caption),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${NumberFormat("#,##0").format(s.amount)} ريال",
                     style: TextStyle(color: isToMe ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                Text(isToMe ? "لك عليه" : "عليك له", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.lg))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text("تصدير كشف حساب (PDF)"),
            onTap: () {
              Navigator.pop(context);
              PdfService.shareAccountPdf(
                account: widget.account,
                settlements: _settlements,
                summary: _summary,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.blue),
            title: const Text("نسخ كشف الحساب"),
            onTap: () {
              Navigator.pop(context);
              final buffer = StringBuffer();
              buffer.writeln("كشف حساب: ${widget.account.name}");
              buffer.writeln("المتبقي: ${NumberFormat("#,##0.##").format(_summary['remaining'])} ريال");
              buffer.writeln("-------------------");
              for (var s in _settlements) {
                buffer.writeln("${s.date.day}/${s.date.month}: ${s.description} - ${NumberFormat("#,##0.##").format(s.amount)} ريال (${s.direction == 'to_me' ? 'لك' : 'عليك'})");
              }
              Share.share(buffer.toString());
            },
          ),
          const SizedBox(height: AppSizes.md),
        ],
      ),
    );
  }
}
