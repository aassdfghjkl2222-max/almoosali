import 'package:flutter/material.dart';
import '../../core/app_sizes.dart';
import '../../models/daily_report_template.dart';
import '../../widgets/app_button.dart';
import '../../widgets/financial/daily_report_view.dart';

/// معاينة القالب الرسمي الموحّد قبل الاعتماد — نفس عرض DailyReportView
/// المستخدم أيضاً (بمصدر بيانات مطابق) في نص المشاركة/النسخ وPDF. الزر
/// "تأكيد واعتماد" يُظهر حالة تحميل ويُصرِّح بأي خطأ فعلي بدل الفشل الصامت
/// (كانت هذه الشاشة StatelessWidget بلا أي معالجة للاستثناءات سابقاً — إن
/// فشل [onConfirm] لأي سبب كان الزر يبدو "لا يعمل" بلا أي رسالة للمستخدم).
class ReportPreviewPage extends StatefulWidget {
  final DailyReportTemplate template;
  final Future<void> Function() onConfirm;

  const ReportPreviewPage({
    super.key,
    required this.template,
    required this.onConfirm,
  });

  @override
  State<ReportPreviewPage> createState() => _ReportPreviewPageState();
}

class _ReportPreviewPageState extends State<ReportPreviewPage> {
  bool _isSubmitting = false;

  Future<void> _confirm() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.onConfirm();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تعذّر اعتماد التقرير: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              children: [DailyReportView(template: widget.template)],
            ),
          ),
          _buildActionButtons(context),
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
          Expanded(
            child: AppButton(
              text: "✏️ تعديل",
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              backgroundColor: Colors.grey[200],
              foregroundColor: Colors.black87,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: AppButton(
              text: "✅ تأكيد واعتماد",
              onPressed: _isSubmitting ? null : _confirm,
              isLoading: _isSubmitting,
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
