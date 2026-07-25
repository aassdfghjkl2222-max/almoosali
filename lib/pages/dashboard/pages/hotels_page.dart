import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_config.dart';
import '../../../core/document_status.dart';
import '../../../core/hotel_session.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_page_route.dart';
import '../../../models/hotel.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../repositories/document_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_drawer.dart';
import '../dashboard_page.dart';
import 'documents_page.dart';

/// شاشة اختيار الفندق — نقطة الدخول الأولى بعد الدخول للتطبيق، بلا أي هوية
/// لفندق محدَّد بعد (لهذا خلفيتها محايدة وليست بلون أي فندق). لا تحتوي أي
/// إدارة للفنادق (إضافة/تعديل/أرشفة) — تلك انتقلت بالكامل إلى الإعدادات ←
/// إدارة الفنادق (راجع HotelManagementPage)؛ هذه الشاشة مخصَّصة حصراً لاختيار
/// فندق نشط والانتقال للوحة تحكمه.
class HotelsPage extends StatefulWidget {
  const HotelsPage({super.key});

  @override
  State<HotelsPage> createState() => _HotelsPageState();
}

class _HotelsPageState extends State<HotelsPage> {
  final repository = HotelRepository();
  final docRepository = DocumentRepository();
  late Future<List<Hotel>> _hotelsFuture;
  final Map<int, int> _hotelAlertCounts = {};
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _ink = Color(0xFF1C1B1A);
  static const _paper = Color(0xFFFAF8F5);

  @override
  void initState() {
    super.initState();
    // هذه هي "المنطقة المحايدة": أي عودة إلى قائمة الفنادق تُصفِّر هوية
    // الفندق الحالية فوراً، فيعود التطبيق للهوية الافتراضية حتى يُختار فندق جديد.
    HotelSession.current.value = null;
    _loadData();
  }

  void _loadData() {
    setState(() {
      _hotelsFuture = repository.seedData().then((_) async {
        // فندق تحت الصيانة أو "قريباً" يبقى غير مؤرشَف (يظهر في إدارة الفنادق)
        // لكن لا يجب أن يظهر هنا كخيار تشغيلي فعلي للموظفين — راجع
        // HotelRepository.getOperationalHotels وHotel.status.
        final hotels = await repository.getOperationalHotels();
        await _loadAllAlerts(hotels);
        return hotels;
      });
    });
  }

  Future<void> _loadAllAlerts(List<Hotel> hotels) async {
    for (var hotel in hotels) {
      final docs = await docRepository.getDocumentsForHotel(hotel.id!);
      final count = docs.where((doc) => DocumentStatus.fromExpiryDate(doc.expiryDate).needsAttention).length;
      _hotelAlertCounts[hotel.id!] = count;
    }
  }

  void _openHotel(Hotel hotel) {
    // ضبط الفندق الحالي هو ما يجعل ثيم التطبيق بأكمله يتحول لهويته البصرية
    // فوراً، لكل شاشة تُفتح من هنا فصاعداً.
    HotelSession.current.value = hotel;
    Navigator.push(context, premiumRoute(DashboardPage(hotel: hotel)));
  }

  void _openAlerts(Hotel hotel) {
    Navigator.push(context, premiumRoute(DocumentsPage(hotel: hotel, alertsOnly: true)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _paper,
        drawer: const AppDrawer(),
        body: SafeArea(
          child: FutureBuilder<List<Hotel>>(
            future: _hotelsFuture,
            builder: (context, snapshot) {
              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final hotels = snapshot.data ?? [];

              return Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : hotels.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.xs, AppSizes.md, AppSizes.xl),
                                itemCount: hotels.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: AppSizes.md),
                                  child: _StaggeredEntry(index: index, child: _buildHotelCard(hotels[index])),
                                ),
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// ترويسة هادئة بلا أي كتلة لون صلبة — اسم الشركة الرسمي (عربي بارز، إنجليزي
  /// أخف وأصغر تحته) بدل أي عنوان وصفي، وزر قائمة جانبية أنيق بدل شريط تطبيق
  /// تقليدي، ينسجم مع خلفية الشاشة المحايدة.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConfig.companyNameAr,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: _ink, letterSpacing: -0.2, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConfig.companyNameEn,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey.shade500, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          _buildMenuButton(),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _scaffoldKey.currentState?.openDrawer(),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: const Icon(Icons.menu_rounded, color: _ink, size: 22),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), shape: BoxShape.circle),
              child: const Icon(Icons.apartment_outlined, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: AppSizes.md),
            const Text("لا توجد منشآت مضافة", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
            const SizedBox(height: 6),
            Text(
              "يمكن إضافة منشأة جديدة من الإعدادات ← إدارة الفنادق",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة فندق فاخرة بأقل محتوى ممكن: تعبئة كاملة بتدرُّج هوية الفندق (بدل
  /// لوحة جانبية) واسم أبيض بارز فوقها مباشرة — "اللون يهيمن، الاسم يتحدَّث
  /// بلونه" بدل تقسيم البطاقة بين منطقة ملوَّنة وأخرى بيضاء. بلا مدينة ولا أي
  /// نص إضافي، ليبقى الاسم هو العنصر البصري الأساسي. الظل/الحواف/لمسة الضغط
  /// موروثة من AppCard نفسها (padding صفري لأن التدرُّج يجب أن يملأ البطاقة
  /// حتى حوافها الخارجية بلا أي هامش داخلي أبيض).
  Widget _buildHotelCard(Hotel hotel) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    final alertCount = _hotelAlertCounts[hotel.id!] ?? 0;

    // تفتيح/تعتيم داخل مساحة HSL (تغيير النصوع فقط، بلا مزج مع الأسود/الأبيض
    // المحايدَين) — يحافظ على تدرُّج اللون (hue) والتشبُّع كما هما، فيبقى
    // الذهبي ذهبياً فعلاً عند تعتيمه بدل الانجراف نحو بنّي موحل.
    final hsl = HSLColor.fromColor(identityColor);
    final bright = hsl.withLightness((hsl.lightness + (1 - hsl.lightness) * 0.3).clamp(0.0, 1.0)).toColor();
    final deep = hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor();
    // لوحة الألوان الجاهزة (HotelColorPalettes) تتضمن الآن ألواناً فاتحة جداً
    // (لؤلؤي أبيض، شامبانيا) يصبح فوقها النص الأبيض غير مقروء — نحسب سطوع
    // اللون الأساسي ونبدِّل لوناً داكناً للنص/السهم فقط عند الحاجة الفعلية.
    final isLightBrand = identityColor.computeLuminance() > 0.6;
    final onBrandColor = isLightBrand ? _ink : Colors.white;
    final onBrandColorMuted = isLightBrand ? _ink.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.75);

    return SizedBox(
      height: 112,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => _openHotel(hotel),
        // موجة لمس بيضاء بدل لون الثيم العام الافتراضي — تقرأ بأناقة فوق أي
        // لون هوية غامق أو فاتح على حدٍّ سواء.
        splashColor: Colors.white.withValues(alpha: 0.16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [bright, identityColor, deep],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // طبقة لمعان علوية خفيفة — إحساس "إضاءة فاخرة منعكسة" بدل سطح مسطَّح.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.12), Colors.transparent],
                      stops: const [0, 0.5],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -34,
                end: -34,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _buildLogoBadge(hotel, identityColor, alertCount),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        hotel.arabicName,
                        // اسم أبيض بارز فوق التدرُّج مباشرة (بدلاً من نص داكن
                        // فوق خلفية بيضاء) — بظل نصّي خفيف جداً يضمن وضوحه فوق
                        // أي لون هوية مهما اختلفت درجة سطوعه (كالذهبي الفاتح
                        // نسبياً مقارنةً بالعنابي/الأخضر الغامقين).
                        style: TextStyle(
                          color: onBrandColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          height: 1.2,
                          shadows: isLightBrand ? null : const [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 1))],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios_rounded, color: onBrandColorMuted, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// مساحة الشعار — مربَّع أبيض مرتفع بظل ناعم، مُهيَّأ لاستقبال شعار حقيقي
  /// (صورة) لاحقاً من إدارة الفنادق بدل هذه الأيقونة المؤقتة (راجع تعليق
  /// الملف). شارة التنبيه الصغيرة تتموضع في زاويته العلوية عند وجود تنبيهات،
  /// قابلة للضغط بمفردها لفتح تنبيهات المستندات، بمساحة لمس مريحة رغم صغر
  /// حجمها الظاهري — تعبئة بيضاء ثابتة بحلقة عنبرية تضمن وضوحها فوق أي لون
  /// هوية للفندق.
  Widget _buildLogoBadge(Hotel hotel, Color color, int alertCount) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Icon(Icons.apartment_rounded, color: color, size: 28),
          ),
          if (alertCount > 0)
            PositionedDirectional(
              top: -8,
              end: -8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openAlerts(hotel),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    alignment: Alignment.center,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.warning, width: 1.6),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Center(
                        child: Text(
                          alertCount > 9 ? '9+' : '$alertCount',
                          style: const TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold, height: 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
        ),
    );
  }
}

/// حركة دخول بسيطة (تلاشٍ + انزلاق خفيف) لبطاقات القائمة عند ظهورها، بدون مبالغة.

class _StaggeredEntry extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggeredEntry({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 45).clamp(0, 300);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
