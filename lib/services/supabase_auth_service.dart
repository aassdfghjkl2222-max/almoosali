import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase/supabase_config.dart';

/// جلسة تسجيل الدخول السحابية (Supabase Auth) — منفصلة تماماً عن نظام
/// PIN/اسم المستخدم المحلي ([SecurityService]/جدول users المحلي)، ولا علاقة
/// بينهما. مطلوبة لأن كل سياسات RLS في القاعدة السحابية تعتمد على
/// auth.uid() — بلا تسجيل دخول حقيقي هنا، أي قراءة/كتابة سحابية تُرفَض
/// بصمت من قبل RLS مهما كان مفتاح anon/publishable صحيحاً.
///
/// بيانات الدخول (بريد/كلمة مرور) تُخزَّن محلياً عبر FlutterSecureStorage
/// (نفس نمط SecurityService بالضبط) لإعادة الدخول التلقائي بصمت عند كل
/// مزامنة لاحقة بلا مطالبة المستخدم في كل مرة.
class SupabaseAuthService {
  static final SupabaseAuthService instance = SupabaseAuthService._();
  SupabaseAuthService._();

  final _storage = const FlutterSecureStorage();

  static const _emailKey = 'supabase_auth_email';
  static const _passwordKey = 'supabase_auth_password';

  Future<bool> hasStoredCredentials() async {
    final email = await _storage.read(key: _emailKey);
    return email != null && email.isNotEmpty;
  }

  bool get isSignedIn {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      return SupabaseConfig.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  /// يحفظ بيانات الدخول ثم يسجّل الدخول فوراً — يُستخدَم أول مرة فقط
  /// (حوار "تسجيل الدخول للمزامنة" في BackupPage).
  Future<String?> saveCredentialsAndSignIn({required String email, required String password}) async {
    final error = await _signIn(email: email, password: password);
    if (error != null) return error;
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
    return null;
  }

  /// يُعيد تسجيل الدخول تلقائياً ببيانات محفوظة سابقاً — يُستدعى في بداية كل
  /// مزامنة إن لم تكن هناك جلسة سارية بالفعل. يعيد رسالة خطأ نصية عند
  /// الفشل، أو null عند عدم وجود بيانات محفوظة أصلاً (وليس هذا خطأ بحد ذاته
  /// — راجع BackupPage لكيفية التمييز بين "لا بيانات محفوظة" و"فشل فعلي").
  Future<String?> ensureSignedIn() async {
    if (isSignedIn) return null;
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null) return null;
    return _signIn(email: email, password: password);
  }

  Future<String?> _signIn({required String email, required String password}) async {
    if (!SupabaseConfig.isConfigured) {
      return 'الاتصال بالخدمة السحابية غير مُهيَّأ في هذا الإصدار.';
    }
    try {
      await SupabaseConfig.client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return 'تعذّر تسجيل الدخول: ${e.message}';
    } catch (e) {
      return 'تعذّر تسجيل الدخول: $e';
    }
  }

  Future<void> signOut() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client.auth.signOut();
      } catch (_) {}
    }
  }
}
