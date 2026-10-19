import { test } from 'node:test';
import assert from 'node:assert/strict';
import { lobiKur, ortamKur } from './yardimci.ts';
import { sha256Hex } from '../src/core/sha256.ts';

test('sha256 bilinen vektörler', () => {
  assert.equal(sha256Hex(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  assert.equal(sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  assert.equal(
    sha256Hex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
    '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
  );
});

test('katılım: welcome, token yalnız yeni oyuncuya, hash olarak saklanır', () => {
  const { e, conns } = lobiKur(3);
  const w = conns.p1.son('welcome')!;
  assert.equal(typeof w.p.resumeToken, 'string');
  assert.equal(w.p.snapshot.code, 'TEST42');
  const rec = e.oda.players.find((p) => p.id === w.p.playerId)!;
  assert.notEqual(rec.tokenHash, w.p.resumeToken);
  assert.equal(rec.tokenHash, sha256Hex(w.p.resumeToken));
  // host resume ile girdi: yeni token verilmez
  assert.equal(conns.h.son('welcome')!.p.resumeToken, undefined);
  assert.equal(conns.h.son('welcome')!.p.hostId, conns.h.son('welcome')!.p.playerId);
});

test('aynı takma ad otomatik ek alır; küfür reddedilir; kısa ad reddedilir', () => {
  const { e, conns } = lobiKur(2);
  const c = e.katil('x', 'Oyuncu1');
  assert.equal(c.son('welcome')!.p.snapshot.roster.players.some((p: any) => p.nickname === 'Oyuncu1 2'), true);
  const r = e.katil('y', 'a');
  assert.deepEqual(r.hatalar(), ['NICKNAME_REJECTED']);
  const k = e.katil('z', 'Amk');
  assert.deepEqual(k.hatalar(), ['NICKNAME_REJECTED']);
  void conns;
});

test('oda dolu ve geç katılım kuralları', () => {
  const { e } = lobiKur(20);
  const dolu = e.katil('f', 'Fazla');
  assert.deepEqual(dolu.hatalar(), ['ROOM_FULL']);
  const e2 = lobiKur(3);
  e2.e.gonder('h', 'start');
  const gec = e2.e.katil('g', 'Gec');
  assert.deepEqual(gec.hatalar(), ['LATE_JOIN_CLOSED']);
  const sey = e2.e.katil('s', 'Seyirci', 'spectator');
  assert.equal(sey.son('welcome')!.p.role, 'spectator');
});

test('yanlış oda kodu ROOM_NOT_FOUND', () => {
  const e = ortamKur();
  const c = e.baglan('a');
  e.oda.mesaj('a', JSON.stringify({ v: 1, t: 'join', p: { code: 'YANLIS', nickname: 'Ali', installId: 'x' } }));
  assert.deepEqual(c.hatalar(), ['ROOM_NOT_FOUND']);
  assert.equal(c.kapandi?.code, 4404);
});

test('sürüm uyuşmazlığı UPGRADE_REQUIRED ve kapanış', () => {
  const e = ortamKur();
  const c = e.baglan('a');
  e.oda.mesaj('a', JSON.stringify({ v: 2, t: 'join', p: {} }));
  assert.deepEqual(c.hatalar(), ['UPGRADE_REQUIRED']);
  assert.ok(c.kapandi);
});

test('bilinmeyen/bozuk mesaj INVALID_MESSAGE; büyük mesaj PAYLOAD_TOO_LARGE', () => {
  const { e, conns } = lobiKur(2);
  e.oda.mesaj('p1', 'bozuk{');
  e.oda.mesaj('p1', JSON.stringify({ v: 1, t: 'nope', id: 'a1', p: {} }));
  e.oda.mesaj('p1', 'x'.repeat(9000));
  assert.deepEqual(conns.p1.hatalar(), ['INVALID_MESSAGE', 'INVALID_MESSAGE', 'PAYLOAD_TOO_LARGE']);
});

test('idempotency: aynı id ikinci kez işlenmez, ack tekrar döner', () => {
  const { e, conns } = lobiKur(3);
  for (let i = 0; i < 5; i++) e.gonder('p1', 'reaction', { emoji: '🔥' }, 'ayni-id');
  assert.equal(conns.p2.hepsi('reaction').length, 1);
  assert.equal(conns.p1.hepsi('ack').length, 5);
});

test('host yetkisi: başlat/ayar/atma yalnız host', () => {
  const { e, conns, ids } = lobiKur(3);
  e.gonder('p1', 'start');
  e.gonder('p1', 'setSettings', { soruSayisi: 10 });
  e.gonder('p1', 'kick', { playerId: ids.p2 });
  assert.deepEqual(conns.p1.hatalar(), ['NOT_HOST', 'NOT_HOST', 'NOT_HOST']);
});

test('en az oyuncu: 2 kişiyle 07 başlamaz', () => {
  const { e, conns } = lobiKur(2);
  e.gonder('h', 'start');
  assert.deepEqual(conns.h.hatalar(), ['MIN_PLAYERS']);
});

test('ayar doğrulama: geçersiz değer reddedilir, geçerli yayınlanır', () => {
  const { e, conns } = lobiKur(3);
  e.gonder('h', 'setSettings', { soruSayisi: 7 });
  assert.deepEqual(conns.h.hatalar(), ['INVALID_MESSAGE']);
  e.gonder('h', 'setSettings', { soruSayisi: 10, tahmin: true });
  assert.equal(conns.p1.son('settings')!.p.settings.soruSayisi, 10);
});

test('yeniden bağlanma: aynı oyuncu, eski bağlantı SUPERSEDED, gizli veri geri gelir', () => {
  const { e, conns, ids } = lobiKur(3);
  const token = conns.p1.son('welcome')!.p.resumeToken;
  const yeni = e.baglan('p1b');
  e.oda.mesaj('p1b', JSON.stringify({ v: 1, t: 'resume', p: { resumeToken: token, lastSeq: 0 } }));
  assert.equal(yeni.son('welcome')!.p.playerId, ids.p1);
  assert.deepEqual(conns.p1.hatalar(), ['SUPERSEDED']);
  assert.equal(conns.p1.kapandi?.reason, 'SUPERSEDED');
  // eski bağlantı kapanışı oyuncuyu koparmamalı
  e.oda.baglantiKapandi('p1');
  assert.equal(e.oda.players.find((p) => p.id === ids.p1)!.connected, true);
});

test('geçersiz resume token reddedilir', () => {
  const e = ortamKur();
  const c = e.baglan('a');
  e.oda.mesaj('a', JSON.stringify({ v: 1, t: 'resume', p: { resumeToken: 'yok' } }));
  assert.deepEqual(c.hatalar(), ['ROOM_NOT_FOUND']);
});

test('host 15 sn kopuk kalırsa devir olur ve hostChanged yayınlanır', () => {
  const { e, conns, ids } = lobiKur(4);
  e.oda.baglantiKapandi('h');
  e.ilerle(14_000);
  assert.equal(e.oda.hostId, ids.h);
  e.ilerle(1_100);
  assert.equal(e.oda.hostId, ids.p1);
  assert.equal(conns.p2.son('hostChanged')!.p.hostId, ids.p1);
});

test('host 15 sn içinde dönerse devir olmaz', () => {
  const { e, ids } = lobiKur(3);
  e.oda.baglantiKapandi('h');
  e.ilerle(5_000);
  const c = e.baglan('h2');
  e.oda.mesaj('h2', JSON.stringify({ v: 1, t: 'resume', p: { resumeToken: e.hostToken } }));
  void c;
  e.ilerle(20_000);
  assert.equal(e.oda.hostId, ids.h);
});

test('boş oda 10 dk sonra kapanır', () => {
  const { e } = lobiKur(3);
  for (const k of ['h', 'p1', 'p2']) e.oda.baglantiKapandi(k);
  assert.ok(e.oda.sonrakiUyanis()! <= e.zaman.t + 10 * 60_000);
  e.ilerle(10 * 60_000 + 1);
  assert.equal(e.oda.closed, true);
});

test('hız sınırı: sürekli taşma RATE_LIMITED döner', () => {
  const { e, conns } = lobiKur(3);
  for (let i = 0; i < 60; i++) e.gonder('p1', 'ready', { ready: i % 2 === 0 });
  assert.ok(conns.p1.hatalar().includes('RATE_LIMITED'));
});

test('ayrılan oyuncu lobiden silinir; atılan yeniden giremez', () => {
  const { e, conns, ids } = lobiKur(4);
  e.gonder('p1', 'leave');
  assert.equal(e.oda.players.some((p) => p.id === ids.p1), false);
  e.gonder('h', 'kick', { playerId: ids.p2 });
  assert.deepEqual(conns.p2.hatalar(), ['PLAYER_KICKED']);
  const geri = e.baglan('p2b');
  e.oda.mesaj('p2b', JSON.stringify({ v: 1, t: 'join', p: { nickname: 'Yeni', installId: 'ins-p2' } }));
  assert.deepEqual(geri.hatalar(), ['PLAYER_KICKED']);
});

test('ekran rolü: gizli alan almaz, oyuncu sayılmaz, ikinci ekran reddedilir', () => {
  const { e } = lobiKur(3);
  const d = e.katil('d1', 'Ekran', 'display');
  assert.equal(d.son('welcome')!.p.snapshot.private, null);
  assert.equal(e.oda.oyuncular().length, 3);
  const d2 = e.katil('d2', 'Ekran2', 'display');
  assert.deepEqual(d2.hatalar(), ['ROOM_FULL']);
});

test('oda kurma: geçersiz oyun ve takma ad', async () => {
  const { Oda } = await import('../src/core/room.ts');
  const { ICERIK, Zaman } = await import('./yardimci.ts');
  const { tohumluRand } = await import('../src/core/rng.ts');
  const dep = { now: new Zaman().now, rand: tohumluRand(1), icerik: ICERIK };
  assert.deepEqual(Oda.kur(dep, { code: 'A', game: '99', nickname: 'Ali', installId: 'x' }), { err: 'GAME_NOT_ONLINE' });
  assert.deepEqual(Oda.kur(dep, { code: 'A', game: '07', nickname: '', installId: 'x' }), { err: 'NICKNAME_REJECTED' });
});

test('serileştirme: odayı JSON\'dan geri yükle, sonra devam et', async () => {
  const { Oda } = await import('../src/core/room.ts');
  const { ICERIK } = await import('./yardimci.ts');
  const { tohumluRand } = await import('../src/core/rng.ts');
  const { e, conns } = lobiKur(3);
  e.gonder('h', 'start');
  const json = JSON.parse(JSON.stringify(e.oda.toJSON()));
  const oda2 = Oda.geriYukle({ now: e.zaman.now, rand: tohumluRand(9), icerik: ICERIK }, json);
  assert.equal(oda2.phase, 'SORU');
  const c = new (conns.h.constructor as any)();
  oda2.baglantiAc('x', c);
  oda2.mesaj('x', JSON.stringify({ v: 1, t: 'resume', p: { resumeToken: e.hostToken } }));
  assert.equal(c.son('welcome').p.snapshot.phase, 'SORU');
  assert.equal(c.son('welcome').p.snapshot.public.question.qId, e.oda.toJSON().game && (e.oda.toJSON().game as any).kuyruk[0].id);
});
