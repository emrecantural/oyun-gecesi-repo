import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/room/sayi_yazi.dart';

void main() {
  test('Türkçe sayı yazımı', () {
    expect(sayiYazi(1), 'bir');
    expect(sayiYazi(10), 'on');
    expect(sayiYazi(47), 'kırk yedi');
    expect(sayiYazi(90), 'doksan');
    expect(sayiYazi(83), 'seksen üç');
    expect(sayiYazi(100), '100');
  });
}
