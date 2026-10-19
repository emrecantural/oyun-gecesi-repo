import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/room/oda_servisi.dart';

void main() {
  test('kimlik özeti SHA-256 hex (sunucu ile aynı vektör)', () {
    expect(kimlikOzeti('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(kimlikOzeti('abc').length, 64);
  });
}
