import type { Rand } from '../core/rng.ts';

export type Role = 'player' | 'display' | 'spectator';

export interface Player {
  id: string;
  nickname: string;
  role: Role;
  connected: boolean;
  left: boolean;
  tokenHash: string;
  installHash: string;
  ready: boolean;
  seenIds: string[];
  shape: number;
  color: number;
  joinedAt: number;
  disconnectedAt: number | null;
}

/** Oyun içeriği (CSV'den üretilir; yalnız onaylı satırlar, ya da ICERIK_TASLAK ile taslak). */
export interface Soru07 {
  id: string;
  metin: string;
  kategori: string;
  /** Paket planına göre ücretsiz havuzda mı; belirtilmemişse ücretsiz sayılır. */
  ucretsiz?: boolean;
}
export interface Icerik {
  soru07: Soru07[];
}

export interface OyunBagimliliklari {
  rand: Rand;
  icerik: Icerik;
}

export type Sonuc = { ok: true } | { err: string };
export const TAMAM: Sonuc = { ok: true };
export const hata = (kod: string): Sonuc => ({ err: kod });

export type Ayarlar = Record<string, unknown>;

export interface OyunBaglami {
  now(): number;
  rand(): Rand;
  readonly ayarlar: Ayarlar;
  readonly hostId: string;
  /** Oyuncular (role=player, ayrılmayanlar), katılma sırasıyla. */
  oyuncular(): Player[];
  oyuncu(id: string): Player | undefined;
  faz(): string;
  bitisAni(): number | null;
  setFaz(faz: string, endsAt: number | null): void;
  /** Herkese (ekran + seyirci dahil) mesaj; seq artar. */
  yayin(t: string, p: unknown): void;
  /** Yalnız oyuncuya. */
  gonder(playerId: string, t: string, p: unknown): void;
  /** Yalnız ekran/seyirci dahil, gizli bilgi taşımayan genel durumu yeniden yayınlar. */
  durumYayinla(): void;
  kaydet(): void;
  /** Seyirciyi oyuncuya yükseltir (07: sonraki soruda). */
  seyirciler(): Player[];
  oyuncuYap(id: string): void;
}

export interface Oyun {
  /** Gizli rol eylemi sayılan mesaj türleri: hata yerine daima ack döner (A15). */
  readonly gizliEylemler: readonly string[];
  basla(ctx: OyunBaglami): string | null;
  mesaj(ctx: OyunBaglami, oyuncu: Player, t: string, p: Record<string, unknown>): Sonuc;
  tik(ctx: OyunBaglami): void;
  herkeseAcik(ctx: OyunBaglami): unknown;
  ozel(ctx: OyunBaglami, playerId: string): unknown;
  /** Oyuncu girdi/çıktı/kopma/dönüş. */
  oyuncuDegisti(ctx: OyunBaglami, olay: 'join' | 'leave' | 'disconnect' | 'reconnect', o: Player): void;
  /** Tepki (emoji) bu fazda açık mı? Tanımlı değilse açık. */
  tepkiAcik?(ctx: OyunBaglami): boolean;
  toJSON(): unknown;
}

export interface OyunTanimi {
  id: string;
  minOyuncu: number;
  maxOyuncu: number;
  /** Oyun başladıktan sonra: 'kapali' | 'seyirci' (oyuncu olarak girilemez) | 'acik'. */
  gecKatilim: 'kapali' | 'seyirci' | 'acik';
  varsayilanAyarlar(): Ayarlar;
  /** Gelen ayarları doğrular; geçersizse null. */
  ayarlariDogrula(ham: Record<string, unknown>, mevcut: Ayarlar): Ayarlar | null;
  olustur(ayarlar: Ayarlar, dep: OyunBagimliliklari): Oyun;
  geriYukle(json: unknown, dep: OyunBagimliliklari): Oyun;
}
