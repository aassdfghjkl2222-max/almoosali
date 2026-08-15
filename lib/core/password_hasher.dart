import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// تجزئة كلمات مرور نظام المستخدمين المحلي (users.password_hash/password_salt)
/// عبر PBKDF2-HMAC-SHA256 — بلا اعتماديات native، يكفي تماماً لتهديد قراءة ملف
/// SQLite على نفس الجهاز (لا خدمة شبكية تتعرض لهجوم قوة غاشمة عن بعد).
///
/// لا علاقة له بـ SecurityService (PIN الجهاز، نص صريح عمداً بتصميم سابق منفصل)
/// ولا بـ SupabaseAuthService (مزامنة الفنادق السحابية).
class PasswordHasher {
  PasswordHasher._();

  static const _iterations = 100000;
  static const _saltBytes = 16;
  static const _keyBytes = 32;

  /// يولّد ملحاً عشوائياً جديداً ويُرجع (hash, salt) كنصوص Base64 جاهزة للتخزين.
  static ({String hash, String salt}) hash(String password) {
    final salt = _randomBytes(_saltBytes);
    final hashBytes = _pbkdf2(password, salt);
    return (hash: base64Encode(hashBytes), salt: base64Encode(salt));
  }

  /// يتحقق من كلمة مرور مقابل hash/salt مخزَّنين مسبقاً.
  static bool verify(String password, String storedHash, String storedSalt) {
    final salt = base64Decode(storedSalt);
    final computed = _pbkdf2(password, salt);
    return _constantTimeEquals(computed, base64Decode(storedHash));
  }

  static List<int> _randomBytes(int length) {
    final rand = Random.secure();
    return List<int>.generate(length, (_) => rand.nextInt(256));
  }

  static List<int> _pbkdf2(String password, List<int> salt) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);
    var u = hmac.convert(salt + [0, 0, 0, 1]).bytes;
    var result = List<int>.from(u);
    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result.sublist(0, _keyBytes);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
