import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/common/coming_soon_page.dart';
import 'employees/employee_documents_hub_page.dart';
import 'permanent/permanent_documents_page.dart';
import 'seasonal/seasonal_documents_page.dart';

/// وصف عنصر واحد ضمن قسم "المستندات" — [builder] فارغ يعني أن هذا العنصر
/// لم يُنفَّذ بعد فيُفتح بصفحة "قيد الإعداد" الموحّدة تلقائياً.
class _DocumentsHubEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder? builder;
  const _DocumentsHubEntry({required this.title, required this.subtitle, required this.icon, this.builder});
  bool get isReady => builder != null;
}

/// مجموعة عناوين ضمن الصفحة — تجميع بصري فقط، لا علاقة له بأي جدول قاعدة بيانات.
class _DocumentsHubSection {
  final String title;
  final List<_DocumentsHubEntry> entries;
  const _DocumentsHubSection({required this.title, required this.entries});
}

/// قسم "المستندات" — المرحلة الأولى: هيكل تنقّل فقط بلا تنفيذ وظائف كاملة
/// (حسب طلب المهمة صراحة). قسم رئيسي مستقل في القائمة الرئيسية، وليس تابعاً
/// لفندق معيّن ولا للبيانات المرجعية — لذلك هذه الصفحة عمداً بلا معامل Hotel،
/// وتتبع الثيم المحيط الافتراضي (نفس نمط MasterDataHubPage/SettingsPage).
/// كل الشاشات الفعلية الحالية (مستندات الفندق، مستندات الموظف داخل بطاقته،
/// مستندات المورد داخل بطاقته) تبقى كما هي دون أي تعديل أو نقل بيانات — هذا
/// القسم هو واجهة تجميعية مستقبلية فوقها، تُبنى تدريجياً في مهام لاحقة.
///
/// عقد التوسع المعتمد (نفس عقد MasterDataHubPage المُثبَت عملياً):
/// - عنصر جديد داخل قسم موجود: أضِف `_DocumentsHubEntry` في `entries`.
/// - قسم جديد بالكامل: أضِف `_DocumentsHubSection` جديداً في [_sections] —
///   `build()` لا يحتاج أي تعديل لأنه يُبنى بحلقة واحدة فوق [_sections].
/// - لتفعيل عنصر لاحقاً: امنحه `builder` يفتح شاشته الحقيقية بدل تركه فارغاً.
class DocumentsHubPage extends StatelessWidget {
  const DocumentsHubPage({super.key});

  static final List<_DocumentsHubSection> _sections = [
    // تصنيف المستندات حسب دورة حياتها — تصنيف مستقل عن "يحتاج تجديد؟" (الذي
    // يتحكم فقط بإلزامية تاريخ الانتهاء لكل مستند على حدة).
    _DocumentsHubSection(
      title: "حسب دورة الحياة",
      entries: [
        _DocumentsHubEntry(
          title: "المستندات الدائمة",
          subtitle: "المستندات الرسمية الدائمة كالبلدية والسجل التجاري والتراخيص",
          icon: Icons.verified_outlined,
          builder: (_) => const PermanentDocumentsPage(),
        ),
        _DocumentsHubEntry(
          title: "المستندات الموسمية",
          subtitle: "مجلدات مؤقتة أو موسمية كموسم الحج ورمضان والتفتيش",
          icon: Icons.event_repeat_outlined,
          builder: (_) => const SeasonalDocumentsPage(),
        ),
      ],
    ),
    // مستندات الجهات المختلفة المرتبطة بمحرك المستندات الموحّد.
    _DocumentsHubSection(
      title: "حسب الجهة",
      entries: [
        _DocumentsHubEntry(
          title: "مستندات الموظفين",
          subtitle: "عرض مجمَّع لمستندات كل الموظفين عبر الفنادق",
          icon: Icons.badge_outlined,
          builder: (_) => const EmployeeDocumentsHubPage(),
        ),
        _DocumentsHubEntry(
          title: "مستندات العقود",
          subtitle: "عرض مجمَّع لمستندات العقود عبر الفنادق",
          icon: Icons.assignment_outlined,
        ),
        _DocumentsHubEntry(
          title: "مستندات الموردين",
          subtitle: "عرض مجمَّع لمستندات كل الموردين عبر الفنادق",
          icon: Icons.local_shipping_outlined,
        ),
      ],
    ),
    // البحث والتنبيهات والإحصائيات على مستوى التطبيق بالكامل.
    _DocumentsHubSection(
      title: "البحث والتنبيهات والإحصائيات",
      entries: [
        _DocumentsHubEntry(
          title: "البحث في جميع المستندات",
          subtitle: "بحث موحّد عبر كل مستندات التطبيق بغض النظر عن الجهة المالكة",
          icon: Icons.search,
        ),
        _DocumentsHubEntry(
          title: "المستندات المنتهية",
          subtitle: "كل المستندات المنتهية حالياً عبر جميع الفنادق",
          icon: Icons.error_outline,
        ),
        _DocumentsHubEntry(
          title: "تنتهي خلال 30 يوماً",
          subtitle: "المستندات التي تقترب من تاريخ انتهائها",
          icon: Icons.access_time_rounded,
        ),
        _DocumentsHubEntry(
          title: "إحصائيات المستندات",
          subtitle: "نظرة عامة على أعداد وحالات المستندات في التطبيق",
          icon: Icons.bar_chart_outlined,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("المستندات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: AppSizes.lg),
          for (final section in _sections) ...[
            _buildSectionTitle(context, section.title),
            _buildGroupCard(context, section.entries),
            const SizedBox(height: AppSizes.lg),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(color: AppColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "كل الأقسام هنا تعرض بيانات محرك المستندات الموحّد نفسه — لا يُنشأ أو يُنقل أي مستند، فقط طرق عرض مختلفة له.",
              style: TextStyle(fontSize: 11, color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm, right: AppSizes.xs),
      child: Text(title, style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGroupCard(BuildContext context, List<_DocumentsHubEntry> entries) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _buildEntryTile(context, entries[i]),
            if (i != entries.length - 1) const Divider(height: 1, indent: 72),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryTile(BuildContext context, _DocumentsHubEntry entry) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(entry.icon, color: primary),
      ),
      title: Text(entry.title, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
      subtitle: Text(entry.subtitle, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusChip(context, entry.isReady),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios, size: 14),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: entry.builder ??
              (_) => ComingSoonPage(
                    title: entry.title,
                    icon: entry.icon,
                    description: "سيتوفر ضمن مراحل قادمة من قسم المستندات، ليصبح مركزاً موحّداً لعرض كل مستندات التطبيق عبر محرك المستندات الموحّد.",
                  ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, bool isReady) {
    final color = isReady ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Text(
        isReady ? "متاح الآن" : "قيد الإعداد",
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
