import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// تحسين تلقائي لصورة الفاتورة قبل قراءتها (ذكاء اصطناعي/OCR) — تصحيح دوران
/// EXIF، تقليل تشويش خفيف، تحسين تباين/سطوع تلقائي، ثم زيادة وضوح الحواف.
/// لا يُستخدم قبل محاولة قراءة QR عمداً — قارئات الباركود تتعامل أصلاً مع
/// الميلان/الإضاءة الضعيفة بلا حاجة لمعالجة، وقد يضرّها التنعيم (يُذيب
/// حواف مربّعات QR الدقيقة). أي فشل في المعالجة يُعيد الصورة الأصلية بلا
/// توقف — تحسين الصورة تحسين اختياري، لا يجوز أن يمنع القراءة نفسها.
class ImageEnhancementService {
  ImageEnhancementService._();

  static Future<Uint8List> enhance(Uint8List bytes) async {
    try {
      var image = img.decodeImage(bytes);
      if (image == null) return bytes;

      image = img.bakeOrientation(image);

      // صور كبيرة جداً (كاميرات حديثة) تُبطئ المعالجة بلا فائدة إضافية للقراءة.
      if (image.width > 2400) {
        image = img.copyResize(image, width: 2400);
      }

      image = img.gaussianBlur(image, radius: 1);

      final avgLuminance = _averageLuminance(image);
      final brightness = avgLuminance < 0.35 ? 1.25 : (avgLuminance < 0.5 ? 1.1 : 1.0);

      image = img.normalize(image, min: 0, max: 255);
      image = img.adjustColor(image, contrast: 1.2, brightness: brightness);

      // تحديد حواف/نص تقريبي (unsharp mask) بعد التنعيم لتعويض فقدان الوضوح.
      image = img.convolution(image, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0]);

      return Uint8List.fromList(img.encodePng(image));
    } catch (_) {
      return bytes;
    }
  }

  static Future<List<Uint8List>> enhanceAll(List<Uint8List> images) async {
    final result = <Uint8List>[];
    for (final bytes in images) {
      result.add(await enhance(bytes));
    }
    return result;
  }

  /// متوسط الإضاءة (0-1) بأخذ عيّنة شبكية بدل كل البكسلات (أداء أفضل، دقة
  /// كافية لقرار "هل الصورة مظلمة؟").
  static double _averageLuminance(img.Image image) {
    const step = 12;
    double sum = 0;
    int count = 0;
    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        sum += image.getPixel(x, y).luminanceNormalized;
        count++;
      }
    }
    return count == 0 ? 0.5 : sum / count;
  }
}
