import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/daily_report_template.dart';
import '../models/financial_report.dart';
import '../models/invoice.dart';
import '../models/settlement.dart';
import '../models/settlement_account.dart';

class PdfService {
  /// تصدير قائمة تقارير مفلترة (قسم "التقارير" داخل مركز التحليل) — يتّبع نمط
  /// [ContractReportService] (خطوط Cairo عربية + جدول RTL) بخلاف بقية دوال هذا
  /// الملف التي لا تحمّل خطاً عربياً.
  static Future<pw.Document> _buildReportsListPdf({
    required List<FinancialReport> reports,
    required Map<int, String> hotelNames,
    required String filtersSummary,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoMedium();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final currency = NumberFormat("#,##0.##");

    double totalIncome = 0, totalExpenses = 0;
    for (final r in reports) {
      totalIncome += r.income;
      totalExpenses += r.expenses;
    }

    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("تقارير مركز التحليل", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateTime.now().toString().split(' ')[0], style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (filtersSummary.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text("الفلاتر المطبقة: $filtersSummary", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryBox("عدد التقارير", "${reports.length}"),
              _summaryBox("إجمالي الإيرادات", "${currency.format(totalIncome)} ر.س"),
              _summaryBox("إجمالي المصروفات", "${currency.format(totalExpenses)} ر.س"),
              _summaryBox("الصافي", "${currency.format(totalIncome - totalExpenses)} ر.س"),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ["الفندق", "التاريخ", "الحالة", "الإيرادات", "المصروفات", "الصافي"],
            data: reports.map((r) => [
              hotelNames[r.hotelId] ?? 'فندق #${r.hotelId}',
              r.date,
              r.isPosted ? 'مرحّل' : 'غير مرحّل',
              currency.format(r.income),
              currency.format(r.expenses),
              currency.format(r.income - r.expenses),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: boldFont),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );
    return pdf;
  }

  /// تقرير مالي يومي واحد (PDF كامل) — يعرض [DailyReportTemplate] بنفس
  /// الترتيب والمحتوى وتدرّج الخطوط المعتمد في عرض المعاينة داخل التطبيق
  /// (DailyReportView) وفي نص المشاركة (renderDailyReportAsText) حرفياً،
  /// حتى يكون هناك قالب رسمي واحد موحّد عبر المخرجات الثلاثة. العناوين
  /// الكبيرة الأربعة فقط بخط أكبر؛ كل ما عداها بالحجم العادي.
  static Future<pw.Document> _buildDailyReportPdf(DailyReportTemplate t) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoMedium();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final currency = NumberFormat("#,##0.##");

    pw.Widget lineRow(String label, double amount, {PdfColor? color}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 11))),
              pw.SizedBox(width: 8),
              pw.Text(currency.format(amount), style: pw.TextStyle(fontSize: 11, font: boldFont, color: color)),
            ],
          ),
        );

    pw.Widget sectionCard(String largeTitle, List<ReportTemplateLine> lines, String totalLabel, double totalValue, PdfColor totalColor) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(largeTitle, style: pw.TextStyle(fontSize: 15, font: boldFont)),
            pw.SizedBox(height: 6),
            ...lines.map((l) => lineRow(l.label, l.amount)),
            pw.Divider(color: PdfColors.grey300),
            lineRow(totalLabel, totalValue, color: totalColor),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("📊 التقرير المالي اليومي", style: pw.TextStyle(fontSize: 20, font: boldFont)),
                if (t.isAdditional) pw.Text("(تقرير إضافي)", style: const pw.TextStyle(fontSize: 11, color: PdfColors.red)),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text("🏨 ${t.hotelName}", style: const pw.TextStyle(fontSize: 13)),
          pw.SizedBox(height: 2),
          pw.Text("📅 ${t.dayName}  |  📆 ${t.date}", style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          if (t.incomeLines.isNotEmpty) sectionCard("💰 الإيرادات اليومية", t.incomeLines, "✅ إجمالي الإيرادات", t.totalIncome, PdfColors.green700),
          if (t.expenseLines.isNotEmpty) sectionCard("💸 المصروفات اليومية", t.expenseLines, "✅ إجمالي المصروفات", t.totalExpenses, PdfColors.red700),
          if (t.netLines.isNotEmpty) sectionCard("💵 صافي النقد", t.netLines, "🏁 الإجمالي الصافي", t.netTotal, PdfColors.blueGrey800),
          if (t.unwithdrawnLines.isNotEmpty) ...[
            pw.Text("🏛️ المصروفات التي لم تُصرف من خزينة الفندق", style: pw.TextStyle(fontSize: 12, font: boldFont)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ["البند", "السبب"],
              data: t.unwithdrawnLines.map((l) => [l.itemName, "${l.icon} ${l.label}"]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: boldFont, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerRight,
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  static Future<void> shareDailyReportPdf(DailyReportTemplate t) async {
    final pdf = await _buildDailyReportPdf(t);
    final bytes = await pdf.save();
    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/تقرير_${t.hotelName}_${t.date}_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: "تقرير فندق ${t.hotelName} بتاريخ ${t.date}");
  }

  /// طباعة مباشرة (بدل المشاركة) — لخيار "الطباعة" في شاشة "التقارير السابقة".
  static Future<void> printDailyReportPdf(DailyReportTemplate t) async {
    final pdf = await _buildDailyReportPdf(t);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _summaryBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  static Future<void> shareReportsListPdf({
    required List<FinancialReport> reports,
    required Map<int, String> hotelNames,
    String filtersSummary = '',
  }) async {
    final pdf = await _buildReportsListPdf(reports: reports, hotelNames: hotelNames, filtersSummary: filtersSummary);
    final bytes = await pdf.save();
    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/تقارير_مركز_التحليل_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: "تقارير مركز التحليل (${reports.length} تقرير)");
  }

  static Future<void> printReportsListPdf({
    required List<FinancialReport> reports,
    required Map<int, String> hotelNames,
    String filtersSummary = '',
  }) async {
    final pdf = await _buildReportsListPdf(reports: reports, hotelNames: hotelNames, filtersSummary: filtersSummary);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  /// تصدير قائمة فواتير ضريبية مفلترة (شاشة "تقارير الفواتير الضريبية") —
  /// نفس نمط [_buildReportsListPdf] تماماً (خطوط Cairo عربية + جدول RTL +
  /// صناديق إجماليات)، لأغراض PDF فقط — تصدير Excel المكافئ موجود أصلاً في
  /// ExcelService.exportInvoicesDetailedReport.
  static Future<pw.Document> _buildInvoicesListPdf({
    required List<Invoice> invoices,
    required String scopeLabel,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoMedium();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final currency = NumberFormat("#,##0.##");

    double totalBeforeTax = 0, totalVat = 0, totalAmount = 0;
    for (final inv in invoices) {
      totalBeforeTax += inv.amountBeforeTax;
      totalVat += inv.vat;
      totalAmount += inv.totalAmount;
    }

    final dateFmt = DateFormat('yyyy-MM-dd');
    final periodLabel = fromDate != null && toDate != null ? "${dateFmt.format(fromDate)} → ${dateFmt.format(toDate)}" : "كل الفترات";

    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("تقرير الفواتير الضريبية", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateTime.now().toString().split(' ')[0], style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text("النطاق: $scopeLabel — الفترة: $periodLabel", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryBox("عدد الفواتير", "${invoices.length}"),
              _summaryBox("قبل الضريبة", "${currency.format(totalBeforeTax)} ر.س"),
              _summaryBox("الضريبة", "${currency.format(totalVat)} ر.س"),
              _summaryBox("الإجمالي", "${currency.format(totalAmount)} ر.س"),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ["رقم الفاتورة", "التاريخ", "المورد", "الرقم الضريبي", "قبل الضريبة", "الضريبة", "الإجمالي", "التصنيف", "مصدر التمويل"],
            data: invoices.map((inv) => [
              inv.invoiceNumber,
              inv.date,
              inv.companyName,
              inv.taxNumber,
              currency.format(inv.amountBeforeTax),
              currency.format(inv.vat),
              currency.format(inv.totalAmount),
              inv.expenseCategory ?? 'غير مصنَّف',
              inv.amountSource,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: boldFont, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );
    return pdf;
  }

  static Future<void> shareInvoicesListPdf({
    required List<Invoice> invoices,
    required String scopeLabel,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdf = await _buildInvoicesListPdf(invoices: invoices, scopeLabel: scopeLabel, fromDate: fromDate, toDate: toDate);
    final bytes = await pdf.save();
    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/تقرير_الفواتير_الضريبية_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: "تقرير الفواتير الضريبية (${invoices.length} فاتورة)");
  }

  static Future<void> printInvoicesListPdf({
    required List<Invoice> invoices,
    required String scopeLabel,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdf = await _buildInvoicesListPdf(invoices: invoices, scopeLabel: scopeLabel, fromDate: fromDate, toDate: toDate);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> shareSettlementPdf({
    required Settlement settlement,
    required String creditorName,
    required String debtorName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Financial Settlement Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Manazel App", style: const pw.TextStyle(color: PdfColors.grey)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Report Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"),
                      pw.Text("Transaction Date: ${settlement.date.day}/${settlement.date.month}/${settlement.date.year}"),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: settlement.status == 'paid' ? PdfColors.green : PdfColors.orange,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    child: pw.Text(
                      settlement.status.toUpperCase(),
                      style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),
              _buildSectionTitle("Parties Involved"),
              pw.Row(
                children: [
                  pw.Expanded(child: _buildInfoBox("Creditor", creditorName)),
                  pw.SizedBox(width: 20),
                  pw.Expanded(child: _buildInfoBox("Debtor", debtorName)),
                ],
              ),
              pw.SizedBox(height: 30),
              _buildSectionTitle("Financial Details"),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _buildTableRow("Original Amount", "${NumberFormat("#,##0.00").format(settlement.amount)} SAR"),
                  _buildTableRow("Total Paid", "${NumberFormat("#,##0.00").format(settlement.totalPaid)} SAR"),
                  _buildTableRow("Remaining Amount", "${NumberFormat("#,##0.00").format(settlement.remainingAmount)} SAR", isBold: true),
                ],
              ),
              pw.SizedBox(height: 30),
              _buildSectionTitle("Description"),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
                ),
                child: pw.Text(settlement.description, style: const pw.TextStyle(fontSize: 12)),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text("This is an official financial report generated by Manazel App", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final fileName = "Settlement_${settlement.id}_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: "Financial Settlement Report - $creditorName to $debtorName");
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
    );
  }

  static pw.Widget _buildInfoBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.TableRow _buildTableRow(String label, String value, {bool isBold = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal), textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  static Future<void> shareAccountPdf({
    required SettlementAccount account,
    required List<Settlement> settlements,
    required Map<String, dynamic> summary,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Account Statement", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Manazel App", style: const pw.TextStyle(color: PdfColors.grey)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Account Name: ${account.name}"),
            pw.Text("Account Type: ${account.type.toUpperCase()}"),
            pw.Text("Generated on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),
            _buildSectionTitle("Summary"),
            pw.Row(
              children: [
                pw.Expanded(child: _buildInfoBox("Due to You", "${summary['totalDueToMe']} SAR")),
                pw.SizedBox(width: 10),
                pw.Expanded(child: _buildInfoBox("You Owe", "${summary['totalIOwe']} SAR")),
                pw.SizedBox(width: 10),
                pw.Expanded(child: _buildInfoBox("Balance", "${summary['remaining']} SAR")),
              ],
            ),
            pw.SizedBox(height: 30),
            _buildSectionTitle("Operations History"),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FixedColumnWidth(80),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell("Date", isHeader: true),
                    _buildTableCell("Description", isHeader: true),
                    _buildTableCell("Type", isHeader: true),
                    _buildTableCell("Amount", isHeader: true),
                  ],
                ),
                ...settlements.map((s) => pw.TableRow(
                  children: [
                    _buildTableCell("${s.date.day}/${s.date.month}/${s.date.year}"),
                    _buildTableCell(s.description),
                    _buildTableCell(s.direction == 'to_me' ? "IN" : "OUT"),
                    _buildTableCell("${NumberFormat("#,##0.00").format(s.amount)} SAR"),
                  ],
                )),
              ],
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final fileName = "Account_${account.name}_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: "Account Statement - ${account.name}");
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10),
      ),
    );
  }
}
