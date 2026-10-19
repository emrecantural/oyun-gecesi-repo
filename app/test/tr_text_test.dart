import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/core/tr_text.dart';

void main() {
  group('trUpper', () {
    test('i→İ ve ı→I', () {
      expect(trUpper('istanbul'), 'İSTANBUL');
      expect(trUpper('ığdır'), 'IĞDIR');
    });
    test('diğer harfler', () {
      expect(trUpper('çğöşü'), 'ÇĞÖŞÜ');
    });
  });

  group('trLower', () {
    test('İ→i ve I→ı', () {
      expect(trLower('İSTANBUL'), 'istanbul');
      expect(trLower('IĞDIR'), 'ığdır');
    });
    test('diğer harfler', () {
      expect(trLower('ÇĞÖŞÜ'), 'çğöşü');
    });
  });

  group('foldTr', () {
    test('aksanlar katlanır', () {
      expect(foldTr('Çığ Öşü'), 'cig osu');
      expect(foldTr('İĞNE'), 'igne');
      expect(foldTr('IĞDIR'), 'igdir');
    });
    test('eşleşme', () {
      expect(foldTr('Şişe'), foldTr('sise'));
      expect(foldTr('Kâğıt'), 'kagit');
    });
  });

  group('compareTr', () {
    test('Türkçe alfabe sırası', () {
      final list = ['Zeynep', 'Çağla', 'Ali', 'Ömer', 'Cem', 'ışık', 'İpek']
        ..sort(compareTr);
      expect(list, ['Ali', 'Cem', 'Çağla', 'ışık', 'İpek', 'Ömer', 'Zeynep']);
    });
  });
}
