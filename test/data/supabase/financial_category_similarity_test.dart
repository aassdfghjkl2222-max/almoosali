import 'package:flutter_test/flutter_test.dart';
import 'package:manazel_new/core/text_similarity.dart';

void main() {
  group('isLikelyDuplicateCategoryName', () {
    test('exact match (after trim/case) is a duplicate', () {
      expect(isLikelyDuplicateCategoryName('كهرباء', 'كهرباء'), isTrue);
      expect(isLikelyDuplicateCategoryName(' Electricity ', 'electricity'), isTrue);
    });

    test('one name containing the other is a duplicate', () {
      expect(isLikelyDuplicateCategoryName('باركنج', 'إيراد الباركنج'), isTrue);
      expect(isLikelyDuplicateCategoryName('Parking', 'Parking Revenue'), isTrue);
    });

    test('high token overlap (>=0.5 Jaccard) is a duplicate', () {
      expect(isLikelyDuplicateCategoryName('صيانة عامة للفندق', 'صيانة عامة للمبنى'), isTrue);
    });

    test('genuinely different single-word names are not duplicates', () {
      expect(isLikelyDuplicateCategoryName('كهرباء', 'مياه'), isFalse);
      expect(isLikelyDuplicateCategoryName('Electricity', 'Water'), isFalse);
    });

    test('different multi-word names with low overlap are not duplicates', () {
      expect(isLikelyDuplicateCategoryName('صيانة السباكة الداخلية', 'رواتب الموظفين الشهرية'), isFalse);
    });

    test('empty strings never match', () {
      expect(isLikelyDuplicateCategoryName('', 'كهرباء'), isFalse);
      expect(isLikelyDuplicateCategoryName('كهرباء', ''), isFalse);
    });

    test('Arabic alef/taa-marbuta/yaa normalization treats variants as equal', () {
      expect(isLikelyDuplicateCategoryName('إيراد', 'ايراد'), isTrue);
      expect(isLikelyDuplicateCategoryName('ضريبة', 'ضريبه'), isTrue);
    });
  });
}
