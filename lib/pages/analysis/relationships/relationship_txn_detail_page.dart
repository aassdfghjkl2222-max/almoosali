import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/financial_report.dart';
import '../../../models/hotel.dart';
import '../../../models/relationship_txn.dart';
import '../../../repositories/financial_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import '../../dashboard/pages/documents_page.dart';
import '../reports/report_details_page.dart';

/// تفاصيل عملية مالية واحدة — قراءة فقط بالكامل. يعرض كل بيانات العملية،
/// التقرير المرتبط الحقيقي (إن وُجد عبر reference_type='daily_report')،
/// والمستندات المرتبطة الحقيقية (مرفقات التسوية إن كانت من نظام التسويات)،
/// إضافة إلى "المسار المالي" — تسلسل بصري لمن دفع ولمن ولماذا وعن أي طريق.
class RelationshipTxnDetailPage extends StatefulWidget {
  final Hotel contextHotel;
  final RelationshipTxn txn;
  final Color color;

  const RelationshipTxnDetailPage({super.key, required this.contextHotel, required this.txn, required this.color});

  @override
  State<RelationshipTxnDetailPage> createState() => _RelationshipTxnDetailPageState();
}

class _RelationshipTxnDetailPageState extends State<RelationshipTxnDetailPage> {
  FinancialReport? _linkedReport;
  Hotel? _reportHotel;
  bool _loadingReport = true;

  @override
  void initState() {
    super.initState();
    _loadLinkedReport();
  }

  Future<void> _loadLinkedReport() async {
    if (widget.txn.reportId == null) {
      setState(() => _loadingReport = false);
      return;
    }
    final all = await FinancialRepository().getFinancialReports(widget.txn.hotelId);
    final match = all.where((r) => r.id == widget.txn.reportId).toList();
    if (match.isNotEmpty) {
      final hotels = await HotelRepository().getAllHotels();
      _reportHotel = hotels.firstWhere((h) => h.id == widget.txn.hotelId, orElse: () => widget.contextHotel);
      _linkedReport = match.first;
    }
    if (mounted) setState(() => _loadingReport = false);
  }

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final t = widget.txn;
    final identityColor = HotelVisualIdentity.colorForHotel(widget.contextHotel);
    final statusColor = t.status == 'مُنفَّذة' || t.status == 'مسدَّدة' ? AppColors.success : AppColors.warning;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "تفاصيل العملية #${t.id}", hotel: widget.contextHotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          AppCard(
            identityAccent: widget.color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.operationType, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(t.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(t.description, style: AppTextStyles.caption),
                const Divider(height: AppSizes.lg),
                Text(_format(t.amount), style: AppTextStyles.title.copyWith(fontSize: 28, color: widget.color, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text("المسار المالي", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppSizes.sm),
          _buildFlowCard(t),
          const SizedBox(height: AppSizes.lg),
          Text("بيانات العملية", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppSizes.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoLine("رقم العملية", "#${t.id}"),
                _infoLine("المصدر", t.source == 'ledger' ? "دفتر الأستاذ المالي" : "نظام التسويات"),
                _infoLine("الجهة الدافعة", t.payerName),
                _infoLine("الجهة المستفيدة", t.beneficiaryName),
                if (t.viaAccount.isNotEmpty) _infoLine("عن طريق", t.viaAccount),
                _infoLine("وقت الإنشاء", DateFormat('yyyy-MM-dd HH:mm').format(t.date)),
                _infoLine("وقت الاعتماد", t.status == 'مُنفَّذة' || t.status == 'مسدَّدة' ? "منفَّذة فعلياً (بلا سجل وقت اعتماد منفصل)" : "لم تُسدَّد بعد"),
                _infoLine("الموظف المنفذ", "غير محدد (لا يوجد ربط بموظف في هذا النظام حالياً)"),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text("التقرير المرتبط", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppSizes.sm),
          _buildLinkedReportCard(),
          const SizedBox(height: AppSizes.lg),
          Text("المستندات المرتبطة", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppSizes.sm),
          _buildDocumentsCard(),
        ],
      ),
    );
  }

  Widget _buildFlowCard(RelationshipTxn t) {
    return AppCard(
      child: Column(
        children: [
          _flowStep(Icons.account_circle_outlined, t.payerName, widget.color),
          _flowArrow("حوّل مبلغ ${_format(t.amount)}"),
          if (t.viaAccount.isNotEmpty) ...[
            _flowStep(Icons.account_balance_wallet_outlined, "عن طريق: ${t.viaAccount}", Colors.grey),
            _flowArrow(null),
          ],
          _flowStep(Icons.flag_circle_outlined, t.beneficiaryName, AppColors.success),
          _flowArrow("بتاريخ ${DateFormat('yyyy-MM-dd').format(t.date)}"),
          _flowStep(Icons.description_outlined, t.operationType, AppColors.info),
        ],
      ),
    );
  }

  Widget _flowStep(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
      ],
    );
  }

  Widget _flowArrow(String? label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: AppTextStyles.caption)),
          Expanded(flex: 3, child: Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildLinkedReportCard() {
    if (_loadingReport) {
      return const AppCard(child: Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())));
    }
    if (_linkedReport == null || _reportHotel == null) {
      return AppCard(
        child: Text(
          widget.txn.reportId != null ? "تعذّر تحميل التقرير المرتبط" : "لا يوجد تقرير يومي مرتبط بهذه العملية مباشرة",
          style: AppTextStyles.caption,
        ),
      );
    }
    return AppCard(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailsPage(hotel: _reportHotel!, report: _linkedReport!)));
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: widget.color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined, color: widget.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text("تقرير ${_reportHotel!.arabicName} بتاريخ ${_linkedReport!.date}", style: AppTextStyles.bodyBold.copyWith(fontSize: 13))),
          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard() {
    if (widget.txn.attachments.isNotEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.txn.attachments
              .map((path) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file, color: widget.color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(path.split('/').last, style: AppTextStyles.bodyBold.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("لا توجد مستندات مرفقة بهذه العملية تحديداً.", style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.sm),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsPage(hotel: widget.contextHotel))),
            style: OutlinedButton.styleFrom(foregroundColor: widget.color, side: BorderSide(color: widget.color)),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text("عرض مستندات الفندق"),
          ),
        ],
      ),
    );
  }
}
