import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/financial_report.dart';
import '../../../models/hotel.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import '../reports/report_details_page.dart';

/// عرض كل التقارير التي كوّنت رقماً معيناً في تحليل الإيرادات (حسب فندق/شهر/يوم)
/// — التنقل الذكي: الضغط على أي تقرير يفتح تفاصيله الأصلية (نفس شاشة قسم التقارير).
typedef ReportAmountSelector = double Function(FinancialReport report);

class RevenueDrilldownPage extends StatelessWidget {
  final Hotel hotel;
  final String title;
  final List<FinancialReport> reports;
  final List<Hotel> allHotels;
  final Color color;
  final String totalLabel;
  final ReportAmountSelector? amountSelector;

  const RevenueDrilldownPage({
    super.key,
    required this.hotel,
    required this.title,
    required this.reports,
    required this.allHotels,
    required this.color,
    this.totalLabel = "إجمالي الإيرادات",
    this.amountSelector,
  });

  Hotel _resolveHotel(int hotelId) => allHotels.firstWhere((h) => h.id == hotelId, orElse: () => hotel);

  double _amount(FinancialReport r) => amountSelector != null ? amountSelector!(r) : r.income;

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    final total = reports.fold(0.0, (s, r) => s + _amount(r));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: title, hotel: hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          AppCard(
            identityAccent: color,
            child: Column(
              children: [
                Text(totalLabel, style: AppTextStyles.caption),
                Text(_format(total), style: AppTextStyles.title.copyWith(fontSize: 26, color: color, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text("التقارير (${reports.length})", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppSizes.sm),
          ...reports.map((r) => Card(
                margin: const EdgeInsets.only(bottom: AppSizes.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.receipt_long_outlined, color: color, size: 18),
                  ),
                  title: Text(_resolveHotel(r.hotelId).arabicName, style: AppTextStyles.bodyBold),
                  subtitle: Text(r.date, style: AppTextStyles.caption),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_format(_amount(r)), style: AppTextStyles.bodyBold.copyWith(color: color)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailsPage(hotel: _resolveHotel(r.hotelId), report: r)));
                  },
                ),
              )),
        ],
      ),
    );
  }
}
