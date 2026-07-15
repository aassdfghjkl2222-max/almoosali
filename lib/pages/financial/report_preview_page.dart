import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../models/financial_report.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';

class ReportPreviewPage extends StatelessWidget {
  final Hotel hotel;
  final FinancialReport report;
  final Map<String, dynamic> detailedData;
  final Future<void> Function() onConfirm;

  const ReportPreviewPage({
    super.key,
    required this.hotel,
    required this.report,
    required this.detailedData,
    required this.onConfirm,
  });

  String _format(num val) => NumberFormat("#,##0.##").format(val);

  @override
  Widget build(BuildContext context) {
    bool isAdditional = report.reportType == 'additional';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("معاينة التقرير النهائي"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildHeader(context, isAdditional),
                const SizedBox(height: AppSizes.md),
                _buildSection(context, "💰 الإيرادات", _buildIncomeRows()),
                const SizedBox(height: AppSizes.md),
                _buildSection(context, "💸 المصروفات النقدية والبنكية", _buildCashExpenseRows()),
                const SizedBox(height: AppSizes.md),
                _buildSection(context, "📑 المصروفات المدينة", _buildDebtExpenseRows()),
                const SizedBox(height: AppSizes.md),
                _buildSection(context, "📈 الزيادة والعجز", _buildAdjustRows()),
                const SizedBox(height: AppSizes.md),
                _buildSection(context, "📊 ملخص الأرصدة النهائية", _buildSummaryRows()),
              ],
            ),
          ),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isAdditional) {
    return AppCard(
      color: isAdditional ? Colors.red.shade50 : Colors.white,
      child: Row(
        children: [
          Icon(Icons.apartment, color: isAdditional ? Colors.red : Theme.of(context).colorScheme.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(hotel.arabicName, style: AppTextStyles.bodyBold.copyWith(fontSize: 18)),
                    if (isAdditional) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                        child: const Text("إضافي", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text("تاريخ التقرير: ${report.date}", style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyBold.copyWith(color: Theme.of(context).colorScheme.primary)),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _buildIncomeRows() {
    final inc = detailedData['income_details'];
    return [
      _row("النقد (كاش)", inc['cash']),
      _row("الشبكة (مدى)", inc['pos']),
      _row("التحويل البنكي", inc['transfer']),
      if (hotel.hasParking) ...[
         _row("مواقف (نقد)", inc['parking_cash']),
         _row("مواقف (شبكة)", inc['parking_pos']),
      ],
      const Divider(),
      _row("إجمالي الإيراد", _format(report.income), color: Colors.green),
    ];
  }

  List<Widget> _buildCashExpenseRows() {
    final exp = detailedData['expense_details'];
    final List others = exp['other'] ?? [];
    
    final rows = <Widget>[
      _row("الإعاشة", exp['subsistence'], method: exp['subsistence_method']),
      _row("الاسترداد", exp['refund'], method: exp['refund_method']),
    ];

    for (var e in others) {
      if (e['method'] == 'نقد' || e['method'] == 'شبكة' || e['method'] == 'مصروف خاص') {
        rows.add(_row(e['name'], e['amount'].toString(), method: e['method']));
      }
    }

    if (rows.isEmpty) return [];
    return rows;
  }

  List<Widget> _buildDebtExpenseRows() {
    final exp = detailedData['expense_details'];
    final List others = exp['other'] ?? [];
    final rows = <Widget>[];

    for (var e in others) {
      if (e['method'] != 'نقد' && e['method'] != 'شبكة' && e['method'] != 'مصروف خاص') {
        rows.add(_row(e['name'], e['amount'].toString(), method: e['method'], color: Colors.orange));
      }
    }
    return rows;
  }

  List<Widget> _buildAdjustRows() {
    final adj = detailedData['adjustments'];
    double inc = double.tryParse(adj['increase'].toString()) ?? 0;
    double sho = double.tryParse(adj['shortage'].toString()) ?? 0;
    
    final rows = <Widget>[];
    if (inc > 0) rows.add(_row("زيادة (${adj['increase_effect']})", inc.toString(), color: Colors.green));
    if (sho > 0) rows.add(_row("عجز (${adj['shortage_effect']})", sho.toString(), color: Colors.red));
    return rows;
  }

  List<Widget> _buildSummaryRows() {
    return [
      _row("صافي النقد (للخزنة)", detailedData['net_cash'], color: Colors.blue),
      _row("صافي الشبكة (للبنك)", detailedData['net_pos'], color: Colors.purple),
      const Divider(),
      _row("إجمالي المصروفات", _format(report.expenses), color: AppColors.danger),
    ];
  }

  Widget _row(String label, dynamic val, {Color? color, String? method}) {
    String valueStr = val?.toString() ?? "";
    if (valueStr == "0" || valueStr == "0.0" || valueStr.isEmpty) return const SizedBox.shrink();
    
    double? numericVal = double.tryParse(valueStr);
    String displayVal = numericVal != null ? _format(numericVal) : valueStr;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
          Row(
            children: [
              if (method != null) Text("($method) ", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(displayVal, style: AppTextStyles.bodyBold.copyWith(color: color, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Theme.of(context).scaffoldBackgroundColor))),
      child: Row(
        children: [
          Expanded(child: AppButton(text: "✏️ تعديل", onPressed: () => Navigator.pop(context), backgroundColor: Colors.grey[200], foregroundColor: Colors.black87)),
          const SizedBox(width: AppSizes.md),
          Expanded(child: AppButton(text: "✅ تأكيد واعتماد", onPressed: onConfirm, backgroundColor: Colors.green)),
        ],
      ),
    );
  }
}
