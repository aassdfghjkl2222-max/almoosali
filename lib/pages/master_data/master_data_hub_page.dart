import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/common/coming_soon_page.dart';
import '../document_types/document_types_page.dart';
import '../expenses/manage_categories_page.dart';

/// وصف عنصر واحد ضمن قسم "البيانات المرجعية" — [builder] فارغ يعني أن هذا
/// العنصر لم يُنفَّذ بعد فيُفتح بصفحة "قيد الإعداد" الموحّدة تلقائياً.
class _MasterDataEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder? builder;
  const _MasterDataEntry({required this.title, required this.subtitle, required this.icon, this.builder});
  bool get isReady => builder != null;
}

/// مجموعة عناوين ضمن الصفحة (مثلاً "الجهات والكيانات") — تجميع بصري فقط،
/// لا علاقة له بأي جدول قاعدة بيانات.
class _MasterDataSection {
  final String title;
  final List<_MasterDataEntry> entries;
  const _MasterDataSection({required this.title, required this.entries});
}

/// مركز "البيانات المرجعية" (Master Data) — المكان الوحيد لإدارة كل قاعدة
/// بيانات مشتركة بين جميع الفنادق: لا تخص فندقاً معيناً، ولا تُكرَّر بين
/// الفنادق، وتعتمدها كل الفنادق كمصدر وحيد للحقيقة (Single Source of
/// Truth). لذلك هذه الصفحة عمداً بلا أي معامل Hotel ولا AppDrawer خاص
/// بفندق، وتتبع الثيم المحيط الافتراضي بدل أي هوية فندق (نفس نمط
/// SettingsPage/BackupPage).
///
/// عقد التوسع المعتمد لهذه الصفحة (اقرأه قبل إضافة أي قسم مرجعي جديد):
/// - لإضافة عنصر جديد داخل قسم موجود: أضف `_MasterDataEntry` جديداً داخل
///   `entries` القسم المناسب في [_sections].
/// - لإضافة قسم مرجعي جديد بالكامل (تجميع جديد من نوع مختلف): أضف
///   `_MasterDataSection` جديداً في [_sections] — `build()` نفسه لا
///   يحتاج أي تعديل لأنه يُبنى بحلقة واحدة فوق [_sections].
/// - لتفعيل عنصر لاحقاً بعد بناء شاشته الحقيقية في مهمته المستقلة: امنحه
///   `builder` يفتح تلك الشاشة بدل تركه فارغاً (فارغ = "قيد الإعداد"
///   تلقائياً عبر [ComingSoonPage]).
///
/// العنصر الوحيد المفعَّل فعلياً حالياً هو "تصنيفات المصروفات" (يفتح
/// ManageCategoriesPage الحقيقية على جدول expense_categories الموحّد من
/// مهمة سابقة)، وبقية العناصر "قيد الإعداد" ريثما تُنفَّذ كل واحدة في
/// مهمتها المستقلة.
class MasterDataHubPage extends StatelessWidget {
  const MasterDataHubPage({super.key});

  static final List<_MasterDataSection> _sections = [
    // الجهات والكيانات التي تتعامل معها الفنادق — بيانات "من" (مورد، بنك، جهة حكومية).
    const _MasterDataSection(
      title: "الجهات والكيانات",
      entries: [
        _MasterDataEntry(
          title: "الموردون",
          subtitle: "بيانات الموردين المعتمدة، مشتركة بين جميع الفنادق",
          icon: Icons.local_shipping_outlined,
        ),
        _MasterDataEntry(
          title: "البنوك والحسابات البنكية",
          subtitle: "الحسابات البنكية المعتمدة في النظام المالي",
          icon: Icons.account_balance_outlined,
        ),
        _MasterDataEntry(
          title: "الجهات الحكومية",
          subtitle: "الجهات والمؤسسات الحكومية ذات العلاقة بعمليات الفنادق",
          icon: Icons.domain_outlined,
        ),
      ],
    ),
    // التصنيفات والأنواع المعتمدة — بيانات "كيف تُصنَّف الأشياء" (تصنيف، نوع).
    _MasterDataSection(
      title: "التصنيفات والأنواع",
      entries: [
        _MasterDataEntry(
          title: "تصنيفات المصروفات",
          subtitle: "تصنيف بنود المصروفات المستخدَمة في كل الفنادق",
          icon: Icons.category_outlined,
          builder: (_) => const ManageCategoriesPage(),
        ),
        const _MasterDataEntry(
          title: "تصنيفات الإيرادات",
          subtitle: "تصنيف مصادر الإيرادات المستخدَمة في كل الفنادق",
          icon: Icons.monetization_on_outlined,
        ),
        _MasterDataEntry(
          title: "أنواع المستندات",
          subtitle: "الأنواع المعتمدة لتصنيف المستندات والمرفقات",
          icon: Icons.description_outlined,
          builder: (_) => const DocumentTypesPage(),
        ),
        const _MasterDataEntry(
          title: "أنواع العقود",
          subtitle: "الأنواع المعتمدة لتصنيف عقود الفنادق",
          icon: Icons.assignment_outlined,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("البيانات المرجعية", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              "كل قسم هنا مصدر بيانات واحد ومشترك بين جميع الفنادق — لا يُكرَّر أو يُعاد إدخاله لكل فندق على حدة.",
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

  Widget _buildGroupCard(BuildContext context, List<_MasterDataEntry> entries) {
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

  Widget _buildEntryTile(BuildContext context, _MasterDataEntry entry) {
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
                    description: "سيتوفر ضمن مراحل قادمة من قسم البيانات المرجعية، ليصبح مصدر البيانات الموحد الوحيد المعتمد في كل أقسام التطبيق.",
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
