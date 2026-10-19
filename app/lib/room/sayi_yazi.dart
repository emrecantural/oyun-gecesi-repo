const _birler = ['', 'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz', 'dokuz'];
const _onlar = ['', 'on', 'yirmi', 'otuz', 'kırk', 'elli', 'altmış', 'yetmiş', 'seksen', 'doksan'];

/// 1–99 arası sayıyı Türkçe yazıya çevirir (HOST ekranı ve ekran okuyucu için); aralık dışı rakamla döner.
String sayiYazi(int n) {
  if (n < 1 || n > 99) return '$n';
  final on = _onlar[n ~/ 10];
  final bir = _birler[n % 10];
  return [on, bir].where((s) => s.isNotEmpty).join(' ');
}
