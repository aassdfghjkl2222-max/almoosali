import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_sizes.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/financial_report.dart';
import '../../models/hotel.dart';
import '../../services/daily_report_builder.dart';
import '../../services/daily_report_text_renderer.dart';
import '../../services/pdf_service.dart';
import '../../widgets/financial/daily_report_view.dart';

/// عرض تقرير محفوظ سابقاً (للقراءة فقط) — يُفتح من "التقارير السابقة"،
/// بنفس القالب الرسمي الموحّد بالضبط (DailyReportView) مع إمكانية المشاركة/
/// النسخ/تصدير PDF/الطباعة لهذا التقرير المحدَّد فقط.
class SavedReportViewPage extends StatelessWidget {
  final Hotel hotel;
  final FinancialReport report;

  const SavedReportViewPage({super.key, required this.hotel, required this.report});

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    final template = buildTemplateFromSavedReport(report: report, hotelName: hotel.arabicName);

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
