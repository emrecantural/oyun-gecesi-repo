import { Oda, type Baglanti } from '../src/core/room.ts';
import { tohumluRand } from '../src/core/rng.ts';
import type { Icerik } from '../src/games/types.ts';

export class SahteBaglanti implements Baglanti {
  gelen: { t: string; seq: number; now: number; p: any }[] = [];
  kapandi: { code: number; reason: string } | null = null;
  send(raw: string): void {
    this.gelen.push(JSON.parse(raw));
  }
  close(code: number, reason: string): void {
    this.kapandi = { code, reason };
  }
  son(t: string) {
    for (let i = this.gelen.length - 1; i >= 0; i--) if (this.gelen[i].t === t) return this.gelen[i];
    return undefined;
  }
  hepsi(t: string) {
    return this.gelen.filter((m) => m.t === t);
  }
  hatalar(): string[] {
    return this.hepsi('error').map((e) => e.p.code);
  }
}

export const ICERIK: Icerik = {
  soru07: Array.from({ length: 40 }, (_, i) => ({
    id: `07-S-${i}`,
    metin: `Soru ${i}`,
    kategori: i % 8 === 0 ? 'cesur' : i % 3 === 0 ? 'yilbasi' : 'gunluk',
  })),
};

export class Zaman {
  t = 1_000_000;
  now = () => this.t;
  ilerle(ms: number) {
    this.t += ms;
  }
}

export interface Ortam {
  oda: Oda;
  zaman: Zaman;
  hostToken: string;
  baglan(key: string): SahteBaglanti;
  gonder(key: string, t: string, p?: object, id?: string): void;
  katil(key: string, ad: string, rol?: string): SahteBaglanti;
  tikla(): void;
  ilerle(ms: number): void;
}

let sayac = 0;
export function ortamKur(oyun = '07', ayarlar: Record<string, unknown> = {}, tohum = 7): Ortam {
  const zaman = new Zaman();
  const rand = tohumluRand(tohum);
  const dep = { now: zaman.now, rand, icerik: ICERIK };
  const r = Oda.kur(dep, { code: 'TEST42', game: oyun, nickname: 'Host', installId: 'ins-host', settings: ayarlar });
  if ('err' in r) throw new Error(r.err);
  const conns = new Map<string, SahteBaglanti>();
  const env: Ortam = {
    oda: r.oda,
    zaman,
    hostToken: r.joinToken,
    baglan(key) {
      const c = new SahteBaglanti();
      conns.set(key, c);
      r.oda.baglantiAc(key, c);
      return c;
    },
    gonder(key, t, p = {}, id) {
      r.oda.mesaj(key, JSON.stringify({ v: 1, t, id: id ?? `m${++sayac}`, p }));
    },
    katil(key, ad, rol = 'player') {
      const c = env.baglan(key);
      r.oda.mesaj(key, JSON.stringify({ v: 1, t: 'join', p: { nickname: ad, role: rol, installId: 'ins-' + key } }));
      return c;
    },
    tikla() {
      r.oda.tik();
    },
    ilerle(ms) {
      zaman.ilerle(ms);
      r.oda.tik();
    },
  };
  return env;
}

/** Host + (n-1) oyuncu bağlı lobi. Anahtarlar: h, p1, p2 … */
export function lobiKur(n: number, oyun = '07', ayarlar: Record<string, unknown> = {}, tohum = 7) {
  const e = ortamKur(oyun, ayarlar, tohum);
  const conns: Record<string, SahteBaglanti> = {};
  const hc = e.baglan('h');
  e.oda.mesaj('h', JSON.stringify({ v: 1, t: 'join', p: { resumeToken: e.hostToken, installId: 'ins-host' } }));
  conns.h = hc;
  const ids: Record<string, string> = { h: hc.son('welcome')!.p.playerId };
  for (let i = 1; i < n; i++) {
    const k = 'p' + i;
    conns[k] = e.katil(k, 'Oyuncu' + i);
    ids[k] = conns[k].son('welcome')!.p.playerId;
  }
  return { e, conns, ids };
}
