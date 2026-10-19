import { karistir } from '../core/rng.ts';
import {
  KoyHatasi,
  KoyMotoru,
  ROLLER,
  varsayilanRolPaketi,
  type MotorVeri,
  type Olum,
  type Rol,
} from './koyMotoru.ts';
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

const ROL_DAGIT_MS = 8000;
const ASKLAR_MS = 10_000;
const SAFAK_MS = 10_000;
const AVCI_MS = 15_000;
const OYLAMA_MS = 20_000;
const OY_SONUC_MS = 8000;
const SABAH_OLUM_SAYISI = 20; // içerik/03-koy-ve-kurtlar.csv: sabah_olum
const SABAH_SESSIZ_SAYISI = 10;

const GECE_FAZLARI = ['GECE_KAHIN', 'GECE_KURT', 'GECE_DOKTOR', 'GECE_CADI'] as const;
type GeceFazi = (typeof GECE_FAZLARI)[number];
const FAZ_ROL: Record<GeceFazi, Rol> = { GECE_KAHIN: 'kahin', GECE_KURT: 'kurt', GECE_DOKTOR: 'doktor', GECE_CADI: 'cadi' };
const FAZ_TUR: Record<GeceFazi, string> = { GECE_KAHIN: 'seer', GECE_KURT: 'wolfVote', GECE_DOKTOR: 'protect', GECE_CADI: 'witchAct' };
const EYLEM_FAZ: Record<string, GeceFazi> = {
  seer: 'GECE_KAHIN',
  wolfVote: 'GECE_KURT',
  protect: 'GECE_DOKTOR',
  witchHeal: 'GECE_CADI',
  witchPoison: 'GECE_CADI',
  witchSkip: 'GECE_CADI',
};

interface Eylem {
  kind: string;
  target: string | null;
}

interface Durum {
  motor: MotorVeri | null;
  rolPaketi: Record<string, number> | null;
  kilit: Record<string, Eylem[]>; // bu gecenin kilitli onaylı eylemleri
  kahinSonuc: Record<string, { targetId: string; isWolf: boolean }>; // bu gece
  kahinGecmis: Record<string, { gece: number; targetId: string; isWolf: boolean }[]>;
  avciBekleyen: string | null;
  sonrasi: 'tartisma' | 'gece';
  oluler: { id: string; neden: string; roleShown: Rol | null }[]; // son şafak/oylama/avcı ölümleri
  adaylar: string[] | null; // yeniden oy turunda
  yenidenYapildi: boolean;
  yenidenBekliyor: boolean;
  sonOy: null | { tally: Record<string, number>; eliminatedId: string | null; roleShown: Rol | null; votes: Record<string, string | null> | null; tie: boolean };
  sabahMetni: { key: 'death' | 'silent'; idx: number } | null;
  kullanilanOlum: number[];
  kullanilanSessiz: number[];
  duraklat: null | { faz: string; kalanMs: number };
  final: unknown;
}

function geceMs(ctx: OyunBaglami): number {
  return Number(ctx.ayarlar.geceSn) * 1000;
}

export class KoyKurtlar implements Oyun {
  readonly gizliEylemler: readonly string[] = ['nightAction', 'hunterShoot'];
  private s: Durum;
  private dep: OyunBagimliliklari;

  constructor(s: Durum, dep: OyunBagimliliklari) {
    this.s = s;
    this.dep = dep;
  }

  static yeni(dep: OyunBagimliliklari): KoyKurtlar {
    return new KoyKurtlar(
      {
        motor: null, rolPaketi: null, kilit: {}, kahinSonuc: {}, kahinGecmis: {}, avciBekleyen: null, sonrasi: 'tartisma',
        oluler: [], adaylar: null, yenidenYapildi: false, yenidenBekliyor: false, sonOy: null, sabahMetni: null,
        kullanilanOlum: [], kullanilanSessiz: [], duraklat: null, final: null,
      },
      dep,
    );
  }

  toJSON() {
    return this.s;
  }

  private m(): KoyMotoru {
    return new KoyMotoru(this.s.motor!);
  }

  tepkiAcik(ctx: OyunBaglami): boolean {
    return ['SAFAK', 'OYLAMA_SONUC', 'FINAL', 'LOBBY'].includes(ctx.faz());
  }

  // ------------------------------------------------------------------ başlangıç
  basla(ctx: OyunBaglami): string | null {
    const oyuncular = ctx.oyuncular().map((p) => p.id);
    const n = oyuncular.length;
    if (n < 6 || n > 20) return 'MIN_PLAYERS';
    const paket = this.s.rolPaketi ?? varsayilanRolPaketi(n);
    const toplam = ROLLER.reduce((a, r) => a + (paket[r] ?? 0), 0);
    if (toplam !== n) return 'ROLEPACK_MISMATCH';
    const motor = KoyMotoru.yeni({
      oyuncular,
      rolPaketi: paket,
      rand: this.dep.rand,
      ayar: {
        acikOylama: ctx.ayarlar.oylama === 'acik',
        oluncRoluAc: ctx.ayarlar.rolAc === 'evet',
        esitOyYenidenOy: ctx.ayarlar.esit === 'yeniden',
        doktorKendiniKorur: ctx.ayarlar.doktorKendini === 'evet',
      },
    });
    this.s.motor = motor.d;
    for (const id of oyuncular) this.rolBildir(ctx, id);
    ctx.setFaz('ROL_DAGIT', ctx.now() + ROL_DAGIT_MS);
    return null;
  }

  private rolBildir(ctx: OyunBaglami, id: string): void {
    const d = this.s.motor!;
    const rol = d.roller[id];
    const allies = rol === 'kurt' ? this.m().kurtlar.filter((x) => x !== id) : [];
    ctx.gonder(id, 'private', { kind: 'roleAssigned', role: rol, allies, loverId: d.ask[id] ?? null });
  }

  // ------------------------------------------------------------------ zamanlayıcı
  tik(ctx: OyunBaglami): void {
    const faz = ctx.faz();
    switch (faz) {
      case 'ROL_DAGIT':
        if (Object.keys(this.s.motor!.ask).length > 0) this.asklarFazi(ctx);
        else this.yeniGece(ctx);
        break;
      case 'GECE_ASKLAR':
        this.yeniGece(ctx);
        break;
      case 'GECE_KAHIN':
      case 'GECE_KURT':
      case 'GECE_DOKTOR': {
        const sonraki = GECE_FAZLARI[GECE_FAZLARI.indexOf(faz) + 1];
        this.geceFazi(ctx, sonraki);
        break;
      }
      case 'GECE_CADI':
        this.safak(ctx);
        break;
      case 'SAFAK':
        if (this.s.avciBekleyen) this.avciFazi(ctx, 'tartisma');
        else this.kazanmaKontrol(ctx, 'tartisma');
        break;
      case 'AVCI':
        this.avciIsle(ctx, null);
        break;
      case 'TARTISMA':
        this.oylamaBasla(ctx, null);
        break;
      case 'OYLAMA':
        this.oylamaBitir(ctx);
        break;
      case 'OYLAMA_SONUC':
        if (this.s.yenidenBekliyor) {
          this.s.yenidenBekliyor = false;
          this.s.yenidenYapildi = true;
          this.oylamaBasla(ctx, this.s.adaylar);
        } else if (this.s.avciBekleyen) this.avciFazi(ctx, 'gece');
        else this.kazanmaKontrol(ctx, 'gece');
        break;
      default:
        break;
    }
  }

  private asklarFazi(ctx: OyunBaglami): void {
    const d = this.s.motor!;
    ctx.setFaz('GECE_ASKLAR', ctx.now() + ASKLAR_MS);
    for (const [id, es] of Object.entries(d.ask)) ctx.gonder(id, 'private', { kind: 'lovers', loverId: es });
  }

  private yeniGece(ctx: OyunBaglami): void {
    this.m().geceBasla();
    this.s.kilit = {};
    this.s.kahinSonuc = {};
    this.s.oluler = [];
    this.s.sonOy = null;
    this.s.yenidenYapildi = false;
    this.s.yenidenBekliyor = false;
    this.s.adaylar = null;
    this.geceFazi(ctx, 'GECE_KAHIN');
  }

  private hedefler(id: string): string[] {
    return this.m().canlilar.filter((x) => x !== id);
  }

  private istemOlustur(ctx: OyunBaglami, id: string, faz: GeceFazi): Record<string, unknown> | null {
    const m = this.m();
    if (!m.canli(id)) return null;
    const gercek = this.s.motor!.roller[id] === FAZ_ROL[faz];
    return {
      kind: 'nightPrompt',
      prompt: gercek ? FAZ_TUR[faz] : 'none',
      targets: this.hedefler(id),
      endsAt: ctx.bitisAni(),
      myAction: this.s.kilit[id]?.filter((e) => EYLEM_FAZ[e.kind] === faz) ?? [],
    };
  }

  private geceFazi(ctx: OyunBaglami, faz: GeceFazi): void {
    ctx.setFaz(faz, ctx.now() + geceMs(ctx));
    const m = this.m();
    for (const id of m.canlilar) {
      const ist = this.istemOlustur(ctx, id, faz);
      if (ist) ctx.gonder(id, 'private', ist);
    }
    if (faz === 'GECE_KURT') this.kurtTahtasi(ctx);
    if (faz === 'GECE_KAHIN') {
      // yeniden bağlananlar için kâhin sonucu zaten kilit/sonuçtan gelir
    }
    if (faz === 'GECE_CADI') {
      const cadi = m.canlilar.filter((id) => this.s.motor!.roller[id] === 'cadi');
      for (const id of cadi) ctx.gonder(id, 'private', this.cadiBilgisi());
    }
  }

  private cadiBilgisi() {
    const m = this.m();
    return { kind: 'witchInfo', victimId: m.kurbanHedefi, potions: { heal: this.s.motor!.iyilestirmeVar, poison: this.s.motor!.zehirVar } };
  }

  private kurtTahtasi(ctx: OyunBaglami): void {
    const m = this.m();
    for (const id of m.canliKurtlar) ctx.gonder(id, 'private', { kind: 'wolfBoard', votes: { ...this.s.motor!.kurtOylari } });
  }

  // ------------------------------------------------------------------ gece eylemleri
  mesaj(ctx: OyunBaglami, o: Player, t: string, p: Record<string, unknown>): Sonuc {
    switch (t) {
      case 'nightAction':
        this.geceEylemi(ctx, o, p);
        return TAMAM;
      case 'hunterShoot':
        this.avciAtisi(ctx, o, p);
        return TAMAM;
      case 'castVote':
        return this.oyVer(ctx, o, p);
      case 'setRolePack':
        return this.rolPaketiAyarla(ctx, o, p);
      case 'continue':
      case 'finish':
        return this.duraklatmaKomutu(ctx, o, t);
      default:
        return hata('INVALID_MESSAGE');
    }
  }

  private geceEylemi(ctx: OyunBaglami, o: Player, p: Record<string, unknown>): void {
    const kind = typeof p.kind === 'string' ? p.kind : '';
    const target = typeof p.target === 'string' ? p.target : null;
    const gerekliFaz = EYLEM_FAZ[kind];
    const faz = ctx.faz();
    const m = this.m();
    const rol = this.s.motor?.roller[o.id];
    // Rolü olmayan / yanlış faz / ölü / bilinmeyen tür: olay yok sayılır (Room sahte ack döner).
    if (!gerekliFaz || faz !== gerekliFaz || !rol || rol !== FAZ_ROL[gerekliFaz] || !m.canli(o.id)) return;
    const kilitli = this.s.kilit[o.id] ?? [];
    // İlk onaylı eylem kilitlenir. Cadı: iyileştirme ve zehir ayrı hak; pas ikisini de bitirir.
    if (kilitli.some((e) => e.kind === kind)) return;
    if (rol === 'cadi' && kilitli.some((e) => e.kind === 'witchSkip')) return;
    if (rol !== 'cadi' && kilitli.length > 0) return;
    try {
      switch (kind) {
        case 'seer': {
          if (target === null) throw new KoyHatasi('INVALID_TARGET');
          const kurt = m.kahinSorgula(o.id, target);
          this.s.kahinSonuc[o.id] = { targetId: target, isWolf: kurt };
          (this.s.kahinGecmis[o.id] ??= []).push({ gece: this.s.motor!.gece, targetId: target, isWolf: kurt });
          ctx.gonder(o.id, 'private', { kind: 'seerResult', targetId: target, isWolf: kurt });
          break;
        }
        case 'wolfVote':
          if (target === null) throw new KoyHatasi('INVALID_TARGET');
          m.kurtOyu(o.id, target);
          this.kurtTahtasi(ctx);
          break;
        case 'protect':
          if (target === null) throw new KoyHatasi('INVALID_TARGET');
          m.koru(o.id, target);
          break;
        case 'witchHeal':
          m.cadiIyilestir(o.id);
          break;
        case 'witchPoison':
          if (target === null) throw new KoyHatasi('INVALID_TARGET');
          m.cadiZehirle(o.id, target);
          break;
        case 'witchSkip':
          break;
      }
      (this.s.kilit[o.id] ??= []).push({ kind, target });
      ctx.kaydet();
    } catch (e) {
      // Gerçek rol sahibine yalnız kendisine bilgi verilir; başkalarına hiçbir iz gitmez.
      if (e instanceof KoyHatasi) ctx.gonder(o.id, 'private', { kind: 'actionRejected', code: e.kod });
      else throw e;
    }
  }

  // ------------------------------------------------------------------ şafak
  private metinSec(ctx: OyunBaglami, key: 'death' | 'silent'): { key: 'death' | 'silent'; idx: number } {
    const toplam = key === 'death' ? SABAH_OLUM_SAYISI : SABAH_SESSIZ_SAYISI;
    const kul = key === 'death' ? this.s.kullanilanOlum : this.s.kullanilanSessiz;
    if (kul.length >= toplam) kul.length = 0;
    const kalan = Array.from({ length: toplam }, (_, i) => i).filter((i) => !kul.includes(i));
    const idx = karistir(kalan, this.dep.rand)[0];
    kul.push(idx);
    return { key, idx };
  }

  private olumKayitlari(olumler: Olum[]) {
    const rolAc = this.s.motor!.ayar.oluncRoluAc;
    return olumler.map((o) => ({ id: o.id, neden: o.neden, roleShown: rolAc ? this.s.motor!.roller[o.id] : null }));
  }

  private safak(ctx: OyunBaglami): void {
    const m = this.m();
    const sonuc = m.geceyiCoz();
    this.s.oluler = this.olumKayitlari(sonuc.olumler);
    this.s.avciBekleyen = sonuc.avciBekliyor;
    this.s.sabahMetni = this.metinSec(ctx, sonuc.olumler.length ? 'death' : 'silent');
    ctx.setFaz('SAFAK', ctx.now() + SAFAK_MS);
    ctx.yayin('dawn', { deaths: this.s.oluler, text: this.s.sabahMetni, round: this.s.motor!.gece });
  }

  // ------------------------------------------------------------------ avcı
  private avciFazi(ctx: OyunBaglami, sonra: 'tartisma' | 'gece'): void {
    this.s.sonrasi = sonra;
    ctx.setFaz('AVCI', ctx.now() + AVCI_MS);
    const av = this.s.avciBekleyen!;
    ctx.gonder(av, 'private', { kind: 'hunterPrompt', targets: this.hedefler(av), endsAt: ctx.bitisAni() });
  }

  private avciAtisi(ctx: OyunBaglami, o: Player, p: Record<string, unknown>): void {
    if (ctx.faz() !== 'AVCI' || this.s.avciBekleyen !== o.id) return;
    const target = typeof p.target === 'string' ? p.target : null;
    if (target === null) return;
    const m = this.m();
    if (!m.canli(target) || target === o.id) {
      ctx.gonder(o.id, 'private', { kind: 'actionRejected', code: 'INVALID_TARGET' });
      return;
    }
    this.avciIsle(ctx, target);
  }

  private avciIsle(ctx: OyunBaglami, hedef: string | null): void {
    const av = this.s.avciBekleyen!;
    const olumler = this.m().avciVur(av, hedef);
    this.s.avciBekleyen = null;
    this.s.oluler = this.olumKayitlari(olumler);
    ctx.yayin('hunterShot', { hunterId: av, deaths: this.s.oluler });
    this.kazanmaKontrol(ctx, this.s.sonrasi);
  }

  // ------------------------------------------------------------------ kazanma ve gündüz
  private kazanmaKontrol(ctx: OyunBaglami, sonra: 'tartisma' | 'gece'): void {
    const m = this.m();
    if (m.kazanan() !== null) {
      this.bitir(ctx);
      return;
    }
    if (sonra === 'tartisma') ctx.setFaz('TARTISMA', ctx.now() + Number(ctx.ayarlar.tartismaSn) * 1000);
    else this.yeniGece(ctx);
  }

  private oylamaBasla(ctx: OyunBaglami, adaylar: string[] | null): void {
    this.m().oyBaslat();
    this.s.adaylar = adaylar;
    ctx.setFaz('OYLAMA', ctx.now() + OYLAMA_MS);
  }

  private oyVer(ctx: OyunBaglami, o: Player, p: Record<string, unknown>): Sonuc {
    if (ctx.faz() !== 'OYLAMA') return hata('WRONG_PHASE');
    const m = this.m();
    if (!m.canli(o.id)) return hata('NOT_ALIVE');
    const hedef = p.target === null || p.target === undefined ? null : typeof p.target === 'string' ? p.target : undefined;
    if (hedef === undefined) return hata('INVALID_MESSAGE');
    if (hedef !== null) {
      if (!m.canli(hedef)) return hata('INVALID_TARGET');
      if (hedef === o.id) return hata('SELF_TARGET_FORBIDDEN');
      if (this.s.adaylar && !this.s.adaylar.includes(hedef)) return hata('INVALID_TARGET');
    }
    m.oyVer(o.id, hedef);
    ctx.yayin('voteProgress', { votedCount: Object.keys(this.s.motor!.oylar).length, total: m.canlilar.length });
    return TAMAM;
  }

  private oylamaBitir(ctx: OyunBaglami): void {
    const m = this.m();
    const sayim = m.oySayilari();
    const acik = this.s.motor!.ayar.acikOylama;
    const votes = acik ? { ...this.s.motor!.oylar } : null;
    const r = m.oylamayiBitir();
    let eliminatedId: string | null = null;
    let tie = false;
    if (r.olumler.length) {
      eliminatedId = r.olumler[0].id;
      this.s.oluler = this.olumKayitlari(r.olumler);
      this.s.avciBekleyen = r.avci;
    } else {
      this.s.oluler = [];
      if (r.esitAdaylar.length) {
        tie = true;
        if (this.s.motor!.ayar.esitOyYenidenOy && !this.s.yenidenYapildi) {
          this.s.yenidenBekliyor = true;
          this.s.adaylar = r.esitAdaylar;
        }
      }
    }
    const roleShown = eliminatedId && this.s.motor!.ayar.oluncRoluAc ? this.s.motor!.roller[eliminatedId] : null;
    this.s.sonOy = { tally: sayim, eliminatedId, roleShown, votes, tie };
    ctx.setFaz('OYLAMA_SONUC', ctx.now() + OY_SONUC_MS);
    ctx.yayin('voteResult', {
      tally: sayim,
      eliminatedId,
      roleShown,
      votes,
      deaths: this.s.oluler,
      tie,
      revote: this.s.yenidenBekliyor,
    });
  }

  private bitir(ctx: OyunBaglami): void {
    const m = this.m();
    const d = this.s.motor!;
    const yalanci = m.enIyiYalanci();
    const supheci = m.supheci();
    const badges: { badge: string; playerIds: string[] }[] = [];
    if (yalanci) badges.push({ badge: 'bestLiar', playerIds: [yalanci] });
    if (supheci) badges.push({ badge: 'skeptic', playerIds: [supheci] });
    this.s.final = {
      winner: m.kazanan(),
      roles: d.oyuncular.map((id) => ({ id, role: d.roller[id], alive: m.canli(id) })),
      badges,
    };
    ctx.setFaz('FINAL', null);
    ctx.yayin('final', this.s.final);
  }

  // ------------------------------------------------------------------ yapılandırma ve oyuncu olayları
  private rolPaketiAyarla(ctx: OyunBaglami, o: Player, p: Record<string, unknown>): Sonuc {
    if (o.id !== ctx.hostId) return hata('NOT_HOST');
    if (ctx.faz() !== 'LOBBY') return hata('WRONG_PHASE');
    if (p.pack === null) {
      this.s.rolPaketi = null;
    } else {
      const ham = p.pack as Record<string, unknown>;
      if (typeof ham !== 'object' || ham === null) return hata('INVALID_MESSAGE');
      const paket: Record<string, number> = {};
      for (const [k, v] of Object.entries(ham)) {
        if (!ROLLER.includes(k as Rol) || !Number.isInteger(v) || (v as number) < 0 || (v as number) > 20) return hata('INVALID_MESSAGE');
        paket[k] = v as number;
      }
      this.s.rolPaketi = paket;
    }
    ctx.durumYayinla();
    return TAMAM;
  }

  private duraklatmaKomutu(ctx: OyunBaglami, o: Player, t: string): Sonuc {
    if (o.id !== ctx.hostId) return hata('NOT_HOST');
    const dur = this.s.duraklat;
    if (!dur) return hata('WRONG_PHASE');
    this.s.duraklat = null;
    if (t === 'finish') {
      this.bitir(ctx);
    } else {
      ctx.setFaz(dur.faz, ctx.now() + dur.kalanMs);
    }
    return TAMAM;
  }

  oyuncuDegisti(ctx: OyunBaglami, olay: 'join' | 'leave' | 'disconnect' | 'reconnect', _o: Player): void {
    const faz = ctx.faz();
    if (faz === 'LOBBY' || faz === 'FINAL' || faz === 'DURAKLA') return;
    if (olay === 'disconnect' || olay === 'leave') {
      const bagli = ctx.oyuncular().filter((p) => p.connected).length;
      if (bagli < 6) {
        const bitis = ctx.bitisAni();
        this.s.duraklat = { faz, kalanMs: bitis === null ? 1000 : Math.max(1000, bitis - ctx.now()) };
        ctx.setFaz('DURAKLA', null);
      }
    }
  }

  // ------------------------------------------------------------------ görünürlük
  herkeseAcik(ctx: OyunBaglami): unknown {
    const d = this.s.motor;
    const faz = ctx.faz();
    const m = d ? this.m() : null;
    return {
      settings: ctx.ayarlar,
      rolePack: this.s.rolPaketi,
      round: d?.gece ?? 0,
      alive: m ? Object.fromEntries(d!.oyuncular.map((id) => [id, m.canli(id)])) : {},
      deaths: this.s.oluler,
      dawnText: faz === 'SAFAK' ? this.s.sabahMetni : null,
      voteResult: faz === 'OYLAMA_SONUC' ? this.s.sonOy : null,
      votedCount: faz === 'OYLAMA' && d ? Object.keys(d.oylar).length : 0,
      candidates: faz === 'OYLAMA' ? this.s.adaylar : null,
      paused: this.s.duraklat !== null,
      final: faz === 'FINAL' ? this.s.final : null,
    };
  }

  ozel(ctx: OyunBaglami, playerId: string): unknown {
    const d = this.s.motor;
    if (!d || ctx.faz() === 'LOBBY') return null;
    const m = this.m();
    const rol = d.roller[playerId];
    if (!rol) return null;
    const faz = ctx.faz();
    const geceFaz = (GECE_FAZLARI as readonly string[]).includes(faz) ? (faz as GeceFazi) : null;
    return {
      role: rol,
      allies: rol === 'kurt' ? m.kurtlar.filter((x) => x !== playerId) : [],
      loverId: d.ask[playerId] ?? null,
      seerResults: this.s.kahinGecmis[playerId] ?? [],
      potions: rol === 'cadi' ? { heal: d.iyilestirmeVar, poison: d.zehirVar } : null,
      alive: m.canli(playerId),
      nightPrompt: geceFaz ? this.istemOlustur(ctx, playerId, geceFaz) : null,
      myAction: this.s.kilit[playerId] ?? [],
      wolfBoard: rol === 'kurt' && faz === 'GECE_KURT' ? { ...d.kurtOylari } : null,
      witchInfo: rol === 'cadi' && faz === 'GECE_CADI' && m.canli(playerId) ? this.cadiBilgisi() : null,
      hunterPending: this.s.avciBekleyen === playerId && faz === 'AVCI',
      myVote: faz === 'OYLAMA' ? d.oylar[playerId] ?? null : null,
    };
  }
}

export const koyKurtlarTanimi: OyunTanimi = {
  id: '03',
  minOyuncu: 6,
  maxOyuncu: 20,
  gecKatilim: 'kapali',
  varsayilanAyarlar: () => ({
    geceSn: 25,
    tartismaSn: 90,
    oylama: 'acik',
    rolAc: 'evet',
    esit: 'kimse',
    doktorKendini: 'evet',
    seyirciRol: 'gormez',
  }),
  ayarlariDogrula(ham, mevcut): Ayarlar | null {
    const a: Ayarlar = { ...mevcut };
    const sec: Record<string, readonly (string | number)[]> = {
      geceSn: [20, 25, 35],
      tartismaSn: [60, 90, 120, 180],
      oylama: ['acik', 'gizli'],
      rolAc: ['evet', 'hayir'],
      esit: ['kimse', 'yeniden'],
      doktorKendini: ['evet', 'hayir'],
      seyirciRol: ['gorur', 'gormez'],
    };
    for (const [k, v] of Object.entries(ham)) {
      if (!(k in sec) || !sec[k].includes(v as string | number)) return null;
      a[k] = v;
    }
    return a;
  },
  olustur: (_a, dep) => KoyKurtlar.yeni(dep),
  geriYukle: (json, dep) => new KoyKurtlar(json as Durum, dep),
};
