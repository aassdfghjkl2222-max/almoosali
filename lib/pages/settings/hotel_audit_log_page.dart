import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../models/hotel_audit_log.dart';
import '../../repositories/hotel_repository.dart';
import '../../widgets/common/app_card.dart';

/// سجل تدقيق عمليات إدارة الفنادق — [hotel] لعرض سجل فندق واحد فقط، أو فارغ
/// لعرض سجل كل الفنادق معاً. للعرض فقط، بلا أي إجراء متاح هنا.
class HotelAuditLogPage extends StatefulWidget {
  final Hotel? hotel;
  const HotelAuditLogPage({super.key, this.hotel});

  @override
  State<HotelAuditLogPage> createState() => _HotelAuditLogPageState();
}

class _HotelAuditLogPageState extends State<HotelAuditLogPage> {
  final _repository = HotelRepository();
  List<HotelAuditLog> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _repository.getAuditLog(hotelId: widget.hotel?.id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  IconData _iconFor(String action) {
    switch (action) {
      case HotelAuditLog.actionCreated:
        return Icons.add_circle_outline_rounded;
      case HotelAuditLog.actionEdited:
        return Icons.edit_outlined;
      case HotelAuditLog.actionLogoChanged:
        return Icons.image_outlined;
      case HotelAuditLog.actionColorsChanged:
        return Icons.palette_outlined;
      case HotelAuditLog.actionStatusChanged:
        return Icons.sync_alt_rounded;
      case HotelAuditLog.actionArchived:
        return Icons.archive_outlined;
      case HotelAuditLog.actionRestored:
        return Icons.restore_rounded;
      case HotelAuditLog.actionPermanentlyDeleted:
        return Icons.delete_forever_outlined;
      case HotelAuditLog.actionDuplicated:
        return Icons.copy_all_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _colorFor(String action) {
    switch (action) {
      case HotelAuditLog.actionPermanentlyDeleted:
        return AppColors.danger;
      case HotelAuditLog.actionArchived:
        return AppColors.warning;
      case HotelAuditLog.actionRestored:
      case HotelAuditLog.actionCreated:
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.hotel == null ? "سجل تدقيق الفنادق" : "سجل تدقيق: ${widget.hotel!.arabicName}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text("لا يوجد سجل تدقيق بعد", style: AppTextStyles.caption))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    final color = _colorFor(e.action);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      child: AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                              child: Icon(_iconFor(e.action), color: color, size: 18),
                            ),
                            const SizedBox(width: AppSizes.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.actionLabel, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                                  const SizedBox(height: 2),
                                  if (widget.hotel == null) Text(e.hotelName, style: AppTextStyles.caption.copyWith(fontSize: 12)),
                                  if (e.details != null && e.details!.trim().isNotEmpty) Text(e.details!, style: AppTextStyles.caption.copyWith(fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
                                      const SizedBox(width: 3),
                                      Text(e.performedBy, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                                      const SizedBox(width: AppSizes.sm),
                                      Icon(Icons.schedule, size: 12, color: Colors.grey.shade500),
                                      const SizedBox(width: 3),
                                      Text(e.createdAt.replaceFirst('T', ' ').split('.').first, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
