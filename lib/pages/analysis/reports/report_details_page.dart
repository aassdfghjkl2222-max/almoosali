import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/financial_report.dart';
import '../../../models/hotel.dart';
import '../../../pages/dashboard/pages/documents_page.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import 'report_amount_breakdown_page.dart';

/// شاشة تفاصيل تقرير واحد — للقراءة فقط تماماً، بلا أي إمكانية تعديل أو حذف
/// أو ترحيل (أي تعديل فعلي يتم فقط من شاشة التقرير الأصلية خارج مركز التحليل).
class ReportDetailsPage extends StatelessWidget {
  final Hotel hotel;
  final FinancialReport report;

  const ReportDetailsPage({super.key, required this.hotel, required this.report});

  Map<String, dynamic> get _details {
    if (report.detailsJson == null || report.detailsJson!.isEmpty) return {};
    try {
      return jsonDecode(report.detailsJson!) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  List<BreakdownItem> get _incomeItems {
    final d = _details['income_details'] as Map<String, dynamic>? ?? {};
    final labels = {
      'cash': 'نقد',
      'parking_cash': 'باركنج (نقد)',
      'pos': 'شبكة',
      'parking_pos': 'باركنج (شبكة)',
      'transfer': 'تحويل بنكي',
    };
    final items = <BreakdownItem>[];
    labels.forEach((key, label) {
      final v = double.tryParse(d[key]?.toString() ?? '0') ?? 0;
      if (v > 0) items.add(BreakdownItem(label, v));
    });
    return items;
  }

  List<BreakdownItem> get _expenseItems {
    final d = _details['expense_details'] as Map<String, dynamic>? ?? {};
    final items = <BreakdownItem>[];
    final other = d['other'] as List? ?? [];
    for (final e in other) {
      final amt = double.tryParse(e['amount']?.toString() ?? '0') ?? 0;
      if (amt > 0) items.add(BreakdownItem(e['name']?.toString() ?? 'مصروف', amt, subtitle: e['method']?.toString()));
    }
    final subsistence = double.tryParse(d['subsistence']?.toString() ?? '0') ?? 0;
    if (subsistence > 0) items.add(BreakdownItem('إعاشة', subsistence, subtitle: d['subsistence_method']?.toString()));
    final refund = double.tryParse(d['refund']?.toString() ?? '0') ?? 0;
    if (refund > 0) items.add(BreakdownItem('استرداد', refund, subtitle: d['refund_method']?.toString()));
    final cashToPos = double.tryParse(d['cash_to_pos']?.toString() ?? '0') ?? 0;
    if (cashToPos > 0) items.add(BreakdownItem('تحويل نقد لشبكة', cashToPos));
    return items;
  }

  List<BreakdownItem> get _adjustmentItems {
    final d = _details['adjustments'] as Map<String, dynamic>? ?? {};
    final items = <BreakdownItem>[];
    final increase = double.tryParse(d['increase']?.toString() ?? '0') ?? 0;
    if (increase > 0) items.add(BreakdownItem('زيادة في العهدة', increase, subtitle: d['increase_effect']?.toString()));
    final shortage = double.tryParse(d['shortage']?.toString() ?? '0') ?? 0;
    if (shortage > 0) items.add(BreakdownItem('عجز في العهدة', shortage, subtitle: d['shortage_effect']?.toString()));
    return items;
  }

  double get _cashTotal {
    final d = _details['income_details'] as Map<String, dynamic>? ?? {};
    return (double.tryParse(d['cash']?.toString() ?? '0') ?? 0) + (double.tryParse(d['parking_cash']?.toString() ?? '0') ?? 0);
  }

  double get _bankTotal {
    final d = _details['income_details'] as Map<String, dynamic>? ?? {};
    return (double.tryParse(d['pos']?.toString() ?? '0') ?? 0) +
        (double.tryParse(d['parking_pos']?.toString() ?? '0') ?? 0) +
        (double.tryParse(d['transfer']?.toString() ?? '0') ?? 0);
  }

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  void _openBreakdown(BuildContext context, String title, List<BreakdownItem> items, Color color) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportAmountBreakdownPage(hotel: hotel, title: title, items: items, color: color)));
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    final net = report.income - report.expenses;
    final adjustments = _adjustmentItems;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "تفاصيل التقرير #${report.id}", hotel: hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          _buildHeaderCard(identityColor),
          const SizedBox(height: AppSizes.lg),
          _buildTapRow(context, "الإيرادات", report.income, const Color(0xFF1FA971), Icons.trending_up_outlined, () => _openBreakdown(context, "تفاصيل الإيرادات", _incomeItems, const Color(0xFF1FA971))),
          const SizedBox(height: AppSizes.sm),
          _buildTapRow(context, "المصروفات", report.expenses, const Color(0xFFE0524A), Icons.trending_down_outlined, () => _openBreakdown(context, "تفاصيل المصروفات", _expenseItems, const Color(0xFFE0524A))),
          if (adjustments.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            _buildTapRow(context, "التعديلات (زيادة/عجز)", adjustments.fold(0.0, (s, i) => s + i.amount), const Color(0xFFD9743C), Icons.tune_outlined, () => _openBreakdown(context, "تفاصيل التعديلات", adjustments, const Color(0xFFD9743C))),
          ],
          const SizedBox(height: AppSizes.lg),
          _buildFinancialPositionCard(identityColor, net),
          const SizedBox(height: AppSizes.lg),
          _buildMetaCard(),
          const SizedBox(height: AppSizes.lg),
          _buildDocumentsCard(context, identityColor),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Color color) {
    return AppCard(
      identityAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.receipt_long_outlined, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hotel.arabicName, style: AppTextStyles.title.copyWith(fontSize: 17, color: color)),
                    const SizedBox(height: 2),
                    Text(hotel.city, style: AppTextStyles.caption),
                  ],
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const Divider(height: AppSizes.lg),
          Row(
            children: [
              Expanded(child: _metaStat(Icons.date_range_outlined, "تاريخ التقرير", report.date)),
              Expanded(child: _metaStat(Icons.category_outlined, "نوع التقرير", report.reportType == 'main' ? 'رئيسي' : 'إضافي')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaStat(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final isPosted = report.isPosted;
    final color = isPosted ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(isPosted ? "مرحّل" : "غير مرحّل", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildTapRow(BuildContext context, String title, double amount, Color color, IconData icon, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: AppTextStyles.bodyBold),
        subtitle: const Text("اضغط لعرض التفاصيل", style: AppTextStyles.caption),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_format(amount), style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFinancialPositionCard(Color color, double net) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("المركز المالي", style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(child: _metaStat(Icons.payments_outlined, "نقد", _format(_cashTotal))),
              Expanded(child: _metaStat(Icons.account_balance_outlined, "بنك/شبكة", _format(_bankTotal))),
              Expanded(child: _metaStat(Icons.equalizer_outlined, "الصافي", _format(net))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("بيانات الإنشاء والترحيل", style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
          const SizedBox(height: AppSizes.md),
          _infoLine("الموظف الذي أنشأ التقرير", (report.employeeName?.isNotEmpty ?? false) ? report.employeeName! : "غير محدد"),
          _infoLine("تاريخ الإنشاء", report.createdAt.split('T').first),
          _infoLine("حالة الترحيل", report.isPosted ? "مرحّل إلى الخزنة (تاريخ الترحيل الدقيق غير مسجَّل في النظام)" : "معتمد — لم يُرحَّل بعد"),
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

  Widget _buildDocumentsCard(BuildContext context, Color color) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("المستندات المرتبطة", style: AppTextStyles.bodyBold.copyWith(fontSize: 15)),
          const SizedBox(height: AppSizes.sm),
          const Text(
            "لا يوجد حالياً ربط مباشر بين المستندات والتقرير المحدد في النظام — يمكنك تصفح جميع مستندات الفندق من الزر أدناه.",
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSizes.sm),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsPage(hotel: hotel))),
            style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text("عرض مستندات الفندق"),
          ),
        ],
      ),
    );
  }
}
