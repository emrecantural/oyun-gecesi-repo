import { karistir, type Rand } from '../core/rng.ts';
import {
  TAMAM,
  hata,
  type Ayarlar,
  type Oyun,
  type OyunBagimliliklari,
  type OyunBaglami,
  type OyunTanimi,
  type Player,
  type Sonuc,
} from './types.ts';

export type OdulTuru = 'cinko1' | 'cinko2' | 'tombala';
export type Kart = number[][]; // 3 satır × 9 sütun; 0 = boş

const KART_DAGIT_MS = 3000;
const KONTROL_MS = 1500;
const ODUL_MS = 4000;
const TURLER: readonly OdulTuru[] = ['cinko1', 'cinko2', 'tombala'];
const VARSAYILAN_AD: Record<OdulTuru, string> = { cinko1: '1. Çinko', cinko2: '2. Çinko', tombala: 'Tombala' };

export interface Odul {
  name: string;
  tur: OdulTuru;
}

/** Kurallı rastgele kart: 3×9, satırda 5 sayı, sütunda 1–3 sayı, sütun içi artan, toplam 15. */
export function kartUret(rand: Rand): Kart {
  for (;;) {
    // Sütun sayıları: hepsi 1, kalan 6 fazlalık sütunlara en çok +2.
    const adet = Array(9).fill(1);
    let kalan = 6;
    while (kalan > 0) {
      const j = Math.floor(rand() * 9);
      if (adet[j] < 3) {
        adet[j]++;
        kalan--;
      }
    }
    const kart: Kart = [Array(9).fill(0), Array(9).fill(0), Array(9).fill(0)];
    const kapasite = [5, 5, 5];
    const sutunSirasi = karistir([...Array(9).keys()], rand).sort((a, b) => adet[b] - adet[a]);
    let basarili = true;
    for (const j of sutunSirasi) {
      // En çok kalan kapasiteli satırlar (eşitlikte rastgele).
      const satirlar = karistir([0, 1, 2], rand).sort((a, b) => kapasite[b] - kapasite[a]).slice(0, adet[j]);
      if (satirlar.some((r) => kapasite[r] <= 0)) {
        basarili = false;
        break;
      }
      const lo = j === 0 ? 1 : j * 10;
      const hi = j === 8 ? 90 : j * 10 + 9;
      const havuz: number[] = [];
      for (let n = lo; n <= hi; n++) havuz.push(n);
      const sayilar = karistir(havuz, rand).slice(0, adet[j]).sort((a, b) => a - b);
      satirlar.sort((a, b) => a - b);
      satirlar.forEach((r, i) => {
        kart[r][j] = sayilar[i];
        kapasite[r]--;
      });
    }
    if (basarili && kapasite.every((k) => k === 0)) return kart;
  }
}

export function satirTamamSayisi(kart: Kart, cekilen: ReadonlySet<number>): number {
  return kart.filter((satir) => satir.filter((n) => n > 0).every((n) => cekilen.has(n))).length;
}

export function kartImza(kart: Kart): string {
  return kart.map((s) => s.join('.')).join('|');
}

interface BekleyenIddia {
  prizeIdx: number;
  playerId: string;
}

interface Durum {
  cantaBasi: number[]; // kalan torba (yalnız sunucu)
  cekilen: number[];
  kartlar: Record<string, Kart[]>;
  hiz: number;
  duraklatildi: boolean;
  oduller: { name: string; tur: OdulTuru; kazananlar: string[]; cekimNo: number | null }[];
  bekleyen: BekleyenIddia[];
  kilit: Record<string, number>; // playerId → bu çekim sayısına kadar kilitli
  cinkoSayisi: Record<string, number>;
  sonOdulCekim: { playerId: string; cekimNo: number }[];
  son: null | { yok: boolean; ozet: unknown };
}

export class Tombala implements Oyun {
  readonly gizliEylemler: readonly string[] = [];
  private s: Durum;
  private dep: OyunBagimliliklari;

  constructor(s: Durum, dep: OyunBagimliliklari) {
    this.s = s;
    this.dep = dep;
  }

  static yeni(ayar: Ayarlar, dep: OyunBagimliliklari): Tombala {
    const oduller = (ayar.oduller as Odul[]).map((o) => ({ name: o.name, tur: o.tur, kazananlar: [] as string[], cekimNo: null as number | null }));
    return new Tombala(
      {
        cantaBasi: [], cekilen: [], kartlar: {}, hiz: Number(ayar.hiz), duraklatildi: false, oduller,
        bekleyen: [], kilit: {}, cinkoSayisi: {}, sonOdulCekim: [], son: null,
      },
      dep,
    );
  }

  toJSON() {
    return this.s;
  }

  private kartDagit(ctx: OyunBaglami, o: Player): void {
    const adet = Number(ctx.ayarlar.kartSayisi);
    const mevcutImzalar = new Set(Object.values(this.s.kartlar).flat().map(kartImza));
    const kartlar: Kart[] = [];
    while (kartlar.length < adet) {
      const k = kartUret(this.dep.rand);
      const im = kartImza(k);
      if (mevcutImzalar.has(im)) continue;
      mevcutImzalar.add(im);
      kartlar.push(k);
    }
    this.s.kartlar[o.id] = kartlar;
    ctx.gonder(o.id, 'cards', { cards: kartlar });
  }

  basla(ctx: OyunBaglami): string | null {
    this.s.cantaBasi = karistir(Array.from({ length: 90 }, (_, i) => i + 1), this.dep.rand);
    this.s.hiz = Number(ctx.ayarlar.hiz);
    for (const o of ctx.oyuncular()) this.kartDagit(ctx, o);
    ctx.setFaz('KART_DAGIT', ctx.now() + KART_DAGIT_MS);
    return null;
  }

  private cekimSuresiAyarla(ctx: OyunBaglami): void {
    ctx.setFaz('CEKIM', this.s.hiz > 0 && !this.s.duraklatildi ? ctx.now() + this.s.hiz * 1000 : null);
  }

  private cek(ctx: OyunBaglami): void {
    const n = this.s.cantaBasi.shift();
    if (n === undefined) {
      this.bitir(ctx, true);
      return;
    }
    this.s.cekilen.push(n);
    ctx.yayin('draw', { n, idx: this.s.cekilen.length, at: ctx.now() });
    this.cekimSuresiAyarla(ctx);
  }

  tik(ctx: OyunBaglami): void {
    switch (ctx.faz()) {
      case 'KART_DAGIT':
        this.cek(ctx);
        break;
      case 'CEKIM':
        if (!this.s.duraklatildi) this.cek(ctx);
        break;
      case 'CINKO_KONTROL':
        this.odulDagit(ctx);
        break;
      case 'ODUL':
        if (this.bittiMi()) this.bitir(ctx, false);
        else this.cekimSuresiAyarla(ctx);
        break;
      default:
        break;
    }
  }

  private bittiMi(): boolean {
    const tombalalar = this.s.oduller.filter((o) => o.tur === 'tombala');
    const hepsiDagildi = this.s.oduller.every((o) => o.kazananlar.length > 0);
    return hepsiDagildi || (tombalalar.length > 0 && tombalalar.every((o) => o.kazananlar.length > 0));
  }

  private odulDagit(ctx: OyunBaglami): void {
    const idxler = [...new Set(this.s.bekleyen.map((b) => b.prizeIdx))];
    const cekimNo = this.s.cekilen.length;
    for (const i of idxler) {
      const od = this.s.oduller[i];
      od.kazananlar = this.s.bekleyen.filter((b) => b.prizeIdx === i).map((b) => b.playerId);
      od.cekimNo = cekimNo;
      for (const w of od.kazananlar) {
        this.s.cinkoSayisi[w] = (this.s.cinkoSayisi[w] ?? 0) + 1;
        this.s.sonOdulCekim.push({ playerId: w, cekimNo });
      }
      ctx.yayin('prize', { index: i, name: od.name, tur: od.tur, winners: od.kazananlar, shared: ctx.ayarlar.beraberlik === 'paylas' });
    }
    this.s.bekleyen = [];
    ctx.setFaz('ODUL', ctx.now() + ODUL_MS);
  }

  private bitir(ctx: OyunBaglami, yok: boolean): void {
    const tombalaKazanildi = this.s.oduller.some((o) => o.tur === 'tombala' && o.kazananlar.length > 0);
    const nihai = yok && !tombalaKazanildi;
    const enCok = Math.max(0, ...Object.values(this.s.cinkoSayisi));
    const sanli = enCok > 0 ? Object.keys(this.s.cinkoSayisi).filter((k) => this.s.cinkoSayisi[k] === enCok) : [];
    const son = this.s.cekilen.length;
    const sonDakika = [...new Set(this.s.sonOdulCekim.filter((x) => x.cekimNo > son - 5).map((x) => x.playerId))];
    const ozet = {
      none: nihai,
      drawnCount: son,
      prizes: this.s.oduller.map((o) => ({ name: o.name, tur: o.tur, winners: o.kazananlar })),
      cinkoCounts: this.s.cinkoSayisi,
      badges: [
        ...(sanli.length ? [{ badge: 'lucky', playerIds: sanli }] : []),
        ...(sonDakika.length ? [{ badge: 'lastMinute', playerIds: sonDakika }] : []),
      ],
    };
    this.s.son = { yok: nihai, ozet };
    ctx.setFaz('FINAL', null);
    ctx.yayin('final', ozet);
  }

  mesaj(ctx: OyunBaglami, o: Player, t: string, p: Record<string, unknown>): Sonuc {
    switch (t) {
      case 'claim':
        return this.iddia(ctx, o, p);
      case 'setSpeed': {
        if (o.id !== ctx.hostId) return hata('NOT_HOST');
        const h = Number(p.speed);
        if (![0, 3, 5, 8].includes(h)) return hata('INVALID_MESSAGE');
        this.s.hiz = h;
        ctx.durumYayinla();
        return TAMAM;
      }
      case 'next': {
        if (o.id !== ctx.hostId) return hata('NOT_HOST');
        if (ctx.faz() !== 'CEKIM' || this.s.hiz !== 0) return hata('WRONG_PHASE');
        this.cek(ctx);
        return TAMAM;
      }
      case 'pause': {
        if (o.id !== ctx.hostId) return hata('NOT_HOST');
        if (ctx.faz() !== 'CEKIM') return hata('WRONG_PHASE');
        this.s.duraklatildi = true;
        ctx.setFaz('CEKIM', null);
        return TAMAM;
      }
      case 'unpause': {
        if (o.id !== ctx.hostId) return hata('NOT_HOST');
        if (ctx.faz() !== 'CEKIM' || !this.s.duraklatildi) return hata('WRONG_PHASE');
        this.s.duraklatildi = false;
        this.cekimSuresiAyarla(ctx);
        return TAMAM;
      }
      default:
        return hata('INVALID_MESSAGE');
    }
  }

  private iddia(ctx: OyunBaglami, o: Player, p: Record<string, unknown>): Sonuc {
    const faz = ctx.faz();
    if (faz !== 'CEKIM' && faz !== 'CINKO_KONTROL') return hata('WRONG_PHASE');
    const tur = p.type as OdulTuru;
    const kartIdx = Number(p.cardIdx);
    const kartlar = this.s.kartlar[o.id];
    if (!TURLER.includes(tur) || !kartlar || !Number.isInteger(kartIdx) || kartIdx < 0 || kartIdx >= kartlar.length) {
      return hata('INVALID_MESSAGE');
    }
    const cekimNo = this.s.cekilen.length;
    if (cekimNo < (this.s.kilit[o.id] ?? 0)) return hata('CLAIM_LOCKED');
    const gerekli = tur === 'cinko1' ? 1 : tur === 'cinko2' ? 2 : 3;
    const tamam = satirTamamSayisi(kartlar[kartIdx], new Set(this.s.cekilen));
    if (tamam < gerekli) {
      const ceza = Number(ctx.ayarlar.ceza);
      this.s.kilit[o.id] = cekimNo + ceza;
      ctx.gonder(o.id, 'claimResult', { ok: false, type: tur, reason: 'CLAIM_INVALID', lockUntilIdx: cekimNo + ceza });
      return TAMAM;
    }
    const bekleyenIdx = this.s.bekleyen.find((b) => this.s.oduller[b.prizeIdx].tur === tur)?.prizeIdx;
    const hedef = bekleyenIdx ?? this.s.oduller.findIndex((od) => od.tur === tur && od.kazananlar.length === 0);
    if (hedef < 0) {
      ctx.gonder(o.id, 'claimResult', { ok: false, type: tur, reason: 'NO_PRIZE' });
      return TAMAM;
    }
    if (this.s.bekleyen.some((b) => b.prizeIdx === hedef && b.playerId === o.id)) return TAMAM;
    this.s.bekleyen.push({ prizeIdx: hedef, playerId: o.id });
    ctx.gonder(o.id, 'claimResult', { ok: true, type: tur, prizeIdx: hedef });
    if (faz === 'CEKIM') ctx.setFaz('CINKO_KONTROL', ctx.now() + KONTROL_MS);
    return TAMAM;
  }

  oyuncuDegisti(ctx: OyunBaglami, olay: 'join' | 'leave' | 'disconnect' | 'reconnect', o: Player): void {
    if (olay === 'join' && ctx.faz() !== 'LOBBY' && ctx.faz() !== 'FINAL' && !this.s.kartlar[o.id]) {
      this.kartDagit(ctx, o);
    }
  }

  herkeseAcik(ctx: OyunBaglami): unknown {
    return {
      settings: ctx.ayarlar,
      drawn: this.s.cekilen,
      current: this.s.cekilen.length ? this.s.cekilen[this.s.cekilen.length - 1] : null,
      idx: this.s.cekilen.length,
      speed: this.s.hiz,
      paused: this.s.duraklatildi,
      prizes: this.s.oduller.map((o) => ({ name: o.name, tur: o.tur, winners: o.kazananlar })),
      playerCount: ctx.oyuncular().length,
      final: ctx.faz() === 'FINAL' ? this.s.son?.ozet ?? null : null,
    };
  }

  ozel(ctx: OyunBaglami, playerId: string): unknown {
    if (ctx.faz() === 'LOBBY') return null;
    return { kind: 'cards', cards: this.s.kartlar[playerId] ?? [], lockUntilIdx: this.s.kilit[playerId] ?? 0 };
  }
}

export const tombalaTanimi: OyunTanimi = {
  id: '01',
  minOyuncu: 2,
  maxOyuncu: 30,
  gecKatilim: 'acik',
  varsayilanAyarlar: () => ({
    kartSayisi: 1,
    hiz: 5,
    otoIsaret: true,
    sesliOkuma: true,
    gecKatilim: true,
    ceza: 3,
    beraberlik: 'ikisi',
    oduller: TURLER.map((tur) => ({ name: VARSAYILAN_AD[tur], tur })),
  }),
  ayarlariDogrula(ham, mevcut): Ayarlar | null {
    const a: Ayarlar = { ...mevcut };
    for (const [k, v] of Object.entries(ham)) {
      switch (k) {
        case 'kartSayisi':
          if (![1, 2, 3].includes(v as number)) return null;
          a.kartSayisi = v;
          break;
        case 'hiz':
          if (![0, 3, 5, 8].includes(v as number)) return null;
          a.hiz = v;
          break;
        case 'ceza':
          if (![0, 3].includes(v as number)) return null;
          a.ceza = v;
          break;
        case 'beraberlik':
          if (v !== 'ikisi' && v !== 'paylas') return null;
          a.beraberlik = v;
          break;
        case 'otoIsaret':
        case 'sesliOkuma':
        case 'gecKatilim':
          if (typeof v !== 'boolean') return null;
          a[k] = v;
          break;
        case 'oduller': {
          if (!Array.isArray(v) || v.length < 1 || v.length > 6) return null;
          const liste: Odul[] = [];
          for (const x of v) {
            if (typeof x !== 'object' || x === null) return null;
            const tur = (x as { tur?: unknown }).tur;
            if (!TURLER.includes(tur as OdulTuru)) return null;
            const ad = typeof (x as { name?: unknown }).name === 'string' ? (x as { name: string }).name.trim() : '';
            if (ad.length > 24) return null;
            liste.push({ name: ad || VARSAYILAN_AD[tur as OdulTuru], tur: tur as OdulTuru });
          }
          a.oduller = liste;
          break;
        }
        default:
          return null;
      }
    }
    return a;
  },
  olustur: (ayar, dep) => Tombala.yeni(ayar, dep),
  geriYukle: (json, dep) => new Tombala(json as Durum, dep),
};
