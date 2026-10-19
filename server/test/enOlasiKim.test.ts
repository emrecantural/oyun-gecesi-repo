import { test } from 'node:test';
import assert from 'node:assert/strict';
import { lobiKur } from './yardimci.ts';

function basla(n: number, ayar: Record<string, unknown> = {}) {
  const l = lobiKur(n, '07', ayar);
  l.e.gonder('h', 'start');
  return l;
}
const qid = (l: ReturnType<typeof basla>) => l.conns.h.son('question')!.p.qId as string;

function oyFazinaGec(l: ReturnType<typeof basla>) {
  l.e.ilerle(2000);
}

test('akış: SORU 2 sn → OY → herkes oy verince ~1 sn sonra SONUC', () => {
  const l = basla(4);
  assert.equal(l.e.oda.phase, 'SORU');
  assert.equal(l.conns.p1.son('question')!.p.idx, 1);
  oyFazinaGec(l);
  assert.equal(l.e.oda.phase, 'OY');
  const q = qid(l);
  l.e.gonder('h', 'vote', { qId: q, target: l.ids.p1 });
  l.e.gonder('p1', 'vote', { qId: q, target: l.ids.p2 });
  l.e.gonder('p2', 'vote', { qId: q, target: l.ids.p1 });
  assert.equal(l.e.oda.phase, 'OY');
  l.e.gonder('p3', 'vote', { qId: q, target: l.ids.p1 });
  l.e.ilerle(1001);
  assert.equal(l.e.oda.phase, 'SONUC');
  const r = l.conns.h.son('result')!.p;
  assert.deepEqual(r.winners, [l.ids.p1]);
  assert.equal(r.counts[l.ids.p1], 3);
  assert.equal(r.noVotes, false);
});

test('kendine oy yasak: SELF_VOTE_FORBIDDEN, oy yazılmaz', () => {
  const l = basla(3);
  oyFazinaGec(l);
  l.e.gonder('p1', 'vote', { qId: qid(l), target: l.ids.p1 });
  assert.deepEqual(l.conns.p1.hatalar(), ['SELF_VOTE_FORBIDDEN']);
  assert.equal(l.conns.p1.son('myVote'), undefined);
});

test('kendine oy serbest ayarında kabul edilir', () => {
  const l = basla(3, { kendineOy: 'serbest' });
  oyFazinaGec(l);
  l.e.gonder('p1', 'vote', { qId: qid(l), target: l.ids.p1 });
  assert.equal(l.conns.p1.son('myVote')!.p.target, l.ids.p1);
});

test('eski soru ve yanlış faz reddedilir; geçersiz hedef reddedilir', () => {
  const l = basla(3);
  l.e.gonder('p1', 'vote', { qId: qid(l), target: l.ids.p2 });
  assert.deepEqual(l.conns.p1.hatalar(), ['WRONG_PHASE']);
  oyFazinaGec(l);
  l.e.gonder('p1', 'vote', { qId: 'eski', target: l.ids.p2 });
  l.e.gonder('p1', 'vote', { qId: qid(l), target: 'yok' });
  assert.deepEqual(l.conns.p1.hatalar(), ['WRONG_PHASE', 'STALE_QUESTION', 'INVALID_TARGET']);
});

test('gizlilik: başkasının oyu hiçbir mesajda yok; myVote yalnız sahibine', () => {
  const l = basla(4);
  oyFazinaGec(l);
  l.e.gonder('p1', 'vote', { qId: qid(l), target: l.ids.p2 });
  assert.ok(l.conns.p1.son('myVote'));
  for (const k of ['h', 'p2', 'p3']) assert.equal(l.conns[k].son('myVote'), undefined);
  const ilerleme = l.conns.p2.son('voteProgress')!.p;
  assert.deepEqual(Object.keys(ilerleme).sort(), ['total', 'votedCount']);
  // sonuç ve anlık görüntüde oy sahibi bilgisi yok
  l.e.ilerle(20_000);
  const s = JSON.stringify(l.conns.p2.gelen);
  assert.equal(s.includes(`"${l.ids.p1}":"${l.ids.p2}"`), false);
  const sonuc = l.conns.p2.son('result')!.p;
  assert.deepEqual(Object.keys(sonuc).sort(), ['counts', 'noVotes', 'qId', 'target', 'tie', 'winners']);
});

test('süre dolunca oy vermeyen sessiz sayılır; hiç oy yoksa noVotes ve tur ilerler', () => {
  const l = basla(3);
  oyFazinaGec(l);
  l.e.ilerle(15_000);
  assert.equal(l.e.oda.phase, 'SONUC');
  const r = l.conns.h.son('result')!.p;
  assert.equal(r.noVotes, true);
  assert.deepEqual(r.winners, []);
  l.e.ilerle(6000);
  assert.equal(l.e.oda.phase, 'SORU');
  assert.equal(l.conns.h.son('question')!.p.idx, 2);
});

test('eşitlik: hepsi kazanır, tie=true', () => {
  const l = basla(4);
  oyFazinaGec(l);
  const q = qid(l);
  l.e.gonder('h', 'vote', { qId: q, target: l.ids.p1 });
  l.e.gonder('p1', 'vote', { qId: q, target: l.ids.p2 });
  l.e.ilerle(15_000);
  const r = l.conns.h.son('result')!.p;
  assert.equal(r.tie, true);
  assert.deepEqual([...r.winners].sort(), [l.ids.p1, l.ids.p2].sort());
});

test('oy değiştirilebilir: son seçim geçerli', () => {
  const l = basla(4);
  oyFazinaGec(l);
  const q = qid(l);
  l.e.gonder('h', 'vote', { qId: q, target: l.ids.p1 });
  l.e.gonder('h', 'vote', { qId: q, target: l.ids.p2 });
  l.e.ilerle(15_000);
  const r = l.conns.h.son('result')!.p;
  assert.equal(r.counts[l.ids.p2], 1);
  assert.equal(r.counts[l.ids.p1], undefined);
});

test('tahmin modu: doğru tahmin +1, çoklu kazananda herhangi biri doğru', () => {
  const l = basla(4, { tahmin: true });
  l.e.ilerle(2000);
  assert.equal(l.e.oda.phase, 'TAHMIN');
  const q = qid(l);
  l.e.gonder('h', 'predict', { qId: q, target: l.ids.p1 });
  l.e.gonder('p1', 'predict', { qId: q, target: l.ids.p2 });
  l.e.gonder('p2', 'predict', { qId: q, target: l.ids.p3 });
  l.e.gonder('p3', 'predict', { qId: q, target: l.ids.p1 });
  l.e.ilerle(1001);
  assert.equal(l.e.oda.phase, 'OY');
  // eşitlik: p1 ve p2 kazanır
  l.e.gonder('h', 'vote', { qId: q, target: l.ids.p1 });
  l.e.gonder('p1', 'vote', { qId: q, target: l.ids.p2 });
  l.e.ilerle(15_000);
  const pr = l.conns.h.son('predictResult')!.p;
  assert.deepEqual([...pr.correctPlayerIds].sort(), [l.ids.h, l.ids.p1, l.ids.p3].sort());
  assert.equal(l.conns.h.son('private')?.p ?? undefined, undefined); // private yalnız snapshot'ta
  l.e.ilerle(6000);
  assert.equal(l.e.oda.phase, 'TAHMIN_SKOR');
  l.e.ilerle(2000);
  assert.equal(l.e.oda.phase, 'SORU');
});

test('3 oyuncu: kendine oy yasakken iki seçenek yeter; tur tıkanmaz', () => {
  const l = basla(3, { soruSayisi: 10 });
  oyFazinaGec(l);
  const q = qid(l);
  l.e.gonder('h', 'vote', { qId: q, target: l.ids.p1 });
  l.e.gonder('p1', 'vote', { qId: q, target: l.ids.h });
  l.e.gonder('p2', 'vote', { qId: q, target: l.ids.h });
  l.e.ilerle(1001);
  assert.equal(l.e.oda.phase, 'SONUC');
});

test('tam oyun: 10 soru, final rozetleri ve rövanş', () => {
  const l = basla(4, { soruSayisi: 10, kendineOy: 'serbest' });
  for (let i = 0; i < 10; i++) {
    oyFazinaGec(l);
    const q = qid(l);
    l.e.gonder('h', 'vote', { qId: q, target: l.ids.p1 });
    l.e.gonder('p1', 'vote', { qId: q, target: l.ids.p2 });
    l.e.gonder('p2', 'vote', { qId: q, target: l.ids.p1 });
    if (i < 9) l.e.gonder('p3', 'vote', { qId: q, target: l.ids.p1 });
    l.e.ilerle(16_000);
    l.e.ilerle(6000);
  }
  assert.equal(l.e.oda.phase, 'FINAL');
  const f = l.conns.h.son('final')!.p;
  const fav = f.badges.find((b: any) => b.badge === 'favorite');
  assert.deepEqual(fav.playerIds, [l.ids.p1]);
  const comert = f.badges.find((b: any) => b.badge === 'generous');
  assert.equal(comert.playerIds.includes(l.ids.h), true);
  assert.equal(comert.playerIds.includes(l.ids.p3), false);
  assert.equal(f.scoreboard, null);
  // rövanş yalnız host
  l.e.gonder('p1', 'rematch');
  assert.deepEqual(l.conns.p1.hatalar().slice(-1), ['NOT_HOST']);
  l.e.gonder('h', 'rematch');
  assert.equal(l.e.oda.phase, 'LOBBY');
  l.e.gonder('h', 'start');
  assert.equal(l.e.oda.phase, 'SORU');
});

test('3 üst üste aynı kazanan: sonraki soru olumlu kategoriden ve hedef mesajı', () => {
  const l = basla(4, { soruSayisi: 15, seviye: 'cesur' });
  const hedefler: (string | null)[] = [];
  for (let i = 0; i < 4; i++) {
    oyFazinaGec(l);
    const q = qid(l);
    l.e.gonder('h', 'vote', { qId: q, target: l.ids.p1 });
    l.e.gonder('p2', 'vote', { qId: q, target: l.ids.p1 });
    l.e.ilerle(16_000);
    hedefler.push(l.conns.h.son('result')!.p.target);
    l.e.ilerle(6000);
    if (i === 2) {
      const sonraki = l.conns.h.son('question')!.p.category;
      assert.ok(['gunluk', 'yilbasi'].includes(sonraki), sonraki);
    }
  }
  assert.deepEqual(hedefler.map((x) => x === null), [true, true, false, false]);
});

test('geç katılan seyirci sonraki soruda oyuncuya yükselir ve oy verebilir', () => {
  const l = basla(3);
  const s = l.e.katil('s', 'Gec', 'spectator');
  const sid = s.son('welcome')!.p.playerId;
  oyFazinaGec(l);
  l.e.gonder('s', 'vote', { qId: qid(l), target: l.ids.p1 });
  assert.deepEqual(s.hatalar(), ['NOT_PLAYER']);
  l.e.ilerle(15_000);
  l.e.ilerle(6000);
  assert.equal(l.e.oda.players.find((p) => p.id === sid)!.role, 'player');
  oyFazinaGec(l);
  l.e.gonder('s', 'vote', { qId: qid(l), target: l.ids.p1 });
  assert.equal(s.son('myVote')!.p.target, l.ids.p1);
});

test('bağlı oyuncu 3 altına inince DURAKLA; host devam ettirir veya bitirir', () => {
  const l = basla(3);
  oyFazinaGec(l);
  l.e.oda.baglantiKapandi('p2');
  assert.equal(l.e.oda.phase, 'DURAKLA');
  l.e.gonder('p1', 'continue');
  assert.deepEqual(l.conns.p1.hatalar().slice(-1), ['NOT_HOST']);
  l.e.gonder('h', 'finish');
  assert.equal(l.e.oda.phase, 'FINAL');
});

test('resume: oy kullanan oyuncu geri bağlanınca myVote snapshot\'ta gelir', () => {
  const l = basla(4);
  oyFazinaGec(l);
  const q = qid(l);
  l.e.gonder('p1', 'vote', { qId: q, target: l.ids.p2 });
  const token = l.conns.p1.son('welcome')!.p.resumeToken;
  const yeni = l.e.baglan('p1b');
  l.e.oda.mesaj('p1b', JSON.stringify({ v: 1, t: 'resume', p: { resumeToken: token } }));
  const snap = yeni.son('welcome')!.p.snapshot;
  assert.equal(snap.phase, 'OY');
  assert.equal(snap.private.myVote, l.ids.p2);
  assert.equal(snap.public.question.qId, q);
});

test('1000 adımlık rastgele simülasyon kilitlenmez', () => {
  const l = basla(6, { soruSayisi: 20 });
  let x = 12345;
  const rnd = () => ((x = (x * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
  const anahtarlar = ['h', 'p1', 'p2', 'p3', 'p4', 'p5'];
  for (let i = 0; i < 1000 && l.e.oda.phase !== 'FINAL'; i++) {
    const k = anahtarlar[Math.floor(rnd() * anahtarlar.length)];
    const hedef = l.ids[anahtarlar[Math.floor(rnd() * anahtarlar.length)]];
    l.e.gonder(k, rnd() < 0.5 ? 'vote' : 'predict', { qId: l.conns.h.son('question')!.p.qId, target: hedef });
    l.e.ilerle(Math.floor(rnd() * 8000));
  }
  assert.ok(l.e.oda.phase === 'FINAL' || l.e.oda.endsAt !== null || l.e.oda.phase === 'DURAKLA');
});

test('A14: ücretsiz kurucuda yalnız ücretsiz havuz, premium kurucuda tamamı', async () => {
  const { havuzSec } = await import('../src/games/enOlasiKim.ts');
  const icerik = {
    soru07: Array.from({ length: 30 }, (_, i) => ({ id: `q${i}`, metin: `s${i}`, kategori: 'gunluk', ucretsiz: i < 10 })),
  };
  assert.equal(havuzSec(icerik, 'gunluk', false).length, 10);
  assert.equal(havuzSec(icerik, 'gunluk', true).length, 30);
});

test('premiumHavuz setSettings ile değiştirilemez', () => {
  const l = lobiKur(3, '07');
  l.e.gonder('h', 'setSettings', { premiumHavuz: true });
  assert.deepEqual(l.conns.h.hatalar(), ['INVALID_MESSAGE']);
});
