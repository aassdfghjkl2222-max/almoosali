import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_sizes.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/financial_report.dart';
import '../../models/hotel.dart';
import '../../models/daily_report_template.dart';
import '../../repositories/shared_expense_repository.dart';
import '../../repositories/vault_repository.dart';
import '../../repositories/inter_entity_transfer_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../services/daily_report_builder.dart';
import '../../services/daily_report_text_renderer.dart';
import '../../services/pdf_service.dart';
import '../../widgets/financial/daily_report_view.dart';

/// عرض تقرير محفوظ سابقاً (للقراءة فقط) — يُفتح من "التقارير السابقة"،
/// بنفس القالب الرسمي الموحّد بالضبط (DailyReportView) مع إمكانية المشاركة/
/// النسخ/تصدير PDF/الطباعة لهذا التقرير المحدَّد فقط.
class SavedReportViewPage extends StatefulWidget {
  final Hotel hotel;
  final FinancialReport report;

  const SavedReportViewPage({super.key, required this.hotel, required this.report});

  @override
  State<SavedReportViewPage> createState() => _SavedReportViewPageState();
}

class _SavedReportViewPageState extends State<SavedReportViewPage> {
  final _sharedExpenseRepository = SharedExpenseRepository();
  final _transferRepository = InterEntityTransferRepository();
  DailyReportTemplate? _template;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shares = await _sharedExpenseRepository.getSharesForHotelAndDate(widget.hotel.id!, widget.report.date);
    final withdrawals = await VaultRepository().getAdvanceWithdrawals(widget.report.hotelId);
    final allTransfers = await _transferRepository.getForHotel(widget.report.hotelId);
    final hotels = await HotelRepository().getAllHotelsIncludingArchived();
    final hotelNames = {for (final h in hotels) if (h.id != null) h.id!: h.arabicName};
    final template = buildTemplateFromSavedReport(
      report: widget.report,
      hotelName: widget.hotel.arabicName,
      sharedExpenseLines: [
        for (final s in shares)
          SharedExpenseTemplateLine(
            description: s.groupDescription ?? '',
            fundingHotelName: s.fundingHotelName ?? '',
            amount: s.amount,
            isFundingHotel: s.isFundingHotel,
          ),
      ],
      vaultWithdrawalsForDate: withdrawals.where((w) => w.date == widget.report.date).toList(),
      transferLines: [
        for (final t in allTransfers)
          if (t.fromHotelId == widget.report.hotelId && t.date == widget.report.date)
            InterHotelTransferTemplateLine(
              statement: t.statement,
              counterpartHotelName: hotelNames[t.toHotelId] ?? "فندق آخر",
              amount: t.amount,
              isOutgoing: true,
            ),
      ],
    );
    if (mounted) setState(() => _template = template);
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    final report = widget.report;
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    final template = _template;
    if (template == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: identityColor),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("تقرير ${DateFormat('yyyy-MM-dd').format(DateTime.parse(report.date))}", style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: "مشاركة نصية",
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => Share.share(renderDailyReportAsText(template)),
          ),
          IconButton(
            tooltip: "نسخ",
            icon: const Icon(Icons.copy, color: Colors.white),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: renderDailyReportAsText(template)));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ التقرير")));
            },
          ),
          IconButton(
            tooltip: "مشاركة PDF",
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () => PdfService.shareDailyReportPdf(template),
          ),
          IconButton(
            tooltip: "طباعة",
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: () => PdfService.printDailyReportPdf(template),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [DailyReportView(template: template)],
      ),
    );
  }
}
