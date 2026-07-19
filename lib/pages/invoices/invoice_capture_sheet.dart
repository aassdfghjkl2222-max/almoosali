import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_radius.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';

/// مصدر التقاط فاتورة واحد — صورة (كاميرا/معرض) أو ملف PDF، أبداً كلاهما
/// معاً. يُستهلَك مباشرة من InvoiceCaptureProcessingPage.
typedef InvoiceCaptureSource = ({String? imagePath, String? pdfPath});

/// ورقة اختيار مصدر مسح الفاتورة (تصوير بالكاميرا / اختيار من المعرض /
/// ملف PDF) — تفتح من زر "📷 الباركود"، بديل الماسح الحي القديم. تُعيد
/// null عند الإلغاء.
Future<InvoiceCaptureSource?> showInvoiceCaptureSheet(BuildContext context, {required Hotel hotel}) {
  final identityColor = HotelVisualIdentity.colorForHotel(hotel);
  return showModalBottomSheet<InvoiceCaptureSource>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(alignment: Alignment.centerRight, child: Text("مسح فاتورة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ),
          ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: identityColor),
            title: const Text("تصوير بالكاميرا"),
            onTap: () async {
              final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
              if (sheetContext.mounted) Navigator.pop(sheetContext, picked == null ? null : (imagePath: picked.path, pdfPath: null));
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: identityColor),
            title: const Text("اختيار صورة من المعرض"),
            onTap: () async {
              final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
              if (sheetContext.mounted) Navigator.pop(sheetContext, picked == null ? null : (imagePath: picked.path, pdfPath: null));
            },
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined, color: identityColor),
            title: const Text("اختيار ملف PDF"),
            onTap: () async {
              final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
              final path = result?.files.single.path;
              if (sheetContext.mounted) Navigator.pop(sheetContext, path == null ? null : (imagePath: null, pdfPath: path));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
