import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../models/inter_entity_transfer.dart';
import '../../repositories/inter_entity_transfer_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';

/// "سجل التحويلات" الكامل بين [hotel] و[otherHotel] — الشاشة الأخيرة في مسار
/// التصفّح: المركز المالي ← ديون المنشآت ← فندق ← سجل التحويلات الكامل. يعرض
/// كل تحويل (معلَّق أو مُرحَّل) في أي اتجاه بين الطرفين: التاريخ، المبلغ،
/// البيان، الفندق المُرسِل، الفندق المستقبِل، والحالة.
class InterEntityTransferHistoryPage extends StatefulWidget {
  final Hotel hotel;
  final Hotel otherHotel;
  const InterEntityTransferHistoryPage({super.key, required this.hotel, required this.otherHotel});

  @override
  State<InterEntityTransferHistoryPage> createState() => _InterEntityTransferHistoryPageState();
}

class _InterEntityTransferHistoryPageState extends State<InterEntityTransferHistoryPage> {
  final _repository = InterEntityTransferRepository();
  bool _isLoading = true;
  List<InterEntityTransfer> _transfers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _repository.getHistoryBetween(widget.hotel.id!, widget.otherHotel.id!);
    data.sort((a, b) => "${b.date} ${b.time}".compareTo("${a.date} ${a.time}"));
    if (mounted) setState(() { _transfers = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "سجل التحويلات: ${widget.otherHotel.arabicName}", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transfers.isEmpty
              ? const Center(child: Text("لا توجد تحويلات مسجَّلة مع هذه المنشأة", style: AppTextStyles.caption))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _transfers.length,
                  itemBuilder: (context, index) => _buildTransferCard(_transfers[index], identityColor),
                ),
    );
  }

  Widget _buildTransferCard(InterEntityTransfer t, Color identityColor) {
    final isSending = t.fromHotelId == widget.hotel.id;
    final sendingName = isSending ? widget.hotel.arabicName : widget.otherHotel.arabicName;
    final receivingName = isSending ? widget.otherHotel.arabicName : widget.hotel.arabicName;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      identityAccent: identityColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isSending ? Icons.call_made : Icons.call_received, color: isSending ? Colors.deepOrange : Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(t.statement, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(
                "${NumberFormat("#,##0.##").format(t.amount)} ريال",
                style: TextStyle(fontWeight: FontWeight.bold, color: isSending ? Colors.deepOrange : Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text("من: $sendingName", style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Expanded(child: Text("إلى: $receivingName", style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${t.date}  ${t.time}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
              _statusChip(t.isTransferred),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool isTransferred) {
    final color = isTransferred ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(
        isTransferred ? "مُرحَّل" : "بانتظار الترحيل",
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
