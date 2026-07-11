import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/contract.dart';
import '../models/contract_payment.dart';

class ContractReportService {
  static Future<void> generateAndShareContractReport(Contract contract, List<ContractPayment> payments) async {
    final pdf = await _generatePdf(contract, payments);
    final bytes = await pdf.save();
    
    final directory = await getTemporaryDirectory();
    final fileName = "تقرير_عقد_${contract.name}_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final file = File("${directory.path}/$fileName");
    await file.writeAsBytes(bytes);
    
    await Share.shareXFiles([XFile(file.path)], text: "تقرير عقد - ${contract.name}");
  }

  static Future<void> printContractReport(Contract contract, List<ContractPayment> payments) async {
    final pdf = await _generatePdf(contract, payments);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<pw.Document> _generatePdf(Contract contract, List<ContractPayment> payments) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoMedium();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final totalPaid = payments.where((p) => p.status == 'تم السداد').fold(0.0, (sum, p) => sum + p.amount);
    final totalRemaining = contract.totalValue - totalPaid;

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
                pw.Text("تقرير عقد", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateTime.now().toString().split(' ')[0], style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfRow("اسم العقد:", contract.name, boldFont),
                _buildPdfRow("المتعاقد:", contract.contractorName, boldFont),
                _buildPdfRow("تاريخ البداية:", contract.startDate, boldFont),
                _buildPdfRow("تاريخ النهاية:", contract.endDate, boldFont),
                _buildPdfRow("مدة العقد:", "${contract.duration} شهر", boldFont),
                _buildPdfRow("إجمالي القيمة:", "${NumberFormat("#,##0.00").format(contract.totalValue)} ريال", boldFont),
                _buildPdfRow("حالة العقد:", contract.status, boldFont),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryBox("المدفوع", "${NumberFormat("#,##0.00").format(totalPaid)} ريال"),
              _buildSummaryBox("المتبقي", "${NumberFormat("#,##0.00").format(totalRemaining)} ريال"),
              _buildSummaryBox("الدفعات", "${payments.length}"),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text("جدول الدفعات", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ["#", "التاريخ", "المبلغ", "الحالة"],
            data: payments.asMap().entries.map((e) => [
              (e.key + 1).toString(),
              e.value.date,
              "${NumberFormat("#,##0.00").format(e.value.amount)} ريال",
              e.value.status,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildPdfRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(width: 10),
          pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryBox(String label, String value) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
