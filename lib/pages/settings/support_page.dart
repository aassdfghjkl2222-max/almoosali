import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';

/// صفحة "الدعم والمساعدة" — دليل استخدام سريع لأهم أقسام التطبيق. لا تحتوي
/// على أي وسيلة تواصل (بريد/هاتف) لأنه لا توجد قناة دعم مُهيَّأة فعلياً في
/// التطبيق حتى الآن؛ البنية جاهزة لإضافتها لاحقاً دون إعادة تصميم الصفحة.
/// "الإبلاغ عن مشكلة" يوفَّر عبر نسخ معلومات نظام حقيقية بدل قناة وهمية.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  static const _faqs = [
    ("كيف أضيف فندقاً جديداً؟", "من الصفحة الرئيسية اضغط على زر إضافة فندق، ثم أدخل بياناته واختر لون هويته البصرية."),
    ("كيف أرحّل التقرير اليومي؟", "من داخل الفندق افتح \"التقرير المالي\"، ثم بعد تعبئة البيانات اضغط \"تعيين\" لمراجعتها واعتمادها."),
    ("أين أجد تحليلاً شاملاً لأداء الفندق؟", "من لوحة تحكم الفندق افتح \"مركز التحليل\" — يضم الملخص المالي، التقارير، التحليل المالي، والعلاقات المالية."),
    ("كيف أستعيد نسخة احتياطية؟", "من القائمة الرئيسية اختر \"النسخ الاحتياطي والمزامنة\"."),
    ("نسيت رمز الدخول (PIN)، ماذا أفعل؟", "لا يوجد حالياً استرجاع تلقائي للرمز — يلزم التواصل مع من قام بإعداد التطبيق على جهازك."),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("الدعم والمساعدة"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Text("الأسئلة الشائعة ودليل الاستخدام", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppSizes.sm),
          ..._faqs.map((f) => _buildFaqCard(context, f.$1, f.$2)),
          const SizedBox(height: AppSizes.lg),
          Text("الإبلاغ عن مشكلة", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppSizes.sm),
          _buildActionCard(
            context,
            icon: Icons.bug_report_outlined,
            title: "نسخ معلومات النظام",
            subtitle: "لإرفاقها عند الإبلاغ عن مشكلة (الإصدار وإصدار قاعدة البيانات)",
            onTap: () {
              Clipboard.setData(ClipboardData(text: "${AppConfig.appName} ${AppConfig.version} — قاعدة البيانات: إصدار 24"));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ معلومات النظام")));
            },
          ),
          const SizedBox(height: AppSizes.lg),
          _buildInfoCard(
            context,
            "إرسال اقتراح والتواصل مع الدعم الفني",
            "لا توجد حالياً قناة دعم فني مُهيَّأة داخل التطبيق (بريد أو رقم تواصل) — سيتم تفعيلها في مرحلة قادمة.",
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))]),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          Text(body, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildFaqCard(BuildContext context, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))]),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          leading: const Icon(Icons.help_outline, color: AppColors.primary),
          title: Text(question, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
          childrenPadding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(answer, style: AppTextStyles.body.copyWith(fontSize: 13))],
        ),
      ),
    );
  }
}
