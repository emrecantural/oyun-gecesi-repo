import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/content/deste.dart';
import 'package:oyungecesi/content/icerik.dart';
import 'package:oyungecesi/core/csv.dart';

void main() {
  group('csvAyristir', () {
    test('tırnak, virgül ve kaçış', () {
      final r = csvAyristir('a,b\n"x, y","say ""şu"""\n');
      expect(r.length, 1);
      expect(r.first['a'], 'x, y');
      expect(r.first['b'], 'say "şu"');
    });
    test('CRLF ve BOM', () {
      final r = csvAyristir('﻿a,b\r\n1,2\r\n3,4');
      expect(r.map((e) => e['a']), ['1', '3']);
    });
    test('tırnak içinde satır sonu', () {
      final r = csvAyristir('a,b\n"x\ny",z\n');
      expect(r.first['a'], 'x\ny');
    });
  });

  group('icerikAyristir', () {
    const csv = 'id,oyun,tur,seviye,metin,ek,fiziksel,grup,risk,kaynak,durum,yazar,editor,notlar\n'
        '1,05,kart,tatli,Bir,,0,0,dusuk,x,taslak,c,,\n'
        '2,05,kart,tatli,İki,,0,0,dusuk,x,onayli,c,e,\n'
        '3,05,kart,tatli,Üç,,0,0,dusuk,x,reddedildi,c,,\n';
    test('taslak dahil değilken yalnız onaylı', () {
      final r = icerikAyristir(csv, taslakDahil: false);
      expect(r.map((e) => e.id), ['2']);
    });
    test('taslak dahil: reddedilen hariç', () {
      final r = icerikAyristir(csv, taslakDahil: true);
      expect(r.map((e) => e.id), ['1', '2']);
    });
  });

  group('ucretsizSayisi', () {
    test('min(n, max(5, ceil(0,4n)))', () {
      expect(ucretsizSayisi(40), 16);
      expect(ucretsizSayisi(30), 12);
      expect(ucretsizSayisi(20), 8);
      expect(ucretsizSayisi(103), 42);
      expect(ucretsizSayisi(10), 5);
      expect(ucretsizSayisi(3), 3);
      expect(ucretsizSayisi(0), 0);
    });
    test('grup başına ilk N ücretsiz', () {
      final l = [
        for (var i = 0; i < 10; i++)
          IcerikOgesi(
            id: '$i', oyun: '', tur: 'k', seviye: 'a', metin: 'm', ek: '',
            fiziksel: false, grup: false, risk: '', durum: 'onayli'),
      ];
      final r = ucretsizBol(l);
      expect(r.where((o) => o.ucretsiz).length, 5);
      expect(r.first.ucretsiz, isTrue);
      expect(r.last.ucretsiz, isFalse);
    });
  });

  group('Deste', () {
    test('havuz tükenene kadar tekrar yok', () {
      final d = Deste<int>(List.generate(20, (i) => i),
          idOf: (i) => '$i', rastgele: Random(1));
      final cekilen = [for (var i = 0; i < 20; i++) d.cek()!];
      expect(cekilen.toSet().length, 20);
      expect(d.yenilenme, 0);
    });
    test('tükenince yenilenir, son 10 hariç', () {
      final d = Deste<int>(List.generate(20, (i) => i),
          idOf: (i) => '$i', rastgele: Random(2));
      final ilk = [for (var i = 0; i < 20; i++) d.cek()!];
      final son10 = ilk.sublist(10).toSet();
      final sonraki = d.cek()!;
      expect(d.yenilenme, 1);
      expect(son10.contains(sonraki), isFalse);
    });
    test('küçük havuz: hepsi hariçse yine kart verir', () {
      final d = Deste<int>([1, 2, 3], idOf: (i) => '$i', rastgele: Random(3));
      for (var i = 0; i < 10; i++) {
        expect(d.cek(), isNotNull);
      }
    });
    test('görülmüş kartlar atlanır', () {
      final d = Deste<int>([1, 2, 3],
          idOf: (i) => '$i', gorulmus: {'1', '2'}, rastgele: Random(4));
      expect(d.cek(), 3);
    });
    test('boş havuz null', () {
      expect(Deste<int>([], idOf: (i) => '$i').cek(), isNull);
    });
  });
}
