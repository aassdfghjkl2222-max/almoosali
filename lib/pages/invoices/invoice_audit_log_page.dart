import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../models/invoice_audit_log_entry.dart';
import '../../repositories/invoice_repository.dart';
import '../../widgets/common/hotel_identity_title.dart';

/// سجل تعديلات فاتورة واحدة — عرض فقط، غير قابل للحذف (لا يوجد أي زر أو
/// دالة حذف لهذا السجل في كامل التطبيق). يبقى موجوداً حتى بعد حذف الفاتورة
/// نفسها.
class InvoiceAuditLogPage extends StatefulWidget {
  final Hotel hotel;
  final int invoiceId;
  final String invoiceLabel;
  const InvoiceAuditLogPage({super.key, required this.hotel, required this.invoiceId, required this.invoiceLabel});

  @override
  State<InvoiceAuditLogPage> createState() => _InvoiceAuditLogPageState();
}

class _InvoiceAuditLogPageState extends State<InvoiceAuditLogPage> {
  final _repository = InvoiceRepository();
  bool _isLoading = true;
  List<InvoiceAuditLogEntry> _entries = [];

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _repository.getAuditLog(widget.invoiceId);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  String _operationLabel(String type) {
    switch (type) {
      case 'create':
        return "إنشاء الفاتورة";
      case 'update':
        return "تعديل الفاتورة";
      case 'delete':
        return "حذف الفاتورة";
      default:
        return type;
    }
  }

  IconData _operationIcon(String type) {
    switch (type) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      default:
        return Icons.history;
    }
  }

  Color _operationColor(String type) {
    switch (type) {
      case 'create':
        return Colors.green;
      case 'delete':
        return Colors.red;
      default:
        return _identityColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "سجل التعديلات", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Text(widget.invoiceLabel, style: AppTextStyles.bodyBold),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, AppSizes.md),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
                          itemBuilder: (context, index) => _buildEntry(_entries[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: AppSizes.md),
            const Text("لا يوجد سجل تعديلات بعد", style: AppTextStyles.bodyBold),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(InvoiceAuditLogEntry entry) {
    final color = _operationColor(entry.operationType);
    final parts = entry.occurredAt.split('T');
    final datePart = parts.isNotEmpty ? parts[0] : entry.occurredAt;
    final timePart = parts.length > 1 ? parts[1].split('.').first : '';
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.xs),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(_operationIcon(entry.operationType), color: color, size: 18),
        ),
        title: Text(_operationLabel(entry.operationType), style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
        subtitle: Text(
          "بواسطة: ${entry.username} · $datePart${timePart.isNotEmpty ? ' — $timePart' : ''}"
          "${entry.changedFields != null && entry.changedFields!.isNotEmpty ? '\n${entry.changedFields}' : ''}",
          style: AppTextStyles.caption,
        ),
        isThreeLine: entry.changedFields != null && entry.changedFields!.isNotEmpty,
      ),
    );
  }
}
