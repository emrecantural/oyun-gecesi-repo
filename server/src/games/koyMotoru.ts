import { karistir, type Rand } from '../core/rng.ts';

export type Rol = 'kurt' | 'kahin' | 'doktor' | 'cadi' | 'avci' | 'asik' | 'koylu';
export type Taraf = 'koy' | 'kurtlar';
export type OlumNedeni = 'kurt' | 'zehir' | 'askZinciri' | 'oylama' | 'avci';
export interface Olum {
  id: string;
  neden: OlumNedeni;
}

export const ROLLER: readonly Rol[] = ['kurt', 'kahin', 'doktor', 'cadi', 'avci', 'asik', 'koylu'];

export class KoyHatasi extends Error {
  kod: string;
  constructor(kod: string) {
    super(kod);
    this.kod = kod;
  }
}

/** Rol paketi tablosu (Dart `varsayilanRolPaketi` ile birebir). */
export function varsayilanRolPaketi(n: number): Record<Rol, number> {
  const kurt = n <= 11 ? 2 : n <= 15 ? 3 : n <= 19 ? 4 : 5;
  const avci = n >= 8 ? 1 : 0;
  const asik = n >= 10 ? 2 : 0;
  const cadi = n >= 12 ? 1 : 0;
  const koylu = n - kurt - 1 - 1 - avci - asik - cadi;
  return { kurt, kahin: 1, doktor: 1, cadi, avci, asik, koylu };
}

export interface KoyAyarlari {
  acikOylama: boolean;
  oluncRoluAc: boolean;
  esitOyYenidenOy: boolean;
  doktorKendiniKorur: boolean;
}

export interface MotorVeri {
  oyuncular: string[];
  roller: Record<string, Rol>;
  ask: Record<string, string>;
  olu: string[];
  tumOlumler: Olum[];
  gece: number;
  iyilestirmeVar: boolean;
  zehirVar: boolean;
  kurtOylari: Record<string, string>;
  korunan: string | null;
  sonKorunan: string | null;
  zehirHedef: string | null;
  iyilestirildi: boolean;
  kahinSorgu: string[];
  oylar: Record<string, string | null>;
  suphecilik: Record<string, number>;
  ayar: KoyAyarlari;
}

/** Saf oyun motoru; Dart `KoyOyunu` ile aynı kurallar (altın vektörlerle bağlanır). */
export class KoyMotoru {
  d: MotorVeri;

  constructor(d: MotorVeri) {
    this.d = d;
  }

  /** `rolDagitimi` verilirse (test/altın vektör) karıştırma yapılmaz; i. oyuncu i. rolü alır. */
  static yeni(opts: {
    oyuncular: string[];
    rolPaketi?: Partial<Record<Rol, number>>;
    ayar: KoyAyarlari;
    rand?: Rand;
    rolDagitimi?: Rol[];
  }): KoyMotoru {
    const n = opts.oyuncular.length;
    let havuz: Rol[];
    if (opts.rolDagitimi) {
      if (opts.rolDagitimi.length !== n) throw new KoyHatasi('ROLEPACK_MISMATCH');
      havuz = [...opts.rolDagitimi];
    } else {
      const paket = opts.rolPaketi ?? varsayilanRolPaketi(n);
      const toplam = ROLLER.reduce((a, r) => a + (paket[r] ?? 0), 0);
      if (toplam !== n) throw new KoyHatasi('ROLEPACK_MISMATCH');
      havuz = [];
      for (const r of ROLLER) for (let i = 0; i < (paket[r] ?? 0); i++) havuz.push(r);
      havuz = karistir(havuz, opts.rand!);
    }
    const roller: Record<string, Rol> = {};
    opts.oyuncular.forEach((id, i) => (roller[id] = havuz[i]));
    const ask: Record<string, string> = {};
    const asiklar = opts.oyuncular.filter((id) => roller[id] === 'asik');
    if (asiklar.length === 2) {
      ask[asiklar[0]] = asiklar[1];
      ask[asiklar[1]] = asiklar[0];
    }
    return new KoyMotoru({
      oyuncular: [...opts.oyuncular],
      roller,
      ask,
      olu: [],
      tumOlumler: [],
      gece: 0,
      iyilestirmeVar: true,
      zehirVar: true,
      kurtOylari: {},
      korunan: null,
      sonKorunan: null,
      zehirHedef: null,
      iyilestirildi: false,
      kahinSorgu: [],
      oylar: {},
      suphecilik: {},
      ayar: opts.ayar,
    });
  }

  canli(id: string): boolean {
    return !this.d.olu.includes(id);
  }
  get canlilar(): string[] {
    return this.d.oyuncular.filter((id) => this.canli(id));
  }
  get kurtlar(): string[] {
    return this.d.oyuncular.filter((id) => this.d.roller[id] === 'kurt');
  }
  get canliKurtlar(): string[] {
    return this.kurtlar.filter((id) => this.canli(id));
  }

  geceBasla(): void {
    const d = this.d;
    d.gece++;
    d.kurtOylari = {};
    d.korunan = null;
    d.zehirHedef = null;
    d.iyilestirildi = false;
    d.kahinSorgu = [];
  }

  kahinSorgula(actor: string, hedef: string): boolean {
    const d = this.d;
    if (d.roller[actor] !== 'kahin' || !this.canli(actor)) throw new KoyHatasi('NOT_YOUR_ROLE');
    if (!this.canli(hedef) || hedef === actor) throw new KoyHatasi('INVALID_TARGET');
    if (d.kahinSorgu.includes(actor)) throw new KoyHatasi('ALREADY_ACTED');
    d.kahinSorgu.push(actor);
    return d.roller[hedef] === 'kurt';
  }

  kurtOyu(actor: string, hedef: string): void {
    const d = this.d;
    if (d.roller[actor] !== 'kurt' || !this.canli(actor)) throw new KoyHatasi('NOT_YOUR_ROLE');
    if (!this.canli(hedef) || d.roller[hedef] === 'kurt') throw new KoyHatasi('INVALID_TARGET');
    d.kurtOylari[actor] = hedef;
  }

  koru(actor: string, hedef: string): void {
    const d = this.d;
    if (d.roller[actor] !== 'doktor' || !this.canli(actor)) throw new KoyHatasi('NOT_YOUR_ROLE');
    if (!this.canli(hedef)) throw new KoyHatasi('INVALID_TARGET');
    if (hedef === actor && !d.ayar.doktorKendiniKorur) throw new KoyHatasi('DOCTOR_SELF_OFF');
    if (hedef === d.sonKorunan) throw new KoyHatasi('DOCTOR_REPEAT');
    d.korunan = hedef;
  }

  /** Kurtların hedefi: en çok oy; eşitlikte kurban yok. */
  get kurbanHedefi(): string | null {
    const oylar = Object.values(this.d.kurtOylari);
    if (oylar.length === 0) return null;
    const sayim = new Map<string, number>();
    for (const h of oylar) sayim.set(h, (sayim.get(h) ?? 0) + 1);
    const en = Math.max(...sayim.values());
    const adaylar = [...sayim.entries()].filter(([, v]) => v === en).map(([k]) => k);
    return adaylar.length === 1 ? adaylar[0] : null;
  }

  cadiIyilestir(actor: string): void {
    const d = this.d;
    if (d.roller[actor] !== 'cadi' || !this.canli(actor)) throw new KoyHatasi('NOT_YOUR_ROLE');
    if (!d.iyilestirmeVar) throw new KoyHatasi('POTION_USED');
    if (this.kurbanHedefi === null) throw new KoyHatasi('INVALID_TARGET');
    d.iyilestirmeVar = false;
    d.iyilestirildi = true;
  }

  cadiZehirle(actor: string, hedef: string): void {
    const d = this.d;
    if (d.roller[actor] !== 'cadi' || !this.canli(actor)) throw new KoyHatasi('NOT_YOUR_ROLE');
    if (!d.zehirVar) throw new KoyHatasi('POTION_USED');
    if (!this.canli(hedef) || hedef === actor) throw new KoyHatasi('INVALID_TARGET');
    d.zehirVar = false;
    d.zehirHedef = hedef;
  }

  /** Gece çözümü: kurt hedefi (koruma / iyileştirme) → zehir → âşık zinciri → avcı. */
  geceyiCoz(): { olumler: Olum[]; avciBekliyor: string | null } {
    const d = this.d;
    const olumler: Olum[] = [];
    const kurban = this.kurbanHedefi;
    if (kurban !== null && kurban !== d.korunan && !d.iyilestirildi) olumler.push({ id: kurban, neden: 'kurt' });
    const z = d.zehirHedef;
    if (z !== null && !olumler.some((o) => o.id === z)) olumler.push({ id: z, neden: 'zehir' });
    olumler.push(...this.askZinciri(olumler));
    this.isle(olumler);
    d.sonKorunan = d.korunan;
    return { olumler, avciBekliyor: this.avciBul(olumler) };
  }

  private isle(olumler: Olum[]): void {
    for (const o of olumler) {
      this.d.olu.push(o.id);
      this.d.tumOlumler.push(o);
    }
  }

  private avciBul(olumler: Olum[]): string | null {
    return olumler.map((o) => o.id).find((id) => this.d.roller[id] === 'avci') ?? null;
  }

  private askZinciri(olumler: Olum[]): Olum[] {
    const yeni: Olum[] = [];
    for (const o of olumler) {
      const es = this.d.ask[o.id];
      if (es !== undefined && this.canli(es) && !olumler.some((x) => x.id === es) && !yeni.some((x) => x.id === es)) {
        yeni.push({ id: es, neden: 'askZinciri' });
      }
    }
    return yeni;
  }

  // ---- gündüz ----
  oyBaslat(): void {
    this.d.oylar = {};
  }

  oyVer(voter: string, hedef: string | null): void {
    if (!this.canli(voter)) throw new KoyHatasi('NOT_ALIVE');
    if (hedef !== null) {
      if (!this.canli(hedef)) throw new KoyHatasi('INVALID_TARGET');
      if (hedef === voter) throw new KoyHatasi('SELF_TARGET_FORBIDDEN');
    }
    this.d.oylar[voter] = hedef;
  }

  oySayilari(): Record<string, number> {
    const m: Record<string, number> = {};
    for (const h of Object.values(this.d.oylar)) if (h !== null) m[h] = (m[h] ?? 0) + 1;
    return m;
  }

  /** En çok oy alan; eşitlikte kimse elenmez, `esitAdaylar` döner. */
  oylamayiBitir(): { olumler: Olum[]; avci: string | null; esitAdaylar: string[] } {
    const sayim = this.oySayilari();
    const deger = Object.values(sayim);
    if (deger.length === 0) return { olumler: [], avci: null, esitAdaylar: [] };
    const en = Math.max(...deger);
    const adaylar = Object.keys(sayim).filter((k) => sayim[k] === en);
    if (adaylar.length > 1) return { olumler: [], avci: null, esitAdaylar: adaylar };
    const elenen = adaylar[0];
    if (this.d.roller[elenen] === 'kurt') {
      for (const [voter, hedef] of Object.entries(this.d.oylar)) {
        if (hedef === elenen) this.d.suphecilik[voter] = (this.d.suphecilik[voter] ?? 0) + 1;
      }
    }
    const olumler: Olum[] = [{ id: elenen, neden: 'oylama' }];
    olumler.push(...this.askZinciri(olumler));
    this.isle(olumler);
    return { olumler, avci: this.avciBul(olumler), esitAdaylar: [] };
  }

  avciVur(avci: string, hedef: string | null): Olum[] {
    if (this.d.roller[avci] !== 'avci') throw new KoyHatasi('NOT_YOUR_ROLE');
    if (hedef === null) return [];
    if (!this.canli(hedef)) throw new KoyHatasi('INVALID_TARGET');
    const olumler: Olum[] = [{ id: hedef, neden: 'avci' }];
    olumler.push(...this.askZinciri(olumler));
    this.isle(olumler);
    return olumler;
  }

  kazanan(): Taraf | null {
    const k = this.canliKurtlar.length;
    const diger = this.canlilar.length - k;
    if (k === 0) return 'koy';
    if (k >= diger) return 'kurtlar';
    return null;
  }

  enIyiYalanci(): string | null {
    return this.canliKurtlar[0] ?? null;
  }

  supheci(): string | null {
    const e = Object.entries(this.d.suphecilik);
    if (e.length === 0) return null;
    e.sort((a, b) => b[1] - a[1]);
    return e[0][0];
  }
}
