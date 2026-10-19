import { karistir } from '../core/rng.ts';
import {
  TAMAM,
  hata,
  type Ayarlar,
  type Icerik,
  type Oyun,
  type OyunBagimliliklari,
  type OyunBaglami,
  type OyunTanimi,
  type Player,
  type Sonuc,
  type Soru07,
} from './types.ts';

const SORU_MS = 2000;
const SONUC_MS = 6000;
const TAHMIN_SKOR_MS = 2000;
const ERKEN_BITIS_MS = 1000;

interface Durum {
  kuyruk: Soru07[];
  toplam: number;
  idx: number;
  oylar: Record<string, string | null>;
  tahminler: Record<string, string | null>;
  puan: Record<string, number>;
  alinanOy: Record<string, number>;
  kendineOy: Record<string, number>;
  oyVerilenSoru: Record<string, number>;
  katilimSorusu: Record<string, number>;
  serilId: string | null;
  seriN: number;
  sonuc: null | { qId: string; counts: Record<string, number>; winners: string[]; tie: boolean; noVotes: boolean; target: string | null };
  tahminSonuc: null | { qId: string; correctPlayerIds: string[] };
  duraklat: null | { faz: string; kalanMs: number };
  final: null | { badges: { badge: string; playerIds: string[] }[]; scoreboard: { playerId: string; score: number }[] | null; stats: { questions: number } };
}

const OLUMLU = ['gunluk', 'yilbasi'];

/** Ücretsiz kurucu odasında yalnız ücretsiz havuz kullanılır (A14); premium kurucuda tamamı. */
export function havuzSec(icerik: Icerik, seviye: string, premium = true): Soru07[] {
  const tum = premium ? icerik.soru07 : icerik.soru07.filter((q) => q.ucretsiz !== false);
  if (seviye === 'yilbasi') {
    const yb = tum.filter((q) => q.kategori === 'yilbasi');
    return [...yb, ...tum.filter((q) => q.kategori === 'gunluk')];
  }
  if (seviye === 'cesur') return tum;
  return tum.filter((q) => q.kategori !== 'cesur');
}

export class EnOlasiKim implements Oyun {
  readonly gizliEylemler: readonly string[] = [];
  private s: Durum;
  private dep: OyunBagimliliklari;
  constructor(s: Durum, dep: OyunBagimliliklari) {
    this.s = s;
    this.dep = dep;
  }

  static yeni(dep: OyunBagimliliklari): EnOlasiKim {
    return new EnOlasiKim(
      {
        kuyruk: [], toplam: 0, idx: -1, oylar: {}, tahminler: {}, puan: {}, alinanOy: {}, kendineOy: {},
        oyVerilenSoru: {}, katilimSorusu: {}, serilId: null, seriN: 0, sonuc: null, tahminSonuc: null, duraklat: null, final: null,
      },
      dep,
    );
  }

  toJSON() {
    return this.s;
  }

  private soru(): Soru07 | undefined {
    return this.s.kuyruk[this.s.idx];
  }

  basla(ctx: OyunBaglami): string | null {
    const pool = havuzSec(this.dep.icerik, String(ctx.ayarlar.seviye), ctx.ayarlar.premiumHavuz === true);
    const adet = Math.min(Number(ctx.ayarlar.soruSayisi), pool.length);
    if (adet < 1) return 'NO_CONTENT';
    const rand = this.dep.rand;
    let secim: Soru07[];
    if (ctx.ayarlar.seviye === 'cesur') {
      const cesur = karistir(pool.filter((q) => q.kategori === 'cesur'), rand);
      const diger = karistir(pool.filter((q) => q.kategori !== 'cesur'), rand);
      const cesurAdet = Math.min(cesur.length, Math.max(4, Math.round(adet * 0.3)), adet);
      secim = karistir([...cesur.slice(0, cesurAdet), ...diger.slice(0, adet - cesurAdet)], rand);
    } else {
      secim = karistir(pool, rand).slice(0, adet);
    }
    // Kalan havuz, olumlu kategoriye kaydırma için kuyruğun sonuna eklenir.
    const kalan = karistir(pool.filter((q) => !secim.includes(q)), rand);
    this.s.kuyruk = [...secim, ...kalan];
    this.s.toplam = adet;
    this.s.idx = -1;
    for (const p of ctx.oyuncular()) this.s.katilimSorusu[p.id] = 0;
    this.sonrakiSoru(ctx);
    return null;
  }

  private uygunlar(ctx: OyunBaglami): Player[] {
    return ctx.oyuncular();
  }

  private bagliUygun(ctx: OyunBaglami): Player[] {
    return this.uygunlar(ctx).filter((p) => p.connected);
  }

  private sonrakiSoru(ctx: OyunBaglami): void {
    for (const sp of ctx.seyirciler()) {
      ctx.oyuncuYap(sp.id);
      this.s.katilimSorusu[sp.id] = this.s.idx + 1;
    }
    const sonraki = this.s.idx + 1;
    if (sonraki >= this.s.toplam) {
      this.bitir(ctx);
      return;
    }
    // 3 üst üste aynı kazanan: sıradaki soruyu olumlu kategoriye kaydır.
    if (this.s.seriN >= 3) {
      const j = this.s.kuyruk.findIndex((q, i) => i >= sonraki && OLUMLU.includes(q.kategori));
      if (j > sonraki) [this.s.kuyruk[sonraki], this.s.kuyruk[j]] = [this.s.kuyruk[j], this.s.kuyruk[sonraki]];
    }
    this.s.idx = sonraki;
    this.s.oylar = {};
    this.s.tahminler = {};
    this.s.sonuc = null;
    this.s.tahminSonuc = null;
    const q = this.soru()!;
    ctx.setFaz('SORU', ctx.now() + SORU_MS);
    ctx.yayin('question', {
      qId: q.id,
      text: q.metin,
      category: q.kategori,
      idx: this.s.idx + 1,
      total: this.s.toplam,
      endsAt: ctx.now() + SORU_MS,
    });
  }

  private oySuresiMs(ctx: OyunBaglami): number {
    return Number(ctx.ayarlar.oySuresi) * 1000;
  }

  private oyFazinaGec(ctx: OyunBaglami): void {
    ctx.setFaz('OY', ctx.now() + this.oySuresiMs(ctx));
    this.ilerlemeYayinla(ctx);
  }

  private ilerlemeYayinla(ctx: OyunBaglami): void {
    const bagli = this.bagliUygun(ctx);
    const kayit = ctx.faz() === 'TAHMIN' ? this.s.tahminler : this.s.oylar;
    const verilen = bagli.filter((p) => typeof kayit[p.id] === 'string').length;
    ctx.yayin('voteProgress', { votedCount: verilen, total: bagli.length });
  }

  tik(ctx: OyunBaglami): void {
    switch (ctx.faz()) {
      case 'SORU':
        if (ctx.ayarlar.tahmin === true) {
          ctx.setFaz('TAHMIN', ctx.now() + this.oySuresiMs(ctx));
          this.ilerlemeYayinla(ctx);
        } else this.oyFazinaGec(ctx);
        break;
      case 'TAHMIN':
        this.oyFazinaGec(ctx);
        break;
      case 'OY':
        this.sonucHesapla(ctx);
        break;
      case 'SONUC':
        if (ctx.ayarlar.tahmin === true) {
          ctx.setFaz('TAHMIN_SKOR', ctx.now() + TAHMIN_SKOR_MS);
        } else this.sonrakiSoru(ctx);
        break;
      case 'TAHMIN_SKOR':
        this.sonrakiSoru(ctx);
        break;
      default:
        break;
    }
  }

  private sonucHesapla(ctx: OyunBaglami): void {
    const q = this.soru()!;
    const counts: Record<string, number> = {};
    let toplam = 0;
    for (const [voter, hedef] of Object.entries(this.s.oylar)) {
      this.s.oyVerilenSoru[voter] = (this.s.oyVerilenSoru[voter] ?? 0) + (typeof hedef === 'string' ? 1 : 0);
      if (typeof hedef !== 'string') continue;
      counts[hedef] = (counts[hedef] ?? 0) + 1;
      this.s.alinanOy[hedef] = (this.s.alinanOy[hedef] ?? 0) + 1;
      if (hedef === voter) this.s.kendineOy[voter] = (this.s.kendineOy[voter] ?? 0) + 1;
      toplam++;
    }
    const en = Math.max(0, ...Object.values(counts));
    const winners = en > 0 ? Object.keys(counts).filter((k) => counts[k] === en) : [];
    const tie = winners.length > 1;
    if (winners.length === 1) {
      if (this.s.serilId === winners[0]) this.s.seriN++;
      else {
        this.s.serilId = winners[0];
        this.s.seriN = 1;
      }
    } else {
      this.s.serilId = null;
      this.s.seriN = 0;
    }
    const hedefMesaj = this.s.seriN >= 3 ? this.s.serilId : null;
    this.s.sonuc = { qId: q.id, counts, winners, tie, noVotes: toplam === 0, target: hedefMesaj };
    if (ctx.ayarlar.tahmin === true) {
      const dogru: string[] = [];
      for (const [pid, t] of Object.entries(this.s.tahminler)) {
        if (typeof t === 'string' && winners.includes(t)) {
          dogru.push(pid);
          this.s.puan[pid] = (this.s.puan[pid] ?? 0) + 1;
        }
      }
      this.s.tahminSonuc = { qId: q.id, correctPlayerIds: dogru };
    }
    ctx.setFaz('SONUC', ctx.now() + SONUC_MS);
    const gosterilen = ctx.ayarlar.sonuc === 'kazanan' ? Object.fromEntries(winners.map((w) => [w, counts[w]])) : counts;
    ctx.yayin('result', {
      qId: q.id,
      counts: gosterilen,
      winners,
      tie,
      noVotes: toplam === 0,
      target: hedefMesaj,
    });
    if (this.s.tahminSonuc) ctx.yayin('predictResult', this.s.tahminSonuc);
  }

  private bitir(ctx: OyunBaglami): void {
    const oyuncular = this.uygunlar(ctx);
    const enCok = Math.max(0, ...Object.values(this.s.alinanOy));
    const badges: { badge: string; playerIds: string[] }[] = [];
    if (enCok > 0) {
      badges.push({ badge: 'favorite', playerIds: Object.keys(this.s.alinanOy).filter((k) => this.s.alinanOy[k] === enCok) });
    }
    if (ctx.ayarlar.kendineOy === 'serbest') {
      const durust = oyuncular.filter((p) => (this.s.oyVerilenSoru[p.id] ?? 0) > 0 && (this.s.kendineOy[p.id] ?? 0) === 0);
      if (durust.length) badges.push({ badge: 'honest', playerIds: durust.map((p) => p.id) });
    }
    const comert = oyuncular.filter((p) => {
      const katildigi = this.s.toplam - (this.s.katilimSorusu[p.id] ?? 0);
      return katildigi > 0 && (this.s.oyVerilenSoru[p.id] ?? 0) >= katildigi;
    });
    if (comert.length) badges.push({ badge: 'generous', playerIds: comert.map((p) => p.id) });
    const tablo =
      ctx.ayarlar.tahmin === true
        ? oyuncular.map((p) => ({ playerId: p.id, score: this.s.puan[p.id] ?? 0 })).sort((a, b) => b.score - a.score)
        : null;
    this.s.final = { badges, scoreboard: tablo, stats: { questions: this.s.toplam } };
    ctx.setFaz('FINAL', null);
    ctx.yayin('final', this.s.final);
  }

  mesaj(ctx: OyunBaglami, o: Player, t: string, p: Record<string, unknown>): Sonuc {
    switch (t) {
      case 'vote':
        return this.oyVer(ctx, o, p, false);
      case 'predict':
        return this.oyVer(ctx, o, p, true);
      case 'continue':
      case 'finish': {
        if (o.id !== ctx.hostId) return hata('NOT_HOST');
        if (!this.s.duraklat) return hata('WRONG_PHASE');
        if (t === 'finish') {
          this.s.duraklat = null;
          this.bitir(ctx);
        } else {
          const d = this.s.duraklat;
          this.s.duraklat = null;
          ctx.setFaz(d.faz, ctx.now() + d.kalanMs);
          this.ilerlemeYayinla(ctx);
        }
        return TAMAM;
      }
      default:
        return hata('INVALID_MESSAGE');
    }
  }

  private oyVer(ctx: OyunBaglami, o: Player, p: Record<string, unknown>, tahmin: boolean): Sonuc {
    const gerekli = tahmin ? 'TAHMIN' : 'OY';
    if (ctx.faz() !== gerekli) {
      return hata(ctx.faz() === 'SORU' || ctx.faz() === 'OY' || ctx.faz() === 'TAHMIN' ? 'WRONG_PHASE' : 'WRONG_PHASE');
    }
    const q = this.soru();
    if (!q || p.qId !== q.id) return hata('STALE_QUESTION');
    const hedef = p.target;
    if (hedef !== null && typeof hedef !== 'string') return hata('INVALID_MESSAGE');
    if (hedef !== null && hedef !== undefined) {
      const h = ctx.oyuncu(hedef as string);
      if (!h || h.role !== 'player' || h.left) return hata('INVALID_TARGET');
      if (!tahmin && hedef === o.id && ctx.ayarlar.kendineOy !== 'serbest') return hata('SELF_VOTE_FORBIDDEN');
    }
    if (tahmin && (hedef === null || hedef === undefined)) return hata('INVALID_TARGET');
    const kayit = tahmin ? this.s.tahminler : this.s.oylar;
    kayit[o.id] = (hedef ?? null) as string | null;
    if (!tahmin) ctx.gonder(o.id, 'myVote', { qId: q.id, target: kayit[o.id] });
    this.ilerlemeYayinla(ctx);
    // Tüm bağlı oyuncular verdiyse fazı ~1 sn sonra bitir.
    const bagli = this.bagliUygun(ctx);
    if (bagli.length > 0 && bagli.every((x) => typeof kayit[x.id] === 'string')) {
      const yeni = ctx.now() + ERKEN_BITIS_MS;
      ctx.setFaz(ctx.faz(), yeni);
    }
    return TAMAM;
  }

  oyuncuDegisti(ctx: OyunBaglami, olay: 'join' | 'leave' | 'disconnect' | 'reconnect', o: Player): void {
    const faz = ctx.faz();
    if (faz === 'LOBBY' || faz === 'FINAL') return;
    if (olay === 'join') {
      this.s.katilimSorusu[o.id] = this.s.idx + 1;
    }
    if ((olay === 'leave' || olay === 'disconnect') && !this.s.duraklat && this.bagliUygun(ctx).length < 3) {
      this.duraklat(ctx, faz);
    }
  }

  private duraklat(ctx: OyunBaglami, faz: string): void {
    const bitis = ctx.bitisAni();
    const kalanMs = bitis === null ? 0 : Math.max(1000, bitis - ctx.now());
    this.s.duraklat = { faz, kalanMs };
    ctx.setFaz('DURAKLA', null);
  }

  herkeseAcik(ctx: OyunBaglami): unknown {
    const q = this.soru();
    const faz = ctx.faz();
    const bagli = this.bagliUygun(ctx);
    const kayit = faz === 'TAHMIN' ? this.s.tahminler : this.s.oylar;
    return {
      settings: ctx.ayarlar,
      idx: Math.max(0, this.s.idx + 1),
      total: this.s.toplam,
      question: q && faz !== 'LOBBY' && faz !== 'FINAL' ? { qId: q.id, text: q.metin, category: q.kategori } : null,
      voteProgress: { votedCount: bagli.filter((p) => typeof kayit[p.id] === 'string').length, total: bagli.length },
      result: faz === 'SONUC' || faz === 'TAHMIN_SKOR' ? this.s.sonuc : null,
      predictResult: faz === 'SONUC' || faz === 'TAHMIN_SKOR' ? this.s.tahminSonuc : null,
      final: faz === 'FINAL' ? this.s.final : null,
      paused: this.s.duraklat !== null,
    };
  }

  ozel(ctx: OyunBaglami, playerId: string): unknown {
    const faz = ctx.faz();
    if (faz === 'LOBBY') return null;
    const q = this.soru();
    return {
      qId: q?.id ?? null,
      myVote: this.s.oylar[playerId] ?? null,
      myPredict: this.s.tahminler[playerId] ?? null,
      score: this.s.puan[playerId] ?? 0,
    };
  }
}

const SECENEK = {
  soruSayisi: [10, 15, 20],
  oySuresi: [10, 15, 20],
  kendineOy: ['yasak', 'serbest'],
  seviye: ['gunluk', 'cesur', 'yilbasi'],
  sonuc: ['dagilim', 'kazanan'],
} as const;

export const enOlasiKimTanimi: OyunTanimi = {
  id: '07',
  minOyuncu: 3,
  maxOyuncu: 20,
  gecKatilim: 'seyirci',
  varsayilanAyarlar: () => ({ soruSayisi: 15, oySuresi: 15, kendineOy: 'yasak', tahmin: false, seviye: 'gunluk', sonuc: 'dagilim' }),
  ayarlariDogrula(ham, mevcut): Ayarlar | null {
    const a: Ayarlar = { ...mevcut };
    for (const [k, v] of Object.entries(ham)) {
      if (k === 'premiumHavuz') {
        // Yalnız oda kurulurken Worker verir; setSettings ile değiştirilemez (room.ts).
        if (typeof v !== 'boolean') return null;
        a.premiumHavuz = v;
      } else if (k === 'tahmin') {
        if (typeof v !== 'boolean') return null;
        a.tahmin = v;
      } else if (k in SECENEK) {
        if (!(SECENEK as Record<string, readonly (string | number)[]>)[k].includes(v as string | number)) return null;
        a[k] = v as string | number;
      } else return null;
    }
    return a;
  },
  olustur: (_ayar, dep) => EnOlasiKim.yeni(dep),
  geriYukle: (json, dep) => new EnOlasiKim(json as Durum, dep),
};
