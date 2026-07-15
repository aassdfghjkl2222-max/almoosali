import 'package:flutter/material.dart';
import '../../core/app_sizes.dart';
import '../../models/document.dart';
import '../../repositories/document_repository.dart';

/// حوار إضافة مستند جديد لأي جهة مالكة (موظف/مورد/عقد/...) عبر محرك
/// المستندات الموحّد — نقطة الدخول الوحيدة المطلوبة لمنح كيان جديد قدرة
/// "إضافة مستند" دون أي كود إضافي: مرّر [hotelId]/[ownerType]/[ownerId] فقط.
/// المستند غير مرتبط بنوع مرجعي (استخدام حر بالاسم)، ويُفتح للتعديل الكامل
/// (تواريخ/جهة مصدرة/ملاحظات/مرفقات) عبر HotelDocumentEditPage بعد إنشائه —
/// حيث توجد بالفعل خطوة تأكيد حفظ كاملة، فلا حاجة لتأكيد مزدوج هنا.
Future<Document?> showAddOwnedDocumentDialog({
  required BuildContext context,
  required int hotelId,
  required String ownerType,
  required int ownerId,
  String title = "إضافة مستند",
  String nameHint = "اسم المستند",
}) async {
  final nameController = TextEditingController();
  DateTime? expiry;

  return showDialog<Document>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(hintText: nameHint),
              ),
              const SizedBox(height: AppSizes.md),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setDialogState(() => expiry = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "تاريخ الانتهاء (اختياري)", border: OutlineInputBorder()),
                  child: Text(expiry == null ? "بدون تاريخ" : expiry!.toString().split(' ')[0]),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final document = Document(
                hotelId: hotelId,
                ownerType: ownerType,
                ownerId: ownerId,
                name: name,
                expiryDate: expiry == null ? '' : expiry!.toString().split(' ')[0],
                createdAt: DateTime.now().toIso8601String(),
              );
              final id = await DocumentRepository().addDocument(document);
              if (dialogContext.mounted) Navigator.pop(dialogContext, document.copyWith(id: id));
            },
            child: const Text("إضافة"),
          ),
        ],
      ),
    ),
  );
}
