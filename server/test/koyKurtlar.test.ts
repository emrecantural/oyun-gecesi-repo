import { test } from 'node:test';
import assert from 'node:assert/strict';
import { lobiKur } from './yardimci.ts';

type Lobi = ReturnType<typeof lobiKur>;
const motor = (l: Lobi) => (l.e.oda.toJSON().game as any).motor;
const durum = (l: Lobi) => l.e.oda.toJSON().game as any;
const anahtar = (l: Lobi, pid: string) => Object.entries(l.ids).find(([, v]) => v === pid)![0];

function basla(n: number, ayar: Record<string, unknown> = {}, roller?: string[]): Lobi {
  const l = lobiKur(n, '03', ayar);
  l.e.gonder('h', 'start');
  if (roller) {
    const m = motor(l);
    const ids = m.oyuncular as string[];
    ids.forEach((id, i) => (m.roller[id] = roller[i]));
    m.ask = {};
    const asiklar = ids.filter((id) => m.roller[id] === 'asik');
    if (asiklar.length === 2) {
      m.ask[asiklar[0]] = asiklar[1];
      m.ask[asiklar[1]] = asiklar[0];
    }
  }
  return l;
}
const ile = (l: Lobi, rol: string, sira = 0): string =>
  Object.entries(motor(l).roller as Record<string, string>).filter(([, r]) => r === rol).map(([id]) => id)[sira];

/** Faz süresi kadar ilerler. */
function fazBitir(l: Lobi) {
  const b = l.e.oda.endsAt;
  assert.ok(b !== null, 'faz süreli olmalı: ' + l.e.oda.phase);
  l.e.ilerle(b! - l.e.zaman.t + 1);
}
function geceyeKadar(l: Lobi) {
  fazBitir(l); // ROL_DAGIT
  if (l.e.oda.phase === 'GECE_ASKLAR') fazBitir(l);
  assert.equal(l.e.oda.phase, 'GECE_KAHIN');
}
const eylem = (l: Lobi, pid: string, kind: string, target?: string) =>
  l.e.gonder(anahtar(l, pid), 'nightAction', { kind, target });

const ROLLER6 = ['kurt', 'kurt', 'kahin', 'doktor', 'koylu', 'koylu'];

test('6 oyuncu: roller paketle eşleşir, kurda müttefik bildirilir, ROL_DAGIT 8 sn', () => {
  const l = lobiKur(6, '03');
  l.e.gonder('h', 'start');
  assert.equal(l.e.oda.phase, 'ROL_DAGIT');
  const roller = Object.values(motor(l).roller) as string[];
  assert.equal(roller.filter((r) => r === 'kurt').length, 2);
  assert.equal(roller.filter((r) => r === 'kahin').length, 1);
  const kurtId = ile(l, 'kurt');
  const msg = l.conns[anahtar(l, kurtId)].hepsi('private').find((m) => m.p.kind === 'roleAssigned')!;
  assert.equal(msg.p.role, 'kurt');
  assert.equal(msg.p.allies.length, 1);
  const koyluId = ile(l, 'koylu');
  const km = l.conns[anahtar(l, koyluId)].hepsi('private').find((m) => m.p.kind === 'roleAssigned')!;
  assert.deepEqual(km.p.allies, []);
});

test('rol bilgisi başka sokete sızmaz', () => {
  const l = lobiKur(6, '03');
  l.e.gonder('h', 'start');
  for (const [k, c] of Object.entries(l.conns)) {
    const kendi = l.ids[k];
    const rol = motor(l).roller[kendi];
    for (const m of c.gelen) {
      if (m.t === 'private') continue;
      const s = JSON.stringify(m.p);
      for (const baskasi of Object.keys(motor(l).roller)) {
        if (baskasi === kendi) continue;
        assert.equal(s.includes(`"roleAssigned"`), false);
      }
    }
    void rol;
  }
  // roller yayında yok
  const pub = JSON.stringify(l.conns.p1.son('state')!.p);
  assert.equal(pub.includes('"kurt"'), false);
});

test('en az 6 oyuncu; rol paketi uyuşmazlığı start\'ı reddeder; setRolePack yalnız host', () => {
  const l5 = lobiKur(5, '03');
  l5.e.gonder('h', 'start');
  assert.deepEqual(l5.conns.h.hatalar(), ['MIN_PLAYERS']);
  const l = lobiKur(6, '03');
  l.e.gonder('p1', 'setRolePack', { pack: { kurt: 1, koylu: 5 } });
  assert.deepEqual(l.conns.p1.hatalar(), ['NOT_HOST']);
  l.e.gonder('h', 'setRolePack', { pack: { kurt: 1, koylu: 4 } });
  l.e.gonder('h', 'start');
  assert.deepEqual(l.conns.h.hatalar(), ['ROLEPACK_MISMATCH']);
  l.e.gonder('h', 'setRolePack', { pack: { kurt: 1, kahin: 1, koylu: 4 } });
  l.e.gonder('h', 'start');
  assert.equal(l.e.oda.phase, 'ROL_DAGIT');
  assert.equal(Object.values(motor(l).roller).filter((r) => r === 'kurt').length, 1);
});

test('geç katılım yok', () => {
  const l = basla(6);
  assert.deepEqual(l.e.katil('g', 'Gec').hatalar(), ['LATE_JOIN_CLOSED']);
});

test('gece: dört faz atlanmaz; herkes her fazda aynı şekilde istem alır', () => {
  const l = basla(6, { geceSn: 20 }, ROLLER6);
  geceyeKadar(l);
  const fazlar: string[] = [];
  for (let i = 0; i < 4; i++) {
    fazlar.push(l.e.oda.phase);
    const sekiller = new Set<string>();
    for (const [k, c] of Object.entries(l.conns)) {
      const ist = c.hepsi('private').filter((m) => m.p.kind === 'nightPrompt').pop()!;
      sekiller.add(Object.keys(ist.p).sort().join(','));
      assert.equal(ist.p.targets.length, 5);
      void k;
    }
    assert.equal(sekiller.size, 1);
    assert.equal(l.e.oda.endsAt, l.e.zaman.t + 20_000);
    fazBitir(l);
  }
  assert.deepEqual(fazlar, ['GECE_KAHIN', 'GECE_KURT', 'GECE_DOKTOR', 'GECE_CADI']);
  assert.equal(l.e.oda.phase, 'SAFAK');
});

test('kâhin: sonucu yalnız kâhine gider, sorgu kilitlenir, resume sonucu geri getirir', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  const kahin = ile(l, 'kahin');
  const kurt = ile(l, 'kurt');
  const koylu = ile(l, 'koylu');
  eylem(l, kahin, 'seer', kurt);
  const sr = l.conns[anahtar(l, kahin)].son('private')!;
  const sonuc = l.conns[anahtar(l, kahin)].hepsi('private').find((m) => m.p.kind === 'seerResult')!;
  assert.deepEqual([sonuc.p.targetId, sonuc.p.isWolf], [kurt, true]);
  void sr;
  // ikinci sorgu yok sayılır (ack gelir, yeni sonuç gelmez)
  eylem(l, kahin, 'seer', koylu);
  assert.equal(l.conns[anahtar(l, kahin)].hepsi('private').filter((m) => m.p.kind === 'seerResult').length, 1);
  assert.equal(l.conns[anahtar(l, kahin)].hatalar().length, 0);
  // başkaları görmez
  for (const [k, c] of Object.entries(l.conns)) {
    if (k === anahtar(l, kahin)) continue;
    assert.equal(c.hepsi('private').some((m) => m.p.kind === 'seerResult'), false);
  }
  // resume: kilitli eylem ve sonuç snapshot'ta
  const token = l.conns[anahtar(l, kahin)].son('welcome')!.p.resumeToken;
  const yeni = l.e.baglan('kahin2');
  l.e.oda.mesaj('kahin2', JSON.stringify({ v: 1, t: 'resume', p: { resumeToken: token } }));
  const priv = yeni.son('welcome')!.p.snapshot.private;
  assert.equal(priv.role, 'kahin');
  assert.deepEqual(priv.myAction, [{ kind: 'seer', target: kurt }]);
  assert.equal(priv.nightPrompt.myAction.length, 1);
  assert.deepEqual(priv.seerResults.map((r: any) => r.targetId), [kurt]);
});

test('sahte ack: rolü olmayan ve gerçek rol aynı ack baytlarını alır; hata kodu yok', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  const kahin = ile(l, 'kahin');
  const koylu = ile(l, 'koylu');
  const hedef = ile(l, 'kurt');
  l.e.gonder(anahtar(l, kahin), 'nightAction', { kind: 'seer', target: hedef }, 'x-gercek');
  l.e.gonder(anahtar(l, koylu), 'nightAction', { kind: 'seer', target: hedef }, 'x-sahte');
  l.e.gonder(anahtar(l, koylu), 'nightAction', { kind: 'protect', target: hedef }, 'x-sahte2');
  l.e.gonder(anahtar(l, koylu), 'nightAction', { kind: 'bilinmeyen' }, 'x-sahte3');
  const ack = (k: string, id: string) => {
    const m = l.conns[k].hepsi('ack').find((a) => a.p.id === id)!;
    return JSON.stringify({ t: m.t, keys: Object.keys(m.p), len: JSON.stringify(m.p).length - id.length });
  };
  const g = ack(anahtar(l, kahin), 'x-gercek');
  assert.equal(ack(anahtar(l, koylu), 'x-sahte'), g);
  assert.equal(ack(anahtar(l, koylu), 'x-sahte2'), g);
  assert.equal(ack(anahtar(l, koylu), 'x-sahte3'), g);
  assert.equal(l.conns[anahtar(l, koylu)].hatalar().length, 0);
  assert.equal(l.conns[anahtar(l, koylu)].hepsi('private').some((m) => m.p.kind === 'seerResult'), false);
});

test('yanlış fazdaki gerçek eylem yok sayılır (kurt oyu kâhin fazında)', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  const kurt = ile(l, 'kurt');
  eylem(l, kurt, 'wolfVote', ile(l, 'koylu'));
  assert.deepEqual(motor(l).kurtOylari, {});
});

test('kurt hedefi + doktor koruması: kimse ölmez; sessiz sabah', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  const koylu = ile(l, 'koylu');
  fazBitir(l); // KAHIN → KURT
  eylem(l, ile(l, 'kurt', 0), 'wolfVote', koylu);
  eylem(l, ile(l, 'kurt', 1), 'wolfVote', koylu);
  const tahta = l.conns[anahtar(l, ile(l, 'kurt', 0))].hepsi('private').filter((m) => m.p.kind === 'wolfBoard').pop()!;
  assert.equal(Object.keys(tahta.p.votes).length, 2);
  fazBitir(l); // → DOKTOR
  eylem(l, ile(l, 'doktor'), 'protect', koylu);
  fazBitir(l); // → CADI
  fazBitir(l); // → SAFAK
  assert.equal(l.e.oda.phase, 'SAFAK');
  const dawn = l.conns.h.son('dawn')!.p;
  assert.deepEqual(dawn.deaths, []);
  assert.equal(dawn.text.key, 'silent');
});

test('kurt hedefi korunmazsa ölür; rol ayara göre açılır; tartışmaya geçer', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  const koylu = ile(l, 'koylu');
  fazBitir(l);
  eylem(l, ile(l, 'kurt', 0), 'wolfVote', koylu);
  fazBitir(l); fazBitir(l); fazBitir(l);
  const dawn = l.conns.h.son('dawn')!.p;
  assert.deepEqual(dawn.deaths.map((d: any) => [d.id, d.roleShown]), [[koylu, 'koylu']]);
  assert.equal(dawn.text.key, 'death');
  fazBitir(l);
  assert.equal(l.e.oda.phase, 'TARTISMA');
});

test('rolAc=hayir: ölenin rolü gösterilmez', () => {
  const l = basla(6, { rolAc: 'hayir' }, ROLLER6);
  geceyeKadar(l);
  fazBitir(l);
  eylem(l, ile(l, 'kurt', 0), 'wolfVote', ile(l, 'koylu'));
  fazBitir(l); fazBitir(l); fazBitir(l);
  assert.equal(l.conns.h.son('dawn')!.p.deaths[0].roleShown, null);
});

test('doktor aynı kişiyi art arda koruyamaz: yalnız kendisine actionRejected', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  const koylu = ile(l, 'koylu');
  const dok = ile(l, 'doktor');
  fazBitir(l); fazBitir(l);
  eylem(l, dok, 'protect', koylu);
  fazBitir(l); fazBitir(l); fazBitir(l); // SAFAK, TARTISMA…
  assert.equal(l.e.oda.phase, 'TARTISMA');
  fazBitir(l); // OYLAMA
  fazBitir(l); // sonuç
  fazBitir(l); // yeni gece
  assert.equal(l.e.oda.phase, 'GECE_KAHIN');
  fazBitir(l); fazBitir(l);
  eylem(l, dok, 'protect', koylu);
  const red = l.conns[anahtar(l, dok)].hepsi('private').find((m) => m.p.kind === 'actionRejected')!;
  assert.equal(red.p.code, 'DOCTOR_REPEAT');
  assert.equal(l.conns[anahtar(l, dok)].hatalar().length, 0);
});

const ROLLER12 = ['kurt', 'kurt', 'kurt', 'kahin', 'doktor', 'cadi', 'avci', 'koylu', 'koylu', 'koylu', 'koylu', 'koylu'];

test('cadı: iyileştirme ölümü geri alır, zehir öldürür, iksirler bir kez', () => {
  const l = basla(12, {}, ROLLER12);
  geceyeKadar(l);
  const k1 = ile(l, 'koylu', 0), k2 = ile(l, 'koylu', 1), cadi = ile(l, 'cadi');
  fazBitir(l);
  for (let i = 0; i < 3; i++) eylem(l, ile(l, 'kurt', i), 'wolfVote', k1);
  fazBitir(l); fazBitir(l);
  assert.equal(l.e.oda.phase, 'GECE_CADI');
  const info = l.conns[anahtar(l, cadi)].hepsi('private').find((m) => m.p.kind === 'witchInfo')!;
  assert.equal(info.p.victimId, k1);
  assert.deepEqual(info.p.potions, { heal: true, poison: true });
  eylem(l, cadi, 'witchHeal');
  eylem(l, cadi, 'witchPoison', k2);
  fazBitir(l);
  const dawn = l.conns.h.son('dawn')!.p;
  assert.deepEqual(dawn.deaths.map((d: any) => d.id), [k2]);
  assert.equal(motor(l).iyilestirmeVar, false);
  assert.equal(motor(l).zehirVar, false);
});

test('cadı pas: iksirler harcanmaz; pastan sonra ek eylem yok sayılır', () => {
  const l = basla(12, {}, ROLLER12);
  geceyeKadar(l);
  fazBitir(l); fazBitir(l); fazBitir(l);
  const cadi = ile(l, 'cadi');
  eylem(l, cadi, 'witchSkip');
  eylem(l, cadi, 'witchPoison', ile(l, 'koylu'));
  assert.equal(motor(l).zehirVar, true);
});

function tartismadan(l: Lobi) {
  // gece tamamlanır, sessiz sabah ve tartışma
  fazBitir(l); fazBitir(l); fazBitir(l); fazBitir(l); // 4 gece fazı → SAFAK
  fazBitir(l); // SAFAK → TARTISMA
  assert.equal(l.e.oda.phase, 'TARTISMA');
}

test('gündüz: açık oylama eleme, sonuç herkese; kendine oy yasak; ölü oy veremez', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  tartismadan(l);
  fazBitir(l);
  assert.equal(l.e.oda.phase, 'OYLAMA');
  const kurt = ile(l, 'kurt', 0);
  l.e.gonder(anahtar(l, kurt), 'castVote', { target: kurt });
  assert.deepEqual(l.conns[anahtar(l, kurt)].hatalar(), ['SELF_TARGET_FORBIDDEN']);
  for (const id of l.e.oda.players.map((p) => p.id)) {
    if (id !== kurt) l.e.gonder(anahtar(l, id), 'castVote', { target: kurt });
  }
  fazBitir(l);
  assert.equal(l.e.oda.phase, 'OYLAMA_SONUC');
  const r = l.conns.p1.son('voteResult')!.p;
  assert.equal(r.eliminatedId, kurt);
  assert.equal(r.roleShown, 'kurt');
  assert.ok(r.votes, 'açık oylamada oylar görünür');
  fazBitir(l);
  assert.equal(l.e.oda.phase, 'GECE_KAHIN');
  // ölü oy veremez
  fazBitir(l); fazBitir(l); fazBitir(l); fazBitir(l); fazBitir(l); fazBitir(l);
  assert.equal(l.e.oda.phase, 'OYLAMA');
  l.e.gonder(anahtar(l, kurt), 'castVote', { target: ile(l, 'kurt', 1) });
  assert.deepEqual(l.conns[anahtar(l, kurt)].hatalar().slice(-1), ['NOT_ALIVE']);
});

test('gizli oylama: oy sahipleri sonuçta yok', () => {
  const l = basla(6, { oylama: 'gizli' }, ROLLER6);
  geceyeKadar(l);
  tartismadan(l);
  fazBitir(l);
  const hedef = ile(l, 'koylu');
  l.e.gonder('h', 'castVote', { target: hedef });
  fazBitir(l);
  const r = l.conns.p1.son('voteResult')!.p;
  assert.equal(r.votes, null);
  assert.equal(r.tally[hedef], 1);
});

test('eşit oy: kimse elenmez; yeniden oy ayarında eşit adaylar için bir tur daha', () => {
  const l = basla(6, { esit: 'yeniden' }, ROLLER6);
  geceyeKadar(l);
  tartismadan(l);
  fazBitir(l);
  const [a, b] = [ile(l, 'koylu', 0), ile(l, 'koylu', 1)];
  l.e.gonder('h', 'castVote', { target: a });
  l.e.gonder('p1', 'castVote', { target: b });
  fazBitir(l);
  assert.equal(l.conns.h.son('voteResult')!.p.revote, true);
  fazBitir(l);
  assert.equal(l.e.oda.phase, 'OYLAMA');
  // yalnız adaylar seçilebilir
  l.e.gonder('p2', 'castVote', { target: ile(l, 'kurt', 0) });
  assert.deepEqual(l.conns.p2.hatalar().slice(-1), ['INVALID_TARGET']);
  l.e.gonder('p2', 'castVote', { target: a });
  fazBitir(l);
  assert.equal(l.conns.h.son('voteResult')!.p.eliminatedId, a);
});

test('eşit oy ve ayar kimse: kimse elenmez, gece başlar', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  tartismadan(l);
  fazBitir(l);
  l.e.gonder('h', 'castVote', { target: ile(l, 'koylu', 0) });
  l.e.gonder('p1', 'castVote', { target: ile(l, 'koylu', 1) });
  fazBitir(l);
  const r = l.conns.h.son('voteResult')!.p;
  assert.equal(r.eliminatedId, null);
  assert.equal(r.tie, true);
  fazBitir(l);
  assert.equal(l.e.oda.phase, 'GECE_KAHIN');
});

test('avcı: gece öldürülürse son atış; vurulan ölür; süre dolarsa atış yok', () => {
  const l = basla(12, {}, ROLLER12);
  geceyeKadar(l);
  const avci = ile(l, 'avci');
  fazBitir(l);
  for (let i = 0; i < 3; i++) eylem(l, ile(l, 'kurt', i), 'wolfVote', avci);
  fazBitir(l); fazBitir(l); fazBitir(l);
  assert.equal(l.e.oda.phase, 'SAFAK');
  fazBitir(l);
  assert.equal(l.e.oda.phase, 'AVCI');
  assert.ok(l.conns[anahtar(l, avci)].hepsi('private').some((m) => m.p.kind === 'hunterPrompt'));
  // başkası vuramaz (sahte ack)
  l.e.gonder(anahtar(l, ile(l, 'koylu')), 'hunterShoot', { target: ile(l, 'kurt') });
  assert.equal(l.conns[anahtar(l, ile(l, 'koylu'))].hatalar().length, 0);
  assert.equal(l.e.oda.phase, 'AVCI');
  const hedef = ile(l, 'kurt', 0);
  l.e.gonder(anahtar(l, avci), 'hunterShoot', { target: hedef });
  assert.equal(l.e.oda.phase, 'TARTISMA');
  assert.deepEqual(l.conns.h.son('hunterShot')!.p.deaths.map((d: any) => d.id), [hedef]);
  assert.equal(motor(l).olu.includes(hedef), true);
});

test('âşık zinciri: eş de ölür (gece)', () => {
  const l = basla(10, {}, ['kurt', 'kurt', 'kahin', 'doktor', 'avci', 'asik', 'asik', 'koylu', 'koylu', 'koylu']);
  geceyeKadar(l);
  assert.equal(l.e.oda.phase, 'GECE_KAHIN');
  const [a1, a2] = [ile(l, 'asik', 0), ile(l, 'asik', 1)];
  assert.equal(motor(l).ask[a1], a2);
  fazBitir(l);
  eylem(l, ile(l, 'kurt', 0), 'wolfVote', a1);
  eylem(l, ile(l, 'kurt', 1), 'wolfVote', a1);
  fazBitir(l); fazBitir(l); fazBitir(l);
  assert.deepEqual(l.conns.h.son('dawn')!.p.deaths.map((d: any) => d.id).sort(), [a1, a2].sort());
});

test('âşık varsa 1. geceden önce GECE_ASKLAR fazı', () => {
  const l = basla(10, {}, ['kurt', 'kurt', 'kahin', 'doktor', 'avci', 'asik', 'asik', 'koylu', 'koylu', 'koylu']);
  fazBitir(l);
  assert.equal(l.e.oda.phase, 'GECE_ASKLAR');
  assert.ok(l.conns[anahtar(l, ile(l, 'asik', 0))].hepsi('private').some((m) => m.p.kind === 'lovers'));
});

test('kazanma: son kurt elenince köy; kurt sayısı eşitlenince kurtlar', () => {
  const l = basla(6, {}, ['kurt', 'koylu', 'koylu', 'koylu', 'kahin', 'doktor']);
  geceyeKadar(l);
  tartismadan(l);
  fazBitir(l);
  const kurt = ile(l, 'kurt');
  for (const id of l.e.oda.players.map((p) => p.id)) if (id !== kurt) l.e.gonder(anahtar(l, id), 'castVote', { target: kurt });
  fazBitir(l);
  fazBitir(l);
  assert.equal(l.e.oda.phase, 'FINAL');
  const f = l.conns.h.son('final')!.p;
  assert.equal(f.winner, 'koy');
  assert.equal(f.roles.length, 6);
  const l2 = basla(6, {}, ['kurt', 'kurt', 'kurt', 'koylu', 'kahin', 'doktor']);
  geceyeKadar(l2);
  fazBitir(l2);
  for (let i = 0; i < 3; i++) eylem(l2, ile(l2, 'kurt', i), 'wolfVote', ile(l2, 'koylu'));
  fazBitir(l2); fazBitir(l2); fazBitir(l2); fazBitir(l2);
  // 3 kurt, 2 köylü kaldı → kurtlar
  assert.equal(l2.e.oda.phase, 'FINAL');
  assert.equal(l2.conns.h.son('final')!.p.winner, 'kurtlar');
});

test('tepki: gizli fazlarda REACTION_DISABLED, şafakta açık', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  l.e.gonder('p1', 'reaction', { emoji: '🔥' });
  assert.deepEqual(l.conns.p1.hatalar(), ['REACTION_DISABLED']);
  fazBitir(l); fazBitir(l); fazBitir(l); fazBitir(l);
  assert.equal(l.e.oda.phase, 'SAFAK');
  l.e.gonder('p1', 'reaction', { emoji: '🔥' });
  assert.equal(l.conns.p2.hepsi('reaction').length, 1);
});

test('bağlı oyuncu 6 altına inince DURAKLA; devam kalan süreyle sürer', () => {
  const l = basla(6, {}, ROLLER6);
  geceyeKadar(l);
  l.e.ilerle(5000);
  l.e.oda.baglantiKapandi('p4');
  assert.equal(l.e.oda.phase, 'DURAKLA');
  l.e.ilerle(60_000);
  assert.equal(l.e.oda.phase, 'DURAKLA');
  l.e.gonder('h', 'continue');
  assert.equal(l.e.oda.phase, 'GECE_KAHIN');
  assert.ok(l.e.oda.endsAt! - l.e.zaman.t <= 20_000 && l.e.oda.endsAt! - l.e.zaman.t >= 1000);
});

test('rövanş: rol atamaları sıfırlanır', () => {
  const l = basla(6, {}, ['kurt', 'koylu', 'koylu', 'koylu', 'kahin', 'doktor']);
  geceyeKadar(l);
  tartismadan(l);
  fazBitir(l);
  const kurt = ile(l, 'kurt');
  for (const id of l.e.oda.players.map((p) => p.id)) if (id !== kurt) l.e.gonder(anahtar(l, id), 'castVote', { target: kurt });
  fazBitir(l); fazBitir(l);
  assert.equal(l.e.oda.phase, 'FINAL');
  l.e.gonder('h', 'rematch');
  assert.equal(l.e.oda.phase, 'LOBBY');
  assert.equal(durum(l).motor, null);
  l.e.gonder('h', 'start');
  assert.equal(l.e.oda.phase, 'ROL_DAGIT');
});

test('botlarla simülasyon: kilitlenme yok, her oyun sonlanır (20 oyun)', () => {
  let kurtGalibiyet = 0;
  let bitenler = 0;
  for (let oyun = 0; oyun < 20; oyun++) {
    const n = 6 + (oyun % 15);
    const l = lobiKur(n, '03', { geceSn: 20, tartismaSn: 60 }, 100 + oyun);
    l.e.gonder('h', 'start');
    let x = 77 + oyun;
    const rnd = () => ((x = (x * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
    for (let adim = 0; adim < 400 && l.e.oda.phase !== 'FINAL'; adim++) {
      const m = motor(l);
      const canli = (m.oyuncular as string[]).filter((id) => !m.olu.includes(id));
      const faz = l.e.oda.phase;
      for (const id of canli) {
        const k = anahtar(l, id);
        const rol = m.roller[id];
        const hedefler = canli.filter((y) => y !== id);
        const hedef = hedefler[Math.floor(rnd() * hedefler.length)];
        if (faz === 'GECE_KAHIN' && rol === 'kahin') eylem(l, id, 'seer', hedef);
        if (faz === 'GECE_KURT' && rol === 'kurt') eylem(l, id, 'wolfVote', hedefler.filter((y) => m.roller[y] !== 'kurt')[0] ?? hedef);
        if (faz === 'GECE_DOKTOR' && rol === 'doktor') eylem(l, id, 'protect', hedef);
        if (faz === 'GECE_CADI' && rol === 'cadi') eylem(l, id, rnd() < 0.5 ? 'witchSkip' : 'witchPoison', hedef);
        if (faz === 'OYLAMA') l.e.gonder(k, 'castVote', { target: rnd() < 0.8 ? hedef : null });
        if (faz === 'AVCI' && m.roller[id] === 'avci' && m.olu.includes(id) === true) void 0;
      }
      if (faz === 'AVCI') {
        const av = durum(l).avciBekleyen as string;
        const m2 = motor(l);
        const hedefler = (m2.oyuncular as string[]).filter((id) => !m2.olu.includes(id));
        l.e.gonder(anahtar(l, av), 'hunterShoot', { target: hedefler[0] });
      }
      if (l.e.oda.phase === 'FINAL') break;
      if (l.e.oda.endsAt !== null) l.e.ilerle(l.e.oda.endsAt - l.e.zaman.t + 1);
    }
    assert.equal(l.e.oda.phase, 'FINAL', `oyun ${oyun} (n=${n}) bitmedi: ${l.e.oda.phase}`);
    bitenler++;
    if (l.conns.h.son('final')!.p.winner === 'kurtlar') kurtGalibiyet++;
  }
  assert.equal(bitenler, 20);
  void kurtGalibiyet;
});
