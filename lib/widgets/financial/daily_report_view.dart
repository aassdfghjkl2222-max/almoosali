import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../models/daily_report_template.dart';

final _currency = NumberFormat("#,##0.##");

/// عرض القالب الرسمي الموحّد للتقرير المالي اليومي — نفس ترتيب/محتوى نص
/// المشاركة وPDF تماماً (راجع renderDailyReportAsText وPdfService). العناوين
/// الكبيرة الأربعة فقط (📊/💰/💸/💵) بحجم خط كبير؛ كل ما عداها بالحجم
/// الطبيعي — لا يوجد أي منطق حسابي هنا، فقط عرض [DailyReportTemplate] جاهز.
class DailyReportView extends StatelessWidget {
  final DailyReportTemplate template;
  const DailyReportView({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderCard(context, primary),
        if (template.incomeLines.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _buildSectionCard(
            context,
            largeTitle: "💰 الإيرادات اليومية",
            lines: template.incomeLines,
            totalLabel: "✅ إجمالي الإيرادات",
            totalValue: template.totalIncome,
            totalColor: AppColors.success,
          ),
        ],
        if (template.expenseLines.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _buildSectionCard(
            context,
            largeTitle: "💸 المصروفات اليومية",
            lines: template.expenseLines,
            totalLabel: "✅ إجمالي المصروفات",
            totalValue: template.totalExpenses,
            totalColor: AppColors.danger,
          ),
        ],
        if (template.netLines.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _buildSectionCard(
            context,
            largeTitle: "💵 صافي النقد",
            lines: template.netLines,
            totalLabel: "🏁 الإجمالي الصافي",
            totalValue: template.netTotal,
            totalColor: primary,
          ),
        ],
        if (template.unwithdrawnLines.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _buildUnwithdrawnCard(context),
        ],
      ],
    );
  }

  Widget _buildHeaderCard(BuildContext context, Color primary) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: template.isAdditional ? Colors.red.shade50 : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text("📊 التقرير المالي اليومي", style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: primary))),
              if (template.isAdditional)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                  child: const Text("إضافي", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text("🏨 ${template.hotelName}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text("📅 ${template.dayName}  |  📆 ${template.date}", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String largeTitle,
    required List<ReportTemplateLine> lines,
    required String totalLabel,
    required double totalValue,
    required Color totalColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(largeTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSizes.sm),
          for (final l in lines) _buildLineRow(l.label, l.amount),
          const Divider(height: 20),
          _buildLineRow(totalLabel, totalValue, color: totalColor),
        ],
      ),
    );
  }

  Widget _buildLineRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(_currency.format(amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildUnwithdrawnCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🏛️ المصروفات التي لم تُصرف من خزينة الفندق", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSizes.sm),
          for (final l in template.unwithdrawnLines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(l.icon, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l.itemName, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l.label,
                      style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
