import '../core/database/database_service.dart';
import '../core/document_status.dart';
import '../models/document.dart';
import '../models/document_attachment.dart';
import '../services/document_notification_service.dart';
import 'trash_repository.dart';

class DocumentRepository {
  final DatabaseService _databaseService = DatabaseService();
  final _trashRepository = TrashRepository();

  List<Document> _sortedByStatusPriority(List<Map<String, dynamic>> maps) {
    final documents = maps.map((map) => Document.fromMap(map)).toList();
    documents.sort((a, b) {
      final pa = DocumentStatus.fromExpiryDate(a.expiryDate).priority;
      final pb = DocumentStatus.fromExpiryDate(b.expiryDate).priority;
      return pa.compareTo(pb);
    });
    return documents;
  }

  /// كل مستندات الفندق (بغض النظر عن الجهة المالكة الفعلية — فندق مباشرة أو
  /// موظف تابع له...) مع بيانات النوع/الفئة الحيّة، مُرتَّبة تلقائياً حسب
  /// أولوية حالة الانتهاء (منتهٍ أولاً... بلا تاريخ أخيراً) — وليس أبجدياً.
  Future<List<Document>> getDocumentsForHotel(int hotelId) async {
    final maps = await _databaseService.getDocumentsForHotel(hotelId);
    return _sortedByStatusPriority(maps);
  }

  /// مستندات جهة مالكة واحدة بعينها (موظف/مورد/عقد/... حسب [ownerType]) —
  /// نقطة الدخول الوحيدة المطلوبة لربط أي كيان جديد بمحرك المستندات الموحّد.
  Future<List<Document>> getDocumentsForOwner(String ownerType, int ownerId) async {
    final maps = await _databaseService.getDocumentsForOwner(ownerType, ownerId);
    return _sortedByStatusPriority(maps);
  }

  /// "داخل مجلد" نوع مرجعي واحد — كل المستندات المرتبطة به عبر جدول
  /// المراجع (قد يظهر مستند واحد في أكثر من مجلد بلا أي نسخ)، بفلترة
  /// اختيارية بمجموعة فنادق (فارغة/null = بلا فلترة)، تراعي نطاق كل مستند.
  Future<List<Document>> getDocumentsInFolder(int documentTypeId, {List<int>? hotelIds, String? ownerType, int? ownerId}) async {
    final maps = await _databaseService.getDocumentsInFolder(documentTypeId, hotelIds: hotelIds, ownerType: ownerType, ownerId: ownerId);
    return _sortedByStatusPriority(maps);
  }

  /// نسخة فندق واحد من نوع مرجعي واحد إن وُجدت (نطاق single) — يُستخدم
  /// لتفادي إنشاء مستند مكرر عند تعبئة مستند فندق مُزوَّد تلقائياً.
  Future<Document?> getDocumentForHotelAndType(int hotelId, int documentTypeId) async {
    final map = await _databaseService.getDocumentForHotelAndType(hotelId, documentTypeId);
    return map != null ? Document.fromMap(map) : null;
  }

  /// كل مستندات النظام بلا فلترة — لمزامنة تنبيهات الانتهاء الشاملة فقط
  /// (DocumentNotificationService)، وليس لأي شاشة عرض.
  Future<List<Document>> getAllDocuments() async {
    final maps = await _databaseService.getAllDocuments();
    return maps.map((map) => Document.fromMap(map)).toList();
  }

  /// كل المستندات "العامة" — مُرتَّبة حسب أولوية حالة الانتهاء كبقية الشاشات
  /// (منتهٍ أولاً)، بخلاف [getGeneralAndHotelDocuments] التي تحافظ على ترتيب
  /// المجموعتين (عامة ثم فندق) عمداً.
  Future<List<Document>> getGeneralDocuments() async {
    final maps = await _databaseService.getGeneralDocuments();
    return _sortedByStatusPriority(maps);
  }

  /// المستندات العامة أولاً ثم مستندات فندق واحد فقط — **بلا** إعادة فرز
  /// حسب حالة الانتهاء (خلافاً لبقية دوال هذا المستودع) لأن ترتيب
  /// "عامة ثم فندق" جزء من المتطلَّب نفسه، لا تفصيل عرض ثانوي.
  Future<List<Document>> getGeneralAndHotelDocuments(int hotelId) async {
    final maps = await _databaseService.getGeneralAndHotelDocuments(hotelId);
    return maps.map((map) => Document.fromMap(map)).toList();
  }

  /// بحث/فلترة عبر "المستندات الخاصة" بالكامل (كل المجلدات معاً) — يُغذّي
  /// شاشة البحث الموحّدة في مركز المستندات.
  Future<List<Document>> searchDocumentsAdvanced({String? query, List<int>? hotelIds, int? documentTypeId}) async {
    final maps = await _databaseService.searchDocumentsAdvanced(query: query, hotelIds: hotelIds, documentTypeId: documentTypeId);
    return _sortedByStatusPriority(maps);
  }

  /// بحث بالاسم عبر كل مستندات النظام — أساس "ربط مستند موجود" (مرجع لمستند
  /// حالي داخل مجلد آخر، بلا نسخ للملف أو للسجل). فلترة اختيارية بمجموعة
  /// فنادق (نفس منطق [getDocumentsInFolder])، ومُرتَّبة حسب أولوية حالة
  /// الانتهاء كبقية شاشات محرك المستندات (منتهٍ أولاً... إلخ).
  Future<List<Document>> searchDocumentsByName(String query, {String? ownerType, List<int>? hotelIds}) async {
    final maps = await _databaseService.searchDocumentsByName(query, ownerType: ownerType, hotelIds: hotelIds);
    return _sortedByStatusPriority(maps);
  }

  /// يربط مستنداً بمجلد (نوع مرجعي) إضافي — "مرجع" فقط، بلا أي نسخ. آمن
  /// للاستدعاء المتكرر لنفس الزوج (يُتجاهَل عبر الفهرس الفريد).
  Future<void> linkDocumentToFolder(int documentId, int documentTypeId) async {
    await _databaseService.insertDocumentFolderLink(documentId, documentTypeId);
  }

  /// يزيل مرجع مستند من مجلد واحد فقط — لا يمسّ المستند نفسه ولا مرفقاته،
  /// ولا وجوده في أي مجلد آخر. حذف المستند الأصلي فعلياً يكون عبر
  /// [deleteDocument] من صفحته الخاصة فقط.
  Future<void> unlinkDocumentFromFolder(int documentId, int documentTypeId) async {
    await _databaseService.deleteDocumentFolderLink(documentId, documentTypeId);
  }

  /// يضبط نطاق الفنادق "المحددة" لمستند (hotelScope='specific') — يستبدل
  /// أي قائمة سابقة بالكامل.
  Future<void> setDocumentHotels(int documentId, List<int> hotelIds) async {
    await _databaseService.setDocumentHotels(documentId, hotelIds);
  }

  Future<List<int>> getDocumentHotelIds(int documentId) async {
    return await _databaseService.getDocumentHotelIds(documentId);
  }

  Future<Map<int, List<int>>> getDocumentHotelIdsBatch(List<int> documentIds) async {
    return await _databaseService.getDocumentHotelIdsBatch(documentIds);
  }

  /// نقطة الإنشاء الوحيدة — تُعيد جدولة تنبيهات الانتهاء تلقائياً (30/10/5/0
  /// يوم) فتغطي كل شاشات الإنشاء بلا أي استدعاء إضافي متفرّق.
  Future<int> addDocument(Document document) async {
    final id = await _databaseService.insertDocument(document.toMap());
    await DocumentNotificationService.rescheduleForDocument(document.copyWith(id: id));
    return id;
  }

  /// نقطة التعديل الوحيدة — تُعيد جدولة تنبيهات الانتهاء (تُلغي القديمة أولاً)
  /// فتغطي أي تغيير في تاريخ الانتهاء تلقائياً.
  Future<void> updateDocument(Document document) async {
    if (document.id != null) {
      await _databaseService.updateById('documents', document.toMap(), document.id!);
      await DocumentNotificationService.rescheduleForDocument(document);
    }
  }

  /// نقل ناعم إلى سلة المهملات — راجع TrashRepository. لا حذف لملفات المرفقات
  /// هنا إطلاقاً (يبقى المرفق سليماً لو استُعيد المستند لاحقاً) — يحدث فقط
  /// عند الحذف النهائي عبر TrashRepository._deleteAttachmentFiles. تنبيهات
  /// الانتهاء تُلغى فوراً رغم ذلك (لا معنى لتذكير بمستند غير ظاهر حالياً؛
  /// rescheduleForDocument تُعيد جدولتها تلقائياً عند الاستعادة عبر restoreDocument).
  /// تنبيه الانتهاء يُلغى فوراً (لا معنى لتذكير بمستند غير ظاهر حالياً)؛ لو
  /// استُعيد المستند لاحقاً من سلة المهملات، تُعاد جدولته تلقائياً ضمن
  /// المزامنة الشاملة التي تعمل عند كل إقلاع للتطبيق أصلاً (راجع
  /// main.dart: DocumentRepository().getAllDocuments().then(rescheduleAll)) —
  /// بلا حاجة لمسار استعادة مخصَّص هنا.
  Future<void> deleteDocument(Document document) async {
    await _trashRepository.trash('document', document.id!, document.name);
    await DocumentNotificationService.cancelForDocument(document.id!);
  }

  /// يُعيد تزويد كل الفنادق فوراً بنسخة فارغة من أي نوع مرجعي ناقص — يُستدعى
  /// بعد حذف مستند مرتبط بنوع مرجعي حتى تعود نسخة الفندق الفارغة فوراً دون
  /// انتظار إعادة فتح التطبيق (شبكة الأمان التلقائية تُغطي هذه الحالة أصلاً،
  /// لكن هذا الاستدعاء الفوري يمنح تجربة استخدام سلسة بلا فجوة).
  Future<void> reprovisionHotelDocumentTypes() async {
    await _databaseService.provisionDocumentTypesAcrossHotels();
  }

  // ---------------- المرفقات ----------------

  Future<int> addAttachment(DocumentAttachment attachment) async {
    return await _databaseService.insertDocumentAttachment(attachment.toMap());
  }

  Future<List<DocumentAttachment>> getAttachments(int documentId) async {
    final data = await _databaseService.getDocumentAttachments(documentId);
    return data.map((map) => DocumentAttachment.fromMap(map)).toList();
  }

  Future<int> deleteAttachment(int id) async {
    return await _databaseService.deleteById('document_attachments', id);
  }
}
