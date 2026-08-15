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
        if (template.ownerWithdrawalLines.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _buildOwnerWithdrawalCard(context),
        ],
        if (template.transferLines.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _buildTransferCard(context),
        ],
        if (template.sharedExpenseLines.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _buildSharedExpenseCard(context),
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
          const Text("📤 مصروفات خارج إيراد اليوم", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.warning)),
          const SizedBox(height: AppSizes.sm),
          for (final l in template.unwithdrawnLines) ...[
            Row(
              children: [
                Text(l.icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Expanded(child: Text(l.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Text(_currency.format(l.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.warning)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              l.methodLabel != null ? "${l.label} — ${l.methodLabel}" : l.label,
              style: const TextStyle(fontSize: 11, color: AppColors.warning),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (l != template.unwithdrawnLines.last) const Divider(height: AppSizes.md),
          ],
        ],
      ),
    );
  }

  /// تظهر فقط عند وجود سحوبات مالك فعلية بهذا التاريخ (راجع البند 9 من
  /// متطلبات إعادة تصميم التقرير) — عرض معلوماتي بحت، لا تدخل ضمن أي مجموع.
  Widget _buildOwnerWithdrawalCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("👤 مسحوبات المالك", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(height: AppSizes.sm),
          for (final l in template.ownerWithdrawalLines) ...[
            Row(
              children: [
                const Text("💰", style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Expanded(child: Text(l.methodLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text(_currency.format(l.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber)),
              ],
            ),
            if (l != template.ownerWithdrawalLines.last) const Divider(height: AppSizes.md),
          ],
        ],
      ),
    );
  }

  /// تظهر فقط عند وجود تحويلات معلَّقة فعلية بهذا التاريخ — عرض معلوماتي بحت
  /// (ليست مصروفاً، لا تدخل ضمن أي مجموع بهذا التقرير — راجع
  /// InterHotelTransferTemplateLine).
  Widget _buildTransferCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.indigo.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🔄 تحويل بين المنشآت", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: AppSizes.sm),
          for (final l in template.transferLines) ...[
            Row(
              children: [
                Expanded(child: Text(l.statement, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Text(_currency.format(l.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              l.isOutgoing ? "إلى ${l.counterpartHotelName}" : "من ${l.counterpartHotelName}",
              style: const TextStyle(fontSize: 11, color: Colors.indigo),
            ),
            if (l != template.transferLines.last) const Divider(height: AppSizes.md),
          ],
        ],
      ),
    );
  }

  /// عرض معلوماتي فقط — حصص هذا الفندق من "مصروف مشترك" بنفس التاريخ، القيد
  /// المحاسبي نُفِّذ فوراً عند حفظ المصروف المشترك نفسه (لا يدخل ضمن أي مجموع
  /// بهذا التقرير، راجع SharedExpenseTemplateLine).
  Widget _buildSharedExpenseCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🤝 مصروفات مشترَكة (نُفِّذت فوراً، للعرض فقط)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: AppSizes.sm),
          for (final l in template.sharedExpenseLines) ...[
            Row(
              children: [
                Expanded(child: Text(l.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Text(_currency.format(l.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              l.isFundingHotel ? "مموِّل — دُفع المبلغ الإجمالي كاملاً من هذا الفندق" : "مموَّل من ${l.fundingHotelName}",
              style: const TextStyle(fontSize: 11, color: Colors.teal),
            ),
            if (l != template.sharedExpenseLines.last) const Divider(height: AppSizes.md),
          ],
        ],
      ),
    );
  }
}
