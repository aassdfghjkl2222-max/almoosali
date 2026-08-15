import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_radius.dart';
import '../../models/hotel.dart';
import '../../models/financial_report.dart';
import '../../repositories/financial_repository.dart';
import '../../services/excel_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import 'financial_summary_page.dart';

class MonthlyReportPage extends StatefulWidget {
  final Hotel hotel;
  final DateTime initialDate;

  const MonthlyReportPage({
    super.key,
    required this.hotel,
    required this.initialDate,
  });

  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  late DateTime _fromDate;
  late DateTime _toDate;
  final FinancialRepository _repository = FinancialRepository();
  List<FinancialReport> _reports = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
    _toDate = widget.initialDate;
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _repository.getFinancialReportsInRange(
        hotelId: widget.hotel.id ?? 0,
        startDate: _fromDate.toIso8601String(),
        endDate: _toDate.toIso8601String(),
      );
      setState(() {
        _reports = reports.reversed.toList(); // Newest to oldest
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ في تحميل التقارير: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "التقرير الشهري والمراجعة",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          children: [
            _buildPeriodSelector(),
            _buildActionButtons(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "📄 التقارير اليومية",
                  style: AppTextStyles.title,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _reports.isEmpty
                      ? _buildEmptyState()
                      : _buildReportsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: AppCard(
        identityAccent: Theme.of(context).colorScheme.primary,
        child: Row(
          children: [
            Expanded(
              child: _buildDateItem("من:", _fromDate, () => _selectDate(true)),
            ),
            const VerticalDivider(width: AppSizes.md),
            Expanded(
              child: _buildDateItem("إلى:", _toDate, () => _selectDate(false)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateItem(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSizes.xs),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSizes.xs),
              Text(
                "${date.day}/${date.month}/${date.year}",
                style: AppTextStyles.bodyBold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      locale: const Locale('ar', 'SA'),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _loadReports();
    }
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              text: "عرض",
              onPressed: _showReportSummary,
              icon: Icons.analytics,
              height: 45,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: AppButton(
              text: "نسخ",
              onPressed: _copyReport,
              icon: Icons.copy,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              height: 45,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: AppButton(
              text: "مشاركة",
              onPressed: _showShareOptions,
              icon: Icons.share,
              backgroundColor: Colors.blue[700],
              height: 45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final date = DateTime.parse(report.date);
        final dayName = _getDayName(date.weekday);
        final dateStr = "${date.day}/${date.month}/${date.year}";

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
          child: AppCard(
            onTap: () => _openDailyReport(date),
            identityAccent: Theme.of(context).colorScheme.primary,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$dayName $dateStr", style: AppTextStyles.bodyBold),
                      Text(
                        "صافي: ${report.income - report.expenses} ر.س",
                        style: AppTextStyles.caption.copyWith(
                          color: (report.income - report.expenses) < 0 ? AppColors.danger : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: AppSizes.md),
          Text(
            "لا توجد تقارير محفوظة في هذه الفترة",
            style: AppTextStyles.body.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _getDayName(int day) {
    switch (day) {
      case DateTime.sunday: return "الأحد";
      case DateTime.monday: return "الاثنين";
      case DateTime.tuesday: return "الثلاثاء";
      case DateTime.wednesday: return "الأربعاء";
      case DateTime.thursday: return "الخميس";
      case DateTime.friday: return "الجمعة";
      case DateTime.saturday: return "السبت";
      default: return "";
    }
  }

  void _openDailyReport(DateTime date) async {
    // Navigate to Daily Report page for that date
    // We need to pass the date and make sure the page loads it
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinancialSummaryPage(
          hotel: widget.hotel,
          initialDate: date,
        ),
      ),
    );
    _loadReports(); // Refresh list when coming back
  }

  void _showReportSummary() {
    if (_reports.isEmpty) return;
    final reportText = _generateMonthlyReportSummary();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("ملخص التقرير المجمع", textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: AppCard(
            identityAccent: Theme.of(context).colorScheme.primary,
            child: Text(
              reportText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              textDirection: ui.TextDirection.rtl,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إغلاق"),
          ),
        ],
      ),
    );
  }

  void _copyReport() {
    if (_reports.isEmpty) return;
    final text = _generateMonthlyReportSummary();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ التقرير")));
  }

  void _showShareOptions() {
    if (_reports.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("خيارات المشاركة", style: AppTextStyles.title),
              const SizedBox(height: AppSizes.md),
              ListTile(
                leading: Icon(Icons.text_snippet, color: Theme.of(context).colorScheme.primary),
                title: const Text("مشاركة كنص"),
                onTap: () {
                  Navigator.pop(context);
                  _shareText();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: AppColors.danger),
                title: const Text("مشاركة PDF"),
                onTap: () {
                  Navigator.pop(context);
                  _sharePdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_view, color: Colors.green),
                title: const Text("تصدير Excel (احترافي)"),
                onTap: () {
                  Navigator.pop(context);
                  _exportExcel();
                },
              ),
              const SizedBox(height: AppSizes.md),
            ],
          ),
        ),
      ),
    );
  }

  void _shareText() {
    final text = _generateMonthlyReportSummary();
    Share.share(text);
  }

  Future<void> _sharePdf() async {
    // Basic PDF implementation adapted from FinancialSummaryPage
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, text: "Financial Report - ${widget.hotel.englishName}"),
                pw.Paragraph(text: "Hotel: ${widget.hotel.arabicName}"),
                pw.Paragraph(text: "Period: ${_fromDate.day}/${_fromDate.month} - ${_toDate.day}/${_toDate.month}"),
                pw.Divider(),
                pw.Text("Monthly Summary (Aggregated from ${_reports.length} daily reports)"),
                // Add more aggregated data here...
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/monthly_report.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: "التقرير الشهري - ${widget.hotel.arabicName}");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء إنشاء PDF: $e")));
      }
    }
  }

  Future<void> _exportExcel() async {
    try {
      setState(() => _isLoading = true);
      await ExcelService.exportFinancialReport(
        hotel: widget.hotel,
        reports: _reports,
        fromDate: _fromDate,
        toDate: _toDate,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء إنشاء ملف Excel: $e")));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _generateMonthlyReportSummary() {
    double aggCash = 0, aggPos = 0, aggTransfer = 0, aggParkingCash = 0, aggParkingPos = 0;
    double aggSubsistence = 0, aggRefund = 0, aggCashToPos = 0, aggOtherExpenses = 0;
    double aggIncrease = 0, aggShortage = 0;
    double aggNetCash = 0, aggNetPos = 0;

    for (var report in _reports) {
      if (report.detailsJson != null) {
        try {
          final details = jsonDecode(report.detailsJson!);
          final income = details['income_details'] ?? {};
          final expense = details['expense_details'] ?? {};
          final adjust = details['adjustments'] ?? {};

          double cash = double.tryParse(income['cash']?.toString() ?? "0") ?? 0;
          double pos = double.tryParse(income['pos']?.toString() ?? "0") ?? 0;
          double pCash = double.tryParse(income['parking_cash']?.toString() ?? "0") ?? 0;
          double pPos = double.tryParse(income['parking_pos']?.toString() ?? "0") ?? 0;
          double trans = double.tryParse(income['transfer']?.toString() ?? "0") ?? 0;

          aggCash += cash; aggPos += pos; aggTransfer += trans;
          aggParkingCash += pCash; aggParkingPos += pPos;

          double sub = double.tryParse(expense['subsistence']?.toString() ?? "0") ?? 0;
          double ref = double.tryParse(expense['refund']?.toString() ?? "0") ?? 0;
          double c2p = double.tryParse(expense['cash_to_pos']?.toString() ?? "0") ?? 0;
          String subM = expense['subsistence_method'] ?? "نقد";
          String refM = expense['refund_method'] ?? "نقد";

          aggSubsistence += sub; aggRefund += ref; aggCashToPos += c2p;

          // فقط "نقد" يُخصَم من صافي اليوم — أي طريقة أخرى (شبكة/بنك، الخزنة،
          // شخصي، آجل (دين)، ...) لا تُخصَم من صافي النقد ولا صافي الشبكة هنا
          // إطلاقاً بعد الآن (نفس تصنيف oCash/oDebt في
          // FinancialSummaryPage._calculateTotals — "لا فرق بين البنك
          // والشبكة"، والخصم الفعلي من رصيد البنك يحدث فقط عند الترحيل عبر
          // VaultRepository._postNetworkFundedExpenses). كانت "شبكة" و"آجل"
          // تُصنَّفان خطأً كمصروف شبكة هنا سابقاً.
          double otherCash = 0;
          final others = expense['other'] as List? ?? [];
          for (var item in others) {
            double amt = double.tryParse(item['amount']?.toString() ?? "0") ?? 0;
            final method = item['method']?.toString() ?? "";
            if (method == "نقد") otherCash += amt;
            aggOtherExpenses += amt;
          }

          double inc = double.tryParse(adjust['increase']?.toString() ?? "0") ?? 0;
          double sho = double.tryParse(adjust['shortage']?.toString() ?? "0") ?? 0;
          String incEff = adjust['increase_effect'] ?? "نقد";
          String shoEff = adjust['shortage_effect'] ?? "نقد";

          aggIncrease += inc; aggShortage += sho;

          aggNetCash += (cash + pCash + (incEff == "نقد" ? inc : 0)) -
              ((subM == "نقد" ? sub : 0) + (refM == "نقد" ? ref : 0) + c2p + otherCash + (shoEff == "نقد" ? sho : 0));

          aggNetPos += (pos + pPos + (incEff == "شبكة" ? inc : 0) + c2p) -
              (shoEff == "شبكة" ? sho : 0);
        } catch (_) {}
      }
    }

    double totalInc = aggCash + aggPos + aggTransfer + aggParkingCash + aggParkingPos;
    double totalExp = aggSubsistence + aggRefund + aggOtherExpenses;
    double finalBalance = aggNetCash + aggNetPos + aggTransfer;

    StringBuffer buffer = StringBuffer();
    buffer.writeln("📋 *التقرير المالي المجمع*");
    buffer.writeln("🏨 الفندق: ${widget.hotel.arabicName}");
    buffer.writeln("📅 الفترة: ${_fromDate.day}/${_fromDate.month}/${_fromDate.year} - ${_toDate.day}/${_toDate.month}/${_toDate.year}");
    buffer.writeln("━━━━━━━━━━━━━━");
    
    buffer.writeln("💰 *الإيرادات*");
    _addAggLine(buffer, "💵 النقد", aggCash);
    _addAggLine(buffer, "💳 الشبكة", aggPos);
    _addAggLine(buffer, "🏦 التحويل", aggTransfer);
    if (aggParkingCash > 0) _addAggLine(buffer, "🅿️ مواقف نقد", aggParkingCash);
    if (aggParkingPos > 0) _addAggLine(buffer, "🅿️ مواقف شبكة", aggParkingPos);
    buffer.writeln("🧾 إجمالي الإيرادات: ${NumberFormat("#,##0.00").format(totalInc)} ر.س");
    
    buffer.writeln("━━━━━━━━━━━━━━");
    buffer.writeln("💸 *المصروفات*");
    _addAggLine(buffer, "🍽️ الإعاشة", aggSubsistence);
    _addAggLine(buffer, "↩️ الاسترداد", aggRefund);
    _addAggLine(buffer, "🔄 تحويل نقد لشبكة", aggCashToPos);
    _addAggLine(buffer, "🧾 مصروفات أخرى", aggOtherExpenses);
    buffer.writeln("🧾 إجمالي المصروفات: ${NumberFormat("#,##0.00").format(totalExp)} ر.س");
    
    buffer.writeln("━━━━━━━━━━━━━━");
    if (aggIncrease > 0) buffer.writeln("📈 إجمالي الزيادة: ${NumberFormat("#,##0.00").format(aggIncrease)} ر.س");
    if (aggShortage > 0) buffer.writeln("📉 إجمالي النقص: ${NumberFormat("#,##0.00").format(aggShortage)} ر.س");
    if (aggIncrease > 0 || aggShortage > 0) buffer.writeln("━━━━━━━━━━━━━━");
    
    buffer.writeln("📊 *النتائج النهائية*");
    _addAggResultLine(buffer, "💵 صافي النقد", aggNetCash);
    _addAggResultLine(buffer, "💳 صافي الشبكة", aggNetPos);
    _addAggResultLine(buffer, "🧾 الرصيد النهائي", finalBalance);
    buffer.writeln("━━━━━━━━━━━━━━");
    
    return buffer.toString().trim();
  }

  void _addAggLine(StringBuffer buffer, String label, double val) {
    if (val != 0) buffer.writeln("$label: ${NumberFormat("#,##0.00").format(val)} ر.س");
  }

  void _addAggResultLine(StringBuffer buffer, String label, double val) {
    String icon = val < 0 ? "🔴" : "";
    buffer.writeln("$label: $icon${NumberFormat("#,##0.00").format(val)} ر.س");
  }
}
