import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';

class BreakdownItem {
  final String label;
  final double amount;
  final String? subtitle;
  const BreakdownItem(this.label, this.amount, {this.subtitle});
}

/// شاشة قراءة فقط تعرض تفاصيل العناصر التي كوّنت رقماً معيناً داخل التقرير
/// (الإيرادات أو المصروفات) — التنقل الذكي المطلوب في قسم التقارير.
class ReportAmountBreakdownPage extends StatelessWidget {
  final Hotel hotel;
  final String title;
  final List<BreakdownItem> items;
  final Color color;

  const ReportAmountBreakdownPage({
    super.key,
    required this.hotel,
    required this.title,
    required this.items,
    required this.color,
  });

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    final total = items.fold(0.0, (sum, i) => sum + i.amount);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: title, hotel: hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
      ),
      body: items.isEmpty
          ? const Center(child: Text("لا توجد عناصر مسجلة"))
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                AppCard(
                  identityAccent: color,
                  child: Column(
                    children: [
                      const Text("الإجمالي", style: AppTextStyles.caption),
                      Text(_format(total), style: AppTextStyles.title.copyWith(fontSize: 26, color: color, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                ...items.map((i) => Card(
                      margin: const EdgeInsets.only(bottom: AppSizes.sm),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(Icons.receipt_long_outlined, color: color, size: 18),
                        ),
                        title: Text(i.label, style: AppTextStyles.bodyBold),
                        subtitle: i.subtitle != null ? Text(i.subtitle!, style: AppTextStyles.caption) : null,
                        trailing: Text(_format(i.amount), style: AppTextStyles.bodyBold.copyWith(color: color)),
                      ),
                    )),
              ],
            ),
    );
  }
}
