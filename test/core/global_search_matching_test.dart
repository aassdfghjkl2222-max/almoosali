import 'package:flutter_test/flutter_test.dart';
import 'package:manazel_new/core/text_similarity.dart';

void main() {
  group('globalSearchMatches', () {
    test('partial match anywhere in the string, case-insensitive', () {
      final query = normalizeForCategoryNameComparison('احمد');
      expect(globalSearchMatches('أحمد محمد', query), isTrue);
      expect(globalSearchMatches('محمد أحمد', query), isTrue);
    });

    test('English partial match, ignoring case', () {
      final query = normalizeForCategoryNameComparison('MAN');
      expect(globalSearchMatches('Manazel Al-Bayt Co.', query), isTrue);
    });

    test('ignores Arabic diacritics in the stored text', () {
      final query = normalizeForCategoryNameComparison('ايراد');
      expect(globalSearchMatches('إِيرَادٌ إضافي', query), isTrue);
    });

    test('no match returns false', () {
      final query = normalizeForCategoryNameComparison('كهرباء');
      expect(globalSearchMatches('صيانة السباكة', query), isFalse);
    });

    test('null or empty haystack never matches', () {
      final query = normalizeForCategoryNameComparison('test');
      expect(globalSearchMatches(null, query), isFalse);
      expect(globalSearchMatches('', query), isFalse);
    });

    test('empty query never matches (avoids matching everything on an empty search)', () {
      expect(globalSearchMatches('أي نص', ''), isFalse);
    });

    test('numeric/code partial match (tax numbers, invoice numbers)', () {
      final query = normalizeForCategoryNameComparison('3000000');
      expect(globalSearchMatches('300000000000003', query), isTrue);
    });
  });
}
