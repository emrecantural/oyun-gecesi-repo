/// Türkçe büyük/küçük harf ve aksan duyarsız karşılaştırma yardımcıları.
///
/// Dart'ın `toUpperCase/toLowerCase` işlevleri dile bağımsızdır; `i→İ`, `ı→I`
/// dönüşümünü yapmaz. Bu yüzden proje metin işlemlerini buradan yapar.
library;

/// Türkçe kurallarına göre büyütür: `i→İ`, `ı→I`.
String trUpper(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    switch (ch) {
      case 'i':
        buffer.write('İ');
      case 'ı':
        buffer.write('I');
      default:
        buffer.write(ch.toUpperCase());
    }
  }
  return buffer.toString();
}

/// Türkçe kurallarına göre küçültür: `İ→i`, `I→ı`.
String trLower(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    switch (ch) {
      case 'İ':
        buffer.write('i');
      case 'I':
        buffer.write('ı');
      default:
        buffer.write(ch.toLowerCase());
    }
  }
  return buffer.toString();
}

const _foldMap = <String, String>{
  'ç': 'c',
  'ğ': 'g',
  'ı': 'i',
  'ö': 'o',
  'ş': 's',
  'ü': 'u',
  'â': 'a',
  'î': 'i',
  'û': 'u',
};

/// Eşleştirme için: Türkçe küçült + aksanları katla (ç→c, ğ→g, ı→i, ö→o,
/// ş→s, ü→u, â→a, î→i, û→u). Boşlukları ve noktalamayı korur.
String foldTr(String input) {
  final lower = trLower(input);
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_foldMap[ch] ?? ch);
  }
  return buffer.toString();
}

/// Türkçe alfabe sırası (oyuncu listesi gibi tek yerde kullanılır).
const _alphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

int _rank(String ch) {
  final index = _alphabet.indexOf(ch);
  return index < 0 ? _alphabet.length + ch.codeUnitAt(0) : index;
}

/// Türkçe alfabeye göre karşılaştırır (büyük/küçük harf duyarsız).
int compareTr(String a, String b) {
  final x = trLower(a);
  final y = trLower(b);
  final length = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < length; i++) {
    final diff = _rank(x[i]) - _rank(y[i]);
    if (diff != 0) return diff;
  }
  return x.length - y.length;
}
