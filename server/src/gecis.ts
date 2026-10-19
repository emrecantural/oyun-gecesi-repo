// 4 saatlik oda geçişi + ilk oda ücretsiz deneme (mobil-yayin §4.3, api-sozlesmesi §3).
// Saf mantık: depo ve Play istemcisi enjekte edilir (Workers'a bağımlı değil, node:test ile sınanır).
import { sha256Hex } from './core/sha256.ts';

export const URUN_ID = 'oda_gecisi_4s';
export const GECIS_SURESI_MS = 4 * 3600_000;
/** Satın alınıp oda açılmamış geçiş sunucuda 30 gün bekler (kayıp riski önlemi). */
export const BEKLEME_MS = 30 * 24 * 3600_000;

export interface Depo {
  get<T>(anahtar: string): Promise<T | undefined>;
  put(anahtar: string, deger: unknown): Promise<void>;
}

export interface SatinAlma {
  durum: 'PURCHASED' | 'PENDING' | 'INVALID';
  /** BillingFlowParams.obfuscatedAccountId: istemci kurulum kimliğinin SHA-256 özeti. */
  hesap?: string;
}

export interface PlayIstemcisi {
  al(token: string, urunId: string): Promise<SatinAlma>;
  tuket(token: string, urunId: string): Promise<void>;
}

interface GecisKaydi {
  id: string;
  install: string;
  usableUntil: number;
  /** İlk oda açılışı; 4 saatlik pencere buradan başlar. */
  ilk?: number;
}

export type RedeemSonucu =
  | { ok: true; pass: { id: string; usableUntil: number } }
  | { ok: false; hata: 'TOKEN_ALREADY_USED' };

export type OdaHakki = 'pass' | 'deneme' | null;

/** Kurulum kimliği ve token'lar yalnız özet olarak saklanır. */
export const kimlikOzeti = (installId: string): string => sha256Hex(installId);

export class GecisDefteri {
  private readonly depo: Depo;
  private readonly now: () => number;

  constructor(depo: Depo, now: () => number = Date.now) {
    this.depo = depo;
    this.now = now;
  }

  /** Doğrulanmış bir satın almayı geçişe çevirir; aynı token tekrar gelirse aynı geçiş döner (idempotent). */
  async redeem(tokenOzeti: string, installOzeti: string): Promise<RedeemSonucu> {
    const id = tokenOzeti.slice(0, 32);
    const var_ = await this.depo.get<GecisKaydi>(`p:${id}`);
    if (var_) {
      if (var_.install !== installOzeti) return { ok: false, hata: 'TOKEN_ALREADY_USED' };
      return { ok: true, pass: { id: var_.id, usableUntil: var_.usableUntil } };
    }
    const kayit: GecisKaydi = { id, install: installOzeti, usableUntil: this.now() + BEKLEME_MS };
    await this.depo.put(`p:${id}`, kayit);
    return { ok: true, pass: { id, usableUntil: kayit.usableUntil } };
  }

  /** Oda açma hakkı var mı? Tüketmez; başarılı oda kurulumundan sonra [kullan] çağrılır. */
  async bak(passId: string | undefined, installOzeti: string): Promise<OdaHakki> {
    if (passId) {
      const k = await this.depo.get<GecisKaydi>(`p:${passId}`);
      if (k && k.install === installOzeti && this.now() < k.usableUntil) {
        if (k.ilk === undefined || this.now() < k.ilk + GECIS_SURESI_MS) return 'pass';
      }
    }
    if (!(await this.depo.get<boolean>(`d:${installOzeti}`))) return 'deneme';
    return null;
  }

  async kullan(hak: OdaHakki, passId: string | undefined, installOzeti: string): Promise<void> {
    if (hak === 'pass' && passId) {
      const k = await this.depo.get<GecisKaydi>(`p:${passId}`);
      if (k && k.ilk === undefined) {
        k.ilk = this.now();
        await this.depo.put(`p:${passId}`, k);
      }
    } else if (hak === 'deneme') {
      await this.depo.put(`d:${installOzeti}`, true);
    }
  }
}

export interface RedeemGirdi {
  purchaseToken?: unknown;
  productId?: unknown;
  installId?: unknown;
}

export interface Yanit {
  status: number;
  body: unknown;
}

/** POST /v1/passes/redeem iş akışı: doğrula → kaydet → tüket (tüketim başarısızsa geçiş yine geçerli, Google 3 günde iade eder). */
export async function gecisBozdur(
  girdi: RedeemGirdi,
  play: PlayIstemcisi,
  defter: Pick<GecisDefteri, 'redeem'>,
): Promise<Yanit> {
  const token = girdi.purchaseToken;
  const kimlik = girdi.installId;
  if (
    typeof token !== 'string' || token.length < 10 || token.length > 4096 ||
    girdi.productId !== URUN_ID ||
    typeof kimlik !== 'string' || kimlik.length < 8 || kimlik.length > 64
  ) {
    return { status: 400, body: { error: 'PURCHASE_INVALID' } };
  }
  let s: SatinAlma;
  try {
    s = await play.al(token, URUN_ID);
  } catch {
    return { status: 503, body: { error: 'INTERNAL' } };
  }
  if (s.durum === 'PENDING') return { status: 402, body: { error: 'PURCHASE_PENDING' } };
  if (s.durum !== 'PURCHASED') return { status: 400, body: { error: 'PURCHASE_INVALID' } };
  const install = kimlikOzeti(kimlik);
  if (s.hesap !== install) return { status: 403, body: { error: 'ACCOUNT_MISMATCH' } };
  const r = await defter.redeem(sha256Hex(token), install);
  if (!r.ok) return { status: 409, body: { error: r.hata } };
  try {
    await play.tuket(token, URUN_ID);
  } catch {
    /* tüketim yeniden denenebilir; kayıt idempotent */
  }
  return { status: 200, body: { pass: r.pass } };
}
