import { test } from 'node:test';
import assert from 'node:assert/strict';
import { lobiKur } from './yardimci.ts';
import { kartImza, kartUret, satirTamamSayisi } from '../src/games/tombala.ts';
import { tohumluRand } from '../src/core/rng.ts';

test('10.000 kart: yapı kurallarına uygun', () => {
  const rand = tohumluRand(2026);
  for (let i = 0; i < 10_000; i++) {
    const k = kartUret(rand);
    assert.equal(k.length, 3);
    let toplam = 0;
    for (const satir of k) {
      assert.equal(satir.length, 9);
      assert.equal(satir.filter((n) => n > 0).length, 5);
      toplam += satir.filter((n) => n > 0).length;
    }
    assert.equal(toplam, 15);
    for (let j = 0; j < 9; j++) {
      const kolon = k.map((s) => s[j]).filter((n) => n > 0);
      assert.ok(kolon.length >= 1 && kolon.length <= 3, `sütun ${j} sayısı`);
      const lo = j === 0 ? 1 : j * 10;
      const hi = j === 8 ? 90 : j * 10 + 9;
      for (const n of kolon) assert.ok(n >= lo && n <= hi, `${n} sütun ${j} aralığında`);
      const sirali = [...kolon].sort((a, b) => a - b);
      assert.deepEqual(kolon, sirali);
      assert.equal(new Set(kolon).size, kolon.length);
    }
  }
});

test('çekim: 90 sayı tekrarsız', () => {
  const l = lobiKur(2, '01', { hiz: 3 });
  l.e.gonder('h', 'start');
  l.e.ilerle(3000); // KART_DAGIT → ilk çekim
  for (let i = 0; i < 100; i++) l.e.ilerle(3000);
  const cekilenler = l.conns.p1.hepsi('draw').map((m) => m.p.n);
  assert.equal(cekilenler.length, 90);
  assert.equal(new Set(cekilenler).size, 90);
  assert.equal(l.e.oda.phase, 'FINAL');
  assert.equal(l.conns.p1.son('final')!.p.none, true);
});

test('aynı odada kartlar benzersiz; kartlar yalnız sahibine gider', () => {
  const l = lobiKur(10, '01', { kartSayisi: 3 });
  l.e.gonder('h', 'start');
  const imzalar = new Set<string>();
  for (const k of Object.keys(l.conns)) {
    const c = l.conns[k].son('cards')!.p.cards;
    assert.equal(c.length, 3);
    for (const kart of c) imzalar.add(kartImza(kart));
  }
  assert.equal(imzalar.size, 30);
  // başkasının kartı başka bağlantıya ulaşmadı
  const p1kart = JSON.stringify(l.conns.p1.son('cards')!.p.cards);
  assert.equal(JSON.stringify(l.conns.p2.gelen).includes(p1kart), false);
});

// Yardımcı: sunucudaki gerçek kartı ve çekilenleri okuyup ilk tamamlanan satırı bulur.
function durum(l: ReturnType<typeof lobiKur>) {
  return (l.e.oda.toJSON().game as any);
}
function cekimleriSurdur(l: ReturnType<typeof lobiKur>, kosul: () => boolean, azami = 90) {
  for (let i = 0; i < azami && !kosul(); i++) l.e.ilerle(5000);
}

test('geçerli çinko ödül kazandırır; geçersiz çinko ceza kilidi koyar', () => {
  const l = lobiKur(3, '01', { hiz: 5 });
  l.e.gonder('h', 'start');
  l.e.ilerle(3000);
  // Henüz satır tamam değilken çinko: geçersiz
  l.e.gonder('p1', 'claim', { cardIdx: 0, type: 'cinko1' });
  const gecersiz = l.conns.p1.son('claimResult')!.p;
  assert.equal(gecersiz.ok, false);
  assert.equal(gecersiz.reason, 'CLAIM_INVALID');
  assert.equal(gecersiz.lockUntilIdx, 1 + 3);
  l.e.gonder('p1', 'claim', { cardIdx: 0, type: 'cinko1' });
  assert.ok(l.conns.p1.hatalar().includes('CLAIM_LOCKED'));
  // Biri satırı tamamlayana kadar çek
  const kim = () => Object.keys(durum(l).kartlar).find((pid) => {
    const g = new Set<number>(durum(l).cekilen);
    return durum(l).kartlar[pid].some((k: number[][]) => satirTamamSayisi(k, g) >= 1);
  });
  cekimleriSurdur(l, () => !!kim());
  const pid = kim()!;
  const anahtar = Object.entries(l.ids).find(([, v]) => v === pid)![0];
  // kilitli olan p1 ise kilit bitene kadar bekle: farklı oyuncu bulunamazsa devam
  l.e.gonder(anahtar, 'claim', { cardIdx: 0, type: 'cinko1' });
  const kartIdx = durum(l).kartlar[pid].findIndex((k: number[][]) => satirTamamSayisi(k, new Set<number>(durum(l).cekilen)) >= 1);
  l.e.gonder(anahtar, 'claim', { cardIdx: kartIdx, type: 'cinko1' });
  const sonuc = l.conns[anahtar].hepsi('claimResult').filter((m) => m.p.ok);
  if (anahtar !== 'p1') assert.equal(sonuc.length >= 1, true);
  l.e.ilerle(1500);
  assert.equal(l.e.oda.phase, 'ODUL');
  const od = l.conns.h.son('prize')!.p;
  assert.equal(od.tur, 'cinko1');
  assert.deepEqual(od.winners, [pid]);
  l.e.ilerle(4000);
  assert.equal(l.e.oda.phase, 'CEKIM');
});

test('ödül dağıtıldıktan sonra aynı türden iddia NO_PRIZE; çekim sayısı artmaz çift', () => {
  const l = lobiKur(2, '01', { hiz: 3 });
  l.e.gonder('h', 'start');
  l.e.ilerle(3000);
  const g = () => durum(l);
  const bul = () => Object.keys(g().kartlar).find((pid) => g().kartlar[pid].some((k: number[][]) => satirTamamSayisi(k, new Set<number>(g().cekilen)) >= 1));
  for (let i = 0; i < 90 && !bul(); i++) l.e.ilerle(3000);
  const pid = bul()!;
  const key = Object.entries(l.ids).find(([, v]) => v === pid)![0];
  const kidx = g().kartlar[pid].findIndex((k: number[][]) => satirTamamSayisi(k, new Set<number>(g().cekilen)) >= 1);
  l.e.gonder(key, 'claim', { cardIdx: kidx, type: 'cinko1' });
  l.e.ilerle(1500);
  l.e.ilerle(4000);
  l.e.gonder(key, 'claim', { cardIdx: kidx, type: 'cinko1' });
  const son = l.conns[key].hepsi('claimResult').pop()!.p;
  assert.deepEqual([son.ok, son.reason], [false, 'NO_PRIZE']);
});

const SATIR = [5, 0, 25, 0, 45, 0, 65, 0, 85];

function kartKur(l: ReturnType<typeof lobiKur>, pid: string, kart: number[][]) {
  durum(l).kartlar[pid][0] = kart;
}

test('aynı çekimde iki geçerli çinko: ikisi de ödülü alır (beraberlik)', () => {
  const l = lobiKur(3, '01', { hiz: 5 });
  l.e.gonder('h', 'start');
  l.e.ilerle(3000);
  kartKur(l, l.ids.h, [SATIR, Array(9).fill(0), Array(9).fill(0)]);
  kartKur(l, l.ids.p1, [SATIR, Array(9).fill(0), Array(9).fill(0)]);
  durum(l).cekilen = [5, 25, 45, 65, 85];
  l.e.gonder('h', 'claim', { cardIdx: 0, type: 'cinko1' });
  assert.equal(l.e.oda.phase, 'CINKO_KONTROL');
  l.e.ilerle(500);
  l.e.gonder('p1', 'claim', { cardIdx: 0, type: 'cinko1' });
  l.e.ilerle(1100);
  assert.equal(l.e.oda.phase, 'ODUL');
  const od = l.conns.p2.son('prize')!.p;
  assert.deepEqual([...od.winners].sort(), [l.ids.h, l.ids.p1].sort());
});

test('2. çinko iki satırla, tombala 15 sayıyla; tombala oyunu bitirir; rozetler', () => {
  const l = lobiKur(2, '01', { hiz: 5 });
  l.e.gonder('h', 'start');
  l.e.ilerle(3000);
  const tam: number[][] = [SATIR, [3, 13, 0, 33, 0, 53, 0, 73, 0], [7, 0, 27, 0, 47, 0, 67, 0, 87]];
  kartKur(l, l.ids.h, tam);
  // Yalnız ilk satır çekildi: 2. çinko geçersiz
  durum(l).cekilen = [5, 25, 45, 65, 85];
  l.e.gonder('h', 'claim', { cardIdx: 0, type: 'cinko2' });
  assert.equal(l.conns.h.son('claimResult')!.p.ok, false);
  durum(l).kilit = {};
  durum(l).cekilen = [5, 25, 45, 65, 85, 3, 13, 33, 53, 73];
  l.e.gonder('h', 'claim', { cardIdx: 0, type: 'cinko2' });
  l.e.ilerle(1500);
  assert.equal(l.conns.p1.son('prize')!.p.tur, 'cinko2');
  l.e.ilerle(4000);
  // Tombala: hepsi
  durum(l).cekilen = [...durum(l).cekilen, 7, 27, 47, 67, 87];
  l.e.gonder('h', 'claim', { cardIdx: 0, type: 'tombala' });
  l.e.ilerle(1500);
  l.e.ilerle(4000);
  assert.equal(l.e.oda.phase, 'FINAL');
  const f = l.conns.p1.son('final')!.p;
  assert.equal(f.none, false);
  assert.deepEqual(f.badges.find((b: any) => b.badge === 'lucky').playerIds, [l.ids.h]);
  assert.deepEqual(f.badges.find((b: any) => b.badge === 'lastMinute').playerIds, [l.ids.h]);
});

test('elle hız: yalnız host next ile çeker; setSpeed yalnız host', () => {
  const l = lobiKur(2, '01', { hiz: 0 });
  l.e.gonder('h', 'start');
  l.e.ilerle(3000);
  const ilk = durum(l).cekilen.length;
  l.e.ilerle(60_000);
  assert.equal(durum(l).cekilen.length, ilk);
  l.e.gonder('p1', 'next');
  assert.deepEqual(l.conns.p1.hatalar().slice(-1), ['NOT_HOST']);
  l.e.gonder('h', 'next');
  assert.equal(durum(l).cekilen.length, ilk + 1);
  l.e.gonder('p1', 'setSpeed', { speed: 3 });
  assert.deepEqual(l.conns.p1.hatalar().slice(-1), ['NOT_HOST']);
});

test('duraklat/devam: duraklatılmışken sayı çekilmez', () => {
  const l = lobiKur(2, '01', { hiz: 3 });
  l.e.gonder('h', 'start');
  l.e.ilerle(3000);
  l.e.gonder('h', 'pause');
  const n = durum(l).cekilen.length;
  l.e.ilerle(30_000);
  assert.equal(durum(l).cekilen.length, n);
  assert.equal(l.conns.p1.son('state')!.p.public.paused, true);
  l.e.gonder('h', 'unpause');
  l.e.ilerle(3000);
  assert.equal(durum(l).cekilen.length, n + 1);
});

test('geç katılım: kart verilir, geçmiş sayılar snapshot\'ta; kapalıysa reddedilir', () => {
  const l = lobiKur(3, '01', { hiz: 3 });
  l.e.gonder('h', 'start');
  l.e.ilerle(3000);
  l.e.ilerle(3000);
  const g = l.e.katil('g', 'Gec');
  const w = g.son('welcome')!.p;
  assert.equal(w.snapshot.public.drawn.length, 2);
  assert.equal(g.son('cards')!.p.cards.length, 1);
  const l2 = lobiKur(3, '01', { gecKatilim: false });
  l2.e.gonder('h', 'start');
  const r = l2.e.katil('g', 'Gec');
  assert.deepEqual(r.hatalar(), ['LATE_JOIN_CLOSED']);
});

test('ekran (HOST) kart almaz, çekimleri görür', () => {
  const l = lobiKur(3, '01', { hiz: 3 });
  const d = l.e.katil('d', 'Tablet', 'display');
  l.e.gonder('h', 'start');
  l.e.ilerle(3000);
  assert.equal(d.hepsi('cards').length, 0);
  assert.equal(d.hepsi('draw').length, 1);
});

test('sunucuda kart doğrulaması: istemci başkasının kartıyla iddia edemez', () => {
  const l = lobiKur(3, '01', { hiz: 3 });
  l.e.gonder('h', 'start');
  l.e.ilerle(3000);
  l.e.gonder('p1', 'claim', { cardIdx: 5, type: 'cinko1' });
  assert.deepEqual(l.conns.p1.hatalar().slice(-1), ['INVALID_MESSAGE']);
});

test('ayarlar: ödül listesi doğrulanır (1–6, ad ≤24, geçerli tür)', () => {
  const l = lobiKur(2, '01');
  l.e.gonder('h', 'setSettings', { oduller: [] });
  l.e.gonder('h', 'setSettings', { oduller: [{ name: 'x'.repeat(25), tur: 'tombala' }] });
  l.e.gonder('h', 'setSettings', { oduller: [{ name: 'a', tur: 'yok' }] });
  assert.deepEqual(l.conns.h.hatalar(), ['INVALID_MESSAGE', 'INVALID_MESSAGE', 'INVALID_MESSAGE']);
  l.e.gonder('h', 'setSettings', { oduller: [{ name: '', tur: 'tombala' }, { name: 'Pasta', tur: 'cinko1' }] });
  const o = l.conns.p1.son('settings')!.p.settings.oduller;
  assert.deepEqual(o, [{ name: 'Tombala', tur: 'tombala' }, { name: 'Pasta', tur: 'cinko1' }]);
});
