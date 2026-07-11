# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## نظرة عامة

تطبيق **Manazel** (منازل) هو تطبيق Flutter لإدارة مجموعة فنادق (شركة منازل البيت المحدودة): مستندات، موظفون، تقارير مالية يومية، خزنة/حسابات مالية، فواتير ضريبية، عقود، تسويات ديون بين الفنادق والأفراد. التطبيق **Android فقط** (لا توجد مجلدات `ios/` أو `web/` أو غيرها)، وواجهته **عربية بالكامل RTL** (`locale: ar_SA` ثابت في `main.dart`، لا تبديل لغة).

## الأوامر الشائعة

```bash
flutter pub get              # تثبيت الاعتماديات
flutter analyze              # فحص الأخطاء/التحذيرات (يعتمد على flutter_lints عبر analysis_options.yaml)
flutter run                  # تشغيل التطبيق على جهاز/محاكي متصل
flutter build apk            # بناء APK للأندرويد
flutter test                 # تشغيل الاختبارات
flutter test test/widget_test.dart   # تشغيل ملف اختبار واحد
```

⚠️ **ملاحظة مهمة**: `test/widget_test.dart` هو ملف القالب الافتراضي لـ Flutter (يختبر "Counter increments") ولا علاقة له بمنطق التطبيق الفعلي — سيفشل إذا شُغّل لأن `ManazelApp` لا يحتوي عداد. لا توجد اختبارات حقيقية في المشروع حالياً. لا تفترض وجود تغطية اختبارات عند تعديل الكود.

## البنية المعمارية

### تدفق الطبقات (Layering)
```
Pages (UI, StatefulWidget)  →  Repositories  →  DatabaseService (SQL خام عبر sqflite)
                             ↘  Services (منطق أعمال أثقل: FinancialEngine, VaultService, ...)
```
- الصفحات **لا تصل إلى قاعدة البيانات مباشرة أبداً** — تمر دائماً عبر `repositories/*Repository`. حافظ على هذا الفصل عند إضافة ميزات جديدة.
- `lib/core/database/database_service.dart` هو **Singleton واحد ضخم** يحوي كل جمل SQL الخام (CREATE TABLE، الاستعلامات، الترحيلات) لكل الجداول (~18 جدولاً: hotels, documents, financial_reports, financial_accounts, financial_ledger, expense_categories, pending_expenses, deposited_funds, settlements, settlement_transactions, invoices, suppliers, contracts, contract_payments, vault_balances, vault_transactions, personal_withdrawals, entity_loans...). أي جدول/عمود جديد يُضاف هنا أولاً.
- ترقيات السكيمة تتم عبر `onUpgrade` بفحص `oldVersion` تصاعدياً (النسخة الحالية v22). كل ترقية تُغلَّف بـ `try { ... } catch (_) {}` لتفادي تعطل الترقية على تثبيتات قديمة مختلفة الحالة — عند إضافة عمود/جدول جديد اتبع نفس النمط ولا تفترض أن العمود غير موجود مسبقاً.
- طبقة `services/` تحتوي منطق أعمال يتجاوز CRUD بسيط، وتُنفَّذ العمليات المركّبة (ترحيل تقرير، تحديث رصيد + قيد دفتر) داخل `db.transaction(...)` لضمان الاتساق (راجع `financial_engine.dart::postReport`).
- النماذج في `models/` كلاسات يدوية بسيطة (لا `freezed`/`json_serializable`): `fromMap`/`toMap`/`copyWith` مكتوبة يدوياً. اتبع نفس النمط عند إضافة نموذج جديد بدلاً من إدخال أداة توليد كود.

### إدارة الحالة والتنقل
- **لا توجد مكتبة إدارة حالة** (لا Provider/Riverpod/Bloc/GetX). كل شاشة تُدار محلياً عبر `StatefulWidget` + `setState`، وتُحمَّل بياناتها من الـ Repository داخل `initState`.
- **لا يوجد Router مركزي وﻻ named routes**. التنقل يتم بـ `Navigator.push(context, MaterialPageRoute(builder: (_) => TargetPage(hotel: hotel)))` مباشرة، وتمرير البيانات بين الشاشات عبر معاملات الـ constructor (مثلاً كائن `Hotel` يُمرَّر صراحةً لكل شاشة تابعة له). إرجاع نتيجة للشاشة السابقة يتم عبر `Navigator.pop(context, result)` وقراءتها من قيمة `await Navigator.push(...)`.
- عند إضافة شاشة جديدة اتبع نفس النمط الموجود؛ لا تُدخل حل توجيه (routing) أو إدارة حالة جديد بدون نقاش مسبق مع المستخدم لأن ذلك تغيير معماري واسع.

### الهوية البصرية لكل فندق
- كل فندق له لون هوية (`Hotel.identityColorValue`) يُحسب تلقائياً إن لم يوجد عبر `HotelVisualIdentity.defaultColorValue` (اسم الفندق → لون ثابت). الصفحات المرتبطة بفندق تُغلِّف `Scaffold` بـ `Theme(data: AppTheme.createTheme(identity), child: ...)` لتطبيق ألوان الفندق على تلك الشاشة فقط — راجع `dashboard_page.dart` كمرجع عند بناء شاشة جديدة مرتبطة بفندق.
- عناصر تصميم موحّدة يُعاد استخدامها من `widgets/common/`: `AppCard`, `AppButton`, `AppTextField`, `AppDrawer`, `HotelIdentityTitle`. استخدمها بدل بناء عناصر UI من الصفر.

### الأمان وجلسة الدخول
- الدخول يعتمد PIN محلي (`SecurityService` + `flutter_secure_storage`) وبصمة اختيارية (`local_auth`). `main.dart` يفحص `SecurityService.instance.hasPin()` عند الإقلاع ليقرر البدء بـ `PinLoginPage` أو `SecuritySetupPage`.
- يوجد **كلاسان متشابهان لحالة المستخدم الحالي**: `AuthService` (`services/auth_service.dart`) و`SessionService` (`services/session_service.dart`) — كلاهما يحتفظ بـ `currentUser`/`isLoggedIn` بشكل شبه مطابق. تحقق أيهما مستخدم فعلياً في المسار الذي تعدّله قبل افتراض مصدر الحقيقة الوحيد لحالة الجلسة.

### توليد التقارير والملفات
- `services/pdf_service.dart` و`services/excel_service.dart` و`services/contract_report_service.dart` تُنتج تقارير PDF/Excel (عبر `pdf`/`printing`/`excel`) وتُشارَك عبر `share_plus`. عند إضافة تقرير جديد اتبع نمط الخدمة المخصصة (خدمة واحدة لكل نوع تصدير) بدل خلط منطق التصدير داخل الصفحة.

## قواعد وملاحظات يجب مراعاتها عند التعديل

- **لا كود ميت مكرر**: يوجد حالياً ملفان بنفس الاسم `hotel_card.dart` (`pages/dashboard/hotel_card.dart` و`pages/dashboard/widgets/hotel_card.dart`) غير مستوردَين في أي مكان — لا تُضِف عليهما ظناً أنهما مستخدَمان؛ تحقق بالبحث عن الاستيراد أولاً.
- عند تعديل `database_service.dart`، أضف SQL بنفس الأسلوب المضغوط المستخدم حالياً (سطر واحد لكل `CREATE TABLE`)، وحافظ على `FOREIGN KEY ... ON DELETE CASCADE` حيث يوجد ربط بـ `hotel_id` حتى لا تتسرب بيانات يتيمة عند حذف فندق.
- لا تستخدم `print()` للتصحيح؛ لا يوجد أي استخدام له في الكود الحالي.
- التطبيق بالكامل RTL/عربي — أي نص جديد في الواجهة يجب أن يكون بالعربية متوافقاً مع بقية الشاشات (لا نصوص إنجليزية في الواجهة إلا حيث توجد فعلاً كأسماء فنية).
