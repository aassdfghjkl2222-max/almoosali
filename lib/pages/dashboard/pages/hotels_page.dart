import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/document_status.dart';
import '../../../core/hotel_session.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../models/hotel.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../repositories/document_repository.dart';
import '../../../widgets/common/app_drawer.dart';
import '../dashboard_page.dart';
import 'documents_page.dart';
import 'add_hotel_page.dart';

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
        final hotels = await repository.getAllHotels();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "قائمة المنشآت",








          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.2),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<Hotel>>(
        future: _hotelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final hotels = snapshot.data ?? [];

          if (hotels.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Text("لا توجد منشآت مضافة"),
              ),
            );
          }

          final totalAlerts = _hotelAlertCounts.values.fold(0, (sum, v) => sum + v);

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.xl),
            children: [
              _buildHeaderStats(hotels.length, totalAlerts),
              const SizedBox(height: AppSizes.lg),
              ...List.generate(hotels.length, (index) {
                final hotel = hotels[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.sm + 4),
                  child: _StaggeredEntry(
                    index: index,
                    child: _buildHotelCard(context, hotel),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddHotelPage()),
          );
          if (result == true) _loadData();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text("إضافة منشأة", style: TextStyle(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }

  Widget _buildHeaderStats(int hotelsCount, int alertsCount) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.apartment_rounded,
            label: "عدد الفنادق",
            value: "$hotelsCount",
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSizes.sm + 4),
        Expanded(
          child: _statCard(
            icon: Icons.notifications_rounded,
            label: "التنبيهات",
            value: "$alertsCount",
            color: alertsCount > 0 ? AppColors.warning : AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm + 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.10), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xff222222))),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xff777777))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelCard(BuildContext context, Hotel hotel) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    final alertCount = _hotelAlertCounts[hotel.id!] ?? 0;
    final deepShade = Color.lerp(identityColor, Colors.black, 0.22)!;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: Colors.white.withOpacity(0.12),
        highlightColor: Colors.white.withOpacity(0.06),
        onTap: () {
          // ضبط الفندق الحالي هو ما يجعل ثيم التطبيق بأكمله يتحول لهويته
          // البصرية فوراً، لكل شاشة تُفتح من هنا فصاعداً.
          HotelSession.current.value = hotel;
          Navigator.push(context, _premiumRoute(DashboardPage(hotel: hotel)));
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm + 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [identityColor, deepShade],
            ),
            boxShadow: [
              BoxShadow(color: identityColor.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSizes.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hotel.arabicName,
                      style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hotel.city.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: Colors.white.withOpacity(0.75), size: 12),
                          const SizedBox(width: 3),
                          Text(hotel.city, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (alertCount > 0) ...[
                _buildAlertBadge(context, hotel, identityColor, alertCount),
                const SizedBox(width: AppSizes.xs),
              ],
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.65), size: 13),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertBadge(BuildContext context, Hotel hotel, Color identityColor, int count) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentsPage(hotel: hotel, alertsOnly: true),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_rounded, size: 13, color: identityColor),
              const SizedBox(width: 4),
              Text(
                "$count",
                style: TextStyle(
                  color: identityColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Route _premiumRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, animation, secondaryAnimation) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
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
