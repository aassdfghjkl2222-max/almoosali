import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_page_route.dart';
import '../../core/app_permissions.dart';
import '../../core/app_sizes.dart';
import '../../core/app_theme.dart';
import '../../core/document_status.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/hotel_identity.dart';
import '../../models/hotel.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../services/permission_service.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../expenses/pending_expenses_list_page.dart';
import '../invoices/invoices_page.dart';
import '../vault/vault_dashboard_page.dart';
import 'pages/documents_page.dart';
import 'pages/more_modules_page.dart';
import '../employees/employees_page.dart';
import '../financial/financial_summary_page.dart';
import '../analysis/analysis_center_page.dart';
import 'widgets/dashboard_section_card.dart';
import 'widgets/hotel_info_card.dart';

/// وصف قسم واحد ضمن لوحة التحكم — بيانات ثابتة (عنوان/وصف/أيقونة/لون) +
/// دالة بناء الصفحة المقصودة، بترتيب [_sections] الثابت المطلوب (لا يتغير).
class _DashboardSection {
  final String title;
  final IconData icon;
  final Color Function(HotelIdentity identity) color;
  final int Function(_DashboardPageState state)? badgeCount;
  final Widget Function(BuildContext context, Hotel hotel) builder;

  /// رمز صلاحية العرض المطلوب لإظهار هذا القسم — null تعني ظاهر دوماً (أقسام
  /// خارج الوحدات الـ9 المذكورة صراحة في نظام الصلاحيات، مثل مركز التحليل).
  /// راجع PermissionService.hasPermission.
  final String? viewPermission;

  const _DashboardSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.builder,
    this.badgeCount,
    this.viewPermission,
  });
}

final List<_DashboardSection> _sections = [
  _DashboardSection(
    title: "العمليات المالية المعلقة",
    icon: Icons.pending_actions_rounded,
    color: (_) => AppColors.warning,
    badgeCount: (state) => state._pendingCount,
    builder: (context, hotel) => PendingExpensesListPage(hotel: hotel),
    viewPermission: AppPermissions.financialDataView,
  ),
  _DashboardSection(
    title: "التقرير المالي",
    icon: Icons.account_balance_rounded,
    color: (_) => AppColors.success,
    builder: (context, hotel) => FinancialSummaryPage(hotel: hotel),
    viewPermission: AppPermissions.financialReportsView,
  ),
  _DashboardSection(
    title: "المركز المالي",
    icon: Icons.account_balance_wallet_rounded,
    color: (identity) => identity.primary,
    builder: (context, hotel) => VaultDashboardPage(hotel: hotel),
    viewPermission: AppPermissions.vaultView,
  ),
  _DashboardSection(
    title: "مستندات الفندق",
    icon: Icons.description_rounded,
    color: (_) => AppColors.info,
    builder: (context, hotel) => DocumentsPage(hotel: hotel),
    viewPermission: AppPermissions.documentsView,
  ),
  _DashboardSection(
    title: "مركز التحليل",
    icon: Icons.analytics_rounded,
    color: (_) => const Color(0xFF6A1B9A),
    builder: (context, hotel) => AnalysisCenterPage(hotel: hotel),
  ),
  _DashboardSection(
    title: "الفواتير الضريبية",
    icon: Icons.receipt_long_rounded,
    color: (_) => AppColors.secondary,
    builder: (context, hotel) => InvoicesPage(hotel: hotel),
  ),
  _DashboardSection(
    title: "الموظفون",
    icon: Icons.people_alt_rounded,
    color: (_) => const Color(0xFF00897B),
    builder: (context, hotel) => EmployeesPage(hotel: hotel),
    viewPermission: AppPermissions.employeesView,
  ),
  _DashboardSection(
    title: "المزيد",
    icon: Icons.apps_rounded,
    color: (_) => const Color(0xFF616161),
    builder: (context, hotel) => MoreModulesPage(hotel: hotel),
  ),
];

class DashboardPage extends StatefulWidget {
  final Hotel hotel;
  const DashboardPage({super.key, required this.hotel});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final _expenseRepository = ExpenseRepository();
  final _documentRepository = DocumentRepository();
  int _pendingCount = 0;

  int _expiringDocumentsCount = 0;
  DateTime? _lastDocumentUpdate;
  // عدد التنبيهات: بلا مصدر بيانات موحّد بعد — placeholder جاهز للربط لاحقاً
  // بلا أي تعديل على تصميم HotelInfoCard (راجع تعليقها).
  final int _alertsCount = 0;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..forward();
    _loadPendingCount();
    _loadDocumentStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingCount() async {
    final expenses = await _expenseRepository.getPendingExpenses(
      hotelId: widget.hotel.id!,
      isTransferred: false,
    );
    if (mounted) {
      setState(() {
        _pendingCount = expenses.length;
      });
    }
  }

  Future<void> _loadDocumentStats() async {
    final documents = await _documentRepository.getDocumentsForHotel(widget.hotel.id!);
    if (!mounted) return;
    final expiring = documents.where((d) {
      final level = DocumentStatus.fromExpiryDate(d.expiryDate).level;
      return level == DocumentStatusLevel.expired || level == DocumentStatusLevel.urgent || level == DocumentStatusLevel.warning;
    }).length;
    DateTime? lastUpdate;
    for (final d in documents) {
      final created = DateTime.tryParse(d.createdAt);
      if (created != null && (lastUpdate == null || created.isAfter(lastUpdate))) lastUpdate = created;
    }
    setState(() {
      _expiringDocumentsCount = expiring;
      _lastDocumentUpdate = lastUpdate;
    });
  }

  /// انتقال ناعم موحَّد (راجع core/app_page_route.dart) — يُستخدم لكل فتح قسم
  /// من لوحة التحكم فقط، بلا أي تغيير في التنقل نفسه.
  Future<T?> _openSection<T>(Widget page) {
    return Navigator.push<T>(context, premiumRoute<T>(page));
  }

  /// أقسام هذه اللوحة التي يملك المستخدم الحالي صلاحية عرضها لهذا الفندق —
  /// المدير أو وضع PIN بلا تفعيل تعدد مستخدمين يريان كل الأقسام كما كان
  /// السلوك دوماً (راجع PermissionService._noUserLoaded/isManager).
  List<_DashboardSection> get _visibleSections {
    return _sections.where((s) {
      if (s.viewPermission == null) return true;
      return PermissionService.instance.hasPermission(s.viewPermission!, hotelId: widget.hotel.id);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final identity = HotelVisualIdentity.identityForHotel(widget.hotel);
    final sections = _visibleSections;

    return Theme(
      data: AppTheme.createTheme(identity),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: HotelIdentityTitle(title: "لوحة التحكم", hotel: widget.hotel),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [identity.primary, Color.lerp(identity.primary, Colors.black, 0.18)!],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
              label: const Text("تغيير الفندق", style: TextStyle(color: Colors.white, fontSize: 13)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm)),
            ),
          ],
        ),
        drawer: AppDrawer(hotel: widget.hotel),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.md),
                children: [
                  _staggered(
                    0,
                    HotelInfoCard(
                      hotel: widget.hotel,
                      accentColor: identity.primary,
                      alertsCount: _alertsCount,
                      expiringDocumentsCount: _expiringDocumentsCount,
                      lastUpdate: _lastDocumentUpdate,
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  for (var i = 0; i < sections.length; i++) ...[
                    _staggered(
                      i + 1,
                      DashboardSectionCard(
                        icon: sections[i].icon,
                        title: sections[i].title,
                        color: sections[i].color(identity),
                        badgeCount: sections[i].badgeCount?.call(this) ?? 0,
                        onTap: () async {
                          final result = await _openSection(sections[i].builder(context, widget.hotel));
                          if (result == true) {
                            _loadPendingCount();
                            _loadDocumentStats();
                          }
                        },
                      ),
                    ),
                    if (i != sections.length - 1) const SizedBox(height: AppSizes.sm),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ظهور تدريجي (تلاشٍ + انزلاق خفيف لأعلى) لكل عنصر بترتيب متتابع بسيط —
  /// AnimationController واحد للشاشة بأكملها (لا Controller منفصل لكل بطاقة)
  /// حفاظاً على الأداء.
  Widget _staggered(int index, Widget child) {
    final start = (index * 0.06).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final curved = CurvedAnimation(parent: _animController, curve: Interval(start, end, curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(offset: Offset(0, (1 - curved.value) * 16), child: child),
        );
      },
      child: child,
    );
  }
}
