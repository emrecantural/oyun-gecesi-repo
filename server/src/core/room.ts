import { sha256Hex } from './sha256.ts';
import { rastgeleBelirtec, type Rand } from './rng.ts';
import { takmaAdUygun } from './tr.ts';
import type { Ayarlar, Icerik, Oyun, OyunBaglami, OyunTanimi, Player, Role } from '../games/types.ts';
import { oyunTanimi } from '../games/index.ts';

export interface Baglanti {
  send(raw: string): void;
  close(code: number, reason: string): void;
}

export interface OdaBagimliliklari {
  now: () => number;
  rand: Rand;
  icerik: Icerik;
}

const MAX_MESAJ = 8 * 1024;
const HOST_DEVIR_MS = 15_000;
const BOS_ODA_MS = 10 * 60_000;
const AZAMI_OMUR_MS = 6 * 60 * 60_000;
const EMOJILER = ['😀', '😂', '😮', '👏', '🔥', '❤️'];

interface BaglantiKaydi {
  conn: Baglanti;
  playerId: string | null;
  mesajSayisi: number;
}

interface SepetDurumu {
  jeton: number;
  zaman: number;
  ihlal: number;
}

export interface OdaKaydi {
  code: string;
  gameId: string;
  phase: string;
  endsAt: number | null;
  hostId: string;
  seq: number;
  settings: Ayarlar;
  players: Player[];
  game: unknown;
  createdAt: number;
  emptySince: number | null;
  hostLostAt: number | null;
  bannedInstalls: string[];
  closed: boolean;
}

export class Oda {
  code: string;
  def: OyunTanimi;
  phase = 'LOBBY';
  endsAt: number | null = null;
  hostId = '';
  seq = 0;
  settings: Ayarlar;
  players: Player[] = [];
  game: Oyun;
  createdAt: number;
  emptySince: number | null;
  hostLostAt: number | null = null;
  bannedInstalls: string[] = [];
  closed = false;
  reports: { by: string; target: string; reason: string }[] = [];

  private conns = new Map<string, BaglantiKaydi>();
  private byPlayer = new Map<string, string>();
  private sepet = new Map<string, SepetDurumu>();
  private tepki: SepetDurumu = { jeton: 5, zaman: 0, ihlal: 0 };
  private kirli = false;

  private dep: OdaBagimliliklari;

  private constructor(dep: OdaBagimliliklari, code: string, def: OyunTanimi, settings: Ayarlar, game: Oyun) {
    this.dep = dep;
    this.code = code;
    this.def = def;
    this.settings = settings;
    this.game = game;
    this.createdAt = dep.now();
    this.emptySince = this.createdAt;
  }

  /** Oda kur (POST /v1/rooms). Oda sahibi önceden oluşturulur; joinToken onun ilk resumeToken'ıdır. */
  static kur(
    dep: OdaBagimliliklari,
    o: { code: string; game: string; nickname: string; installId: string; settings?: Record<string, unknown> },
  ): { oda: Oda; joinToken: string } | { err: string } {
    const def = oyunTanimi(o.game);
    if (!def) return { err: 'GAME_NOT_ONLINE' };
    const ad = o.nickname.trim();
    if (ad.length < 2 || ad.length > 16 || !takmaAdUygun(ad)) return { err: 'NICKNAME_REJECTED' };
    let ayarlar = def.varsayilanAyarlar();
    if (o.settings) {
      const g = def.ayarlariDogrula(o.settings, ayarlar);
      if (!g) return { err: 'INVALID_MESSAGE' };
      ayarlar = g;
    }
    const oda = new Oda(dep, o.code, def, ayarlar, def.olustur(ayarlar, { rand: dep.rand, icerik: dep.icerik }));
    const joinToken = rastgeleBelirtec(dep.rand);
    const host = oda.yeniOyuncu(ad, 'player', o.installId, joinToken);
    host.connected = false;
    oda.hostId = host.id;
    return { oda, joinToken };
  }

  static geriYukle(dep: OdaBagimliliklari, k: OdaKaydi): Oda {
    const def = oyunTanimi(k.gameId)!;
    const oda = new Oda(dep, k.code, def, k.settings, def.geriYukle(k.game, { rand: dep.rand, icerik: dep.icerik }));
    oda.phase = k.phase;
    oda.endsAt = k.endsAt;
    oda.hostId = k.hostId;
    oda.seq = k.seq;
    oda.players = k.players.map((p) => ({ ...p, connected: false }));
    oda.createdAt = k.createdAt;
    oda.emptySince = k.emptySince;
    oda.hostLostAt = k.hostLostAt;
    oda.bannedInstalls = k.bannedInstalls;
    oda.closed = k.closed;
    return oda;
  }

  toJSON(): OdaKaydi {
    return {
      code: this.code,
      gameId: this.def.id,
      phase: this.phase,
      endsAt: this.endsAt,
      hostId: this.hostId,
      seq: this.seq,
      settings: this.settings,
      players: this.players,
      game: this.game.toJSON(),
      createdAt: this.createdAt,
      emptySince: this.emptySince,
      hostLostAt: this.hostLostAt,
      bannedInstalls: this.bannedInstalls,
      closed: this.closed,
    };
  }

  /** DO her mesajdan sonra çağırır; true ise durumu yazmalı. */
  kaydedilmeli(): boolean {
    const k = this.kirli;
    this.kirli = false;
    return k;
  }

  // ---------------------------------------------------------------- yardımcılar
  private yeniOyuncu(ad: string, role: Role, installId: string, token: string): Player {
    const benzersiz = this.benzersizAd(ad);
    const sira = this.players.length;
    const p: Player = {
      id: rastgeleBelirtec(this.dep.rand).slice(0, 8),
      nickname: benzersiz,
      role,
      connected: true,
      left: false,
      tokenHash: sha256Hex(token),
      installHash: sha256Hex('i:' + installId),
      ready: false,
      seenIds: [],
      shape: sira % 6,
      color: sira % 12,
      joinedAt: this.dep.now(),
      disconnectedAt: null,
    };
    this.players.push(p);
    this.kirli = true;
    return p;
  }

  private benzersizAd(ad: string): string {
    const kullanilan = new Set(this.players.filter((p) => !p.left).map((p) => p.nickname.toLocaleLowerCase('tr')));
    if (!kullanilan.has(ad.toLocaleLowerCase('tr'))) return ad;
    for (let i = 2; i < 100; i++) {
      const aday = `${ad} ${i}`;
      if (!kullanilan.has(aday.toLocaleLowerCase('tr'))) return aday;
    }
    return ad;
  }

  oyuncular(): Player[] {
    return this.players.filter((p) => p.role === 'player' && !p.left);
  }

  private oyuncuBul(id: string): Player | undefined {
    return this.players.find((p) => p.id === id);
  }

  private zarf(t: string, p: unknown, artir: boolean): string {
    if (artir) this.seq++;
    return JSON.stringify({ v: 1, t, seq: this.seq, now: this.dep.now(), p });
  }

  private bagliKayitlar(): BaglantiKaydi[] {
    return [...this.conns.values()].filter((k) => k.playerId !== null);
  }

  yayin(t: string, p: unknown): void {
    const raw = this.zarf(t, p, true);
    for (const k of this.bagliKayitlar()) this.guvenliGonder(k.conn, raw);
  }

  gonder(playerId: string, t: string, p: unknown): void {
    const key = this.byPlayer.get(playerId);
    if (!key) return;
    const k = this.conns.get(key);
    if (k) this.guvenliGonder(k.conn, this.zarf(t, p, false));
  }

  private guvenliGonder(c: Baglanti, raw: string): void {
    try {
      c.send(raw);
    } catch {
      /* kopuk soket: kapanış olayı temizler */
    }
  }

  private hataGonder(c: Baglanti, kod: string, ref?: string): void {
    this.guvenliGonder(c, this.zarf('error', ref ? { code: kod, ref } : { code: kod }, false));
  }

  private rosterIcerik() {
    return {
      players: this.players
        .filter((p) => p.role !== 'display' && !p.left)
        .map((p) => ({
          id: p.id,
          nickname: p.nickname,
          role: p.role,
          shape: p.shape,
          color: p.color,
          connected: p.connected,
          ready: p.ready,
          host: p.id === this.hostId,
        })),
      displays: this.players.filter((p) => p.role === 'display' && p.connected).length,
    };
  }

  private rosterYayinla(): void {
    this.yayin('roster', this.rosterIcerik());
  }

  durumIcerik() {
    return { phase: this.phase, endsAt: this.endsAt, public: this.game.herkeseAcik(this.baglam()) };
  }

  private durumYayinla(): void {
    this.yayin('state', this.durumIcerik());
  }

  private baglam(): OyunBaglami {
    const oda = this;
    return {
      now: () => oda.dep.now(),
      rand: () => oda.dep.rand,
      get ayarlar() {
        return oda.settings;
      },
      get hostId() {
        return oda.hostId;
      },
      oyuncular: () => oda.oyuncular(),
      oyuncu: (id) => oda.oyuncuBul(id),
      faz: () => oda.phase,
      bitisAni: () => oda.endsAt,
      setFaz: (faz, endsAt) => {
        oda.phase = faz;
        oda.endsAt = endsAt;
        oda.kirli = true;
        oda.durumYayinla();
      },
      yayin: (t, p) => oda.yayin(t, p),
      gonder: (id, t, p) => oda.gonder(id, t, p),
      durumYayinla: () => oda.durumYayinla(),
      kaydet: () => {
        oda.kirli = true;
      },
      seyirciler: () => oda.players.filter((p) => p.role === 'spectator' && !p.left),
      oyuncuYap: (id) => {
        const p = oda.oyuncuBul(id);
        if (p && p.role === 'spectator') {
          p.role = 'player';
          oda.kirli = true;
          oda.rosterYayinla();
        }
      },
    };
  }

  private anlikGoruntu(p: Player) {
    return {
      code: this.code,
      game: this.def.id,
      ...this.durumIcerik(),
      private: p.role === 'player' ? this.game.ozel(this.baglam(), p.id) ?? null : null,
      roster: this.rosterIcerik(),
    };
  }

  // ---------------------------------------------------------------- giriş noktaları
  /** Bağlantının sahibi oyuncu (DO soket eki için). */
  baglantiOyuncusu(key: string): string | null {
    return this.conns.get(key)?.playerId ?? null;
  }

  /** DO uyandığında soketi eski oyuncuya yeniden bağlar (Hibernation). */
  yenidenBagla(key: string, conn: Baglanti, playerId: string | null): void {
    this.conns.set(key, { conn, playerId, mesajSayisi: 0 });
    if (playerId) this.byPlayer.set(playerId, key);
  }

  baglantiAc(key: string, conn: Baglanti): void {
    this.conns.set(key, { conn, playerId: null, mesajSayisi: 0 });
  }

  baglantiKapandi(key: string): void {
    const k = this.conns.get(key);
    this.conns.delete(key);
    if (!k || !k.playerId) return;
    if (this.byPlayer.get(k.playerId) !== key) return; // devralınmış
    this.byPlayer.delete(k.playerId);
    const p = this.oyuncuBul(k.playerId);
    if (!p || !p.connected) return;
    p.connected = false;
    p.disconnectedAt = this.dep.now();
    this.kirli = true;
    if (p.id === this.hostId) this.hostLostAt = this.dep.now();
    this.bosKontrol();
    this.rosterYayinla();
    if (p.role === 'player') this.game.oyuncuDegisti(this.baglam(), 'disconnect', p);
  }

  private bosKontrol(): void {
    const bagli = this.players.some((p) => p.connected);
    this.emptySince = bagli ? null : (this.emptySince ?? this.dep.now());
  }

  mesaj(key: string, ham: string): void {
    const k = this.conns.get(key);
    if (!k) return;
    if (ham === 'ping') return;
    if (ham.length > MAX_MESAJ) {
      this.hataGonder(k.conn, 'PAYLOAD_TOO_LARGE');
      return;
    }
    let m: { v?: unknown; t?: unknown; id?: unknown; p?: unknown };
    try {
      m = JSON.parse(ham);
    } catch {
      this.hataGonder(k.conn, 'INVALID_MESSAGE');
      return;
    }
    if (typeof m !== 'object' || m === null || typeof m.t !== 'string') {
      this.hataGonder(k.conn, 'INVALID_MESSAGE');
      return;
    }
    if (m.v !== 1) {
      this.hataGonder(k.conn, 'UPGRADE_REQUIRED');
      k.conn.close(4426, 'UPGRADE_REQUIRED');
      return;
    }
    const id = typeof m.id === 'string' && m.id.length <= 40 ? m.id : undefined;
    const p = (typeof m.p === 'object' && m.p !== null ? m.p : {}) as Record<string, unknown>;
    const t = m.t;

    if (k.playerId === null) {
      k.mesajSayisi++;
      if (k.mesajSayisi > 5) {
        k.conn.close(4429, 'RATE_LIMITED');
        return;
      }
      if (t === 'join') this.katil(key, k, p);
      else if (t === 'resume') this.katil(key, k, { resumeToken: p.resumeToken });
      else this.hataGonder(k.conn, 'INVALID_MESSAGE', id);
      return;
    }

    const oyuncu = this.oyuncuBul(k.playerId);
    if (!oyuncu) {
      k.conn.close(4404, 'ROOM_NOT_FOUND');
      return;
    }
    if (!this.hizSiniri(oyuncu.id)) {
      this.hataGonder(k.conn, 'RATE_LIMITED', id);
      const s = this.sepet.get(oyuncu.id)!;
      if (s.ihlal > 50) k.conn.close(4429, 'RATE_LIMITED');
      return;
    }
    if (id && oyuncu.seenIds.includes(id)) {
      this.guvenliGonder(k.conn, this.zarf('ack', { id }, false));
      return;
    }

    const sonuc = this.dagit(oyuncu, t, p);
    if (id) {
      oyuncu.seenIds.push(id);
      if (oyuncu.seenIds.length > 64) oyuncu.seenIds.shift();
    }
    const gizli = this.game.gizliEylemler.includes(t);
    if (gizli || 'ok' in sonuc) {
      if (id) this.guvenliGonder(k.conn, this.zarf('ack', { id }, false));
    } else {
      this.hataGonder(k.conn, sonuc.err, id);
    }
  }

  private hizSiniri(playerId: string): boolean {
    const simdi = this.dep.now();
    let s = this.sepet.get(playerId);
    if (!s) {
      s = { jeton: 20, zaman: simdi, ihlal: 0 };
      this.sepet.set(playerId, s);
    }
    s.jeton = Math.min(20, s.jeton + ((simdi - s.zaman) / 1000) * 10);
    s.zaman = simdi;
    if (s.jeton < 1) {
      s.ihlal++;
      return false;
    }
    s.jeton -= 1;
    return true;
  }

  // ---------------------------------------------------------------- katılım
  private katil(key: string, k: BaglantiKaydi, p: Record<string, unknown>): void {
    const c = k.conn;
    if (typeof p.code === 'string' && p.code.toUpperCase() !== this.code) {
      this.hataGonder(c, 'ROOM_NOT_FOUND');
      c.close(4404, 'ROOM_NOT_FOUND');
      return;
    }
    if (this.closed) {
      this.hataGonder(c, 'ROOM_NOT_FOUND');
      c.close(4404, 'ROOM_NOT_FOUND');
      return;
    }
    const installId = typeof p.installId === 'string' ? p.installId : '';
    const installHash = sha256Hex('i:' + installId);

    // yeniden bağlanma
    if (typeof p.resumeToken === 'string' && p.resumeToken.length > 0) {
      const h = sha256Hex(p.resumeToken);
      const mevcut = this.players.find((x) => x.tokenHash === h);
      if (!mevcut || mevcut.left) {
        this.hataGonder(c, 'ROOM_NOT_FOUND');
        c.close(4404, 'ROOM_NOT_FOUND');
        return;
      }
      if (this.bannedInstalls.includes(mevcut.installHash)) {
        this.hataGonder(c, 'PLAYER_KICKED');
        c.close(4403, 'PLAYER_KICKED');
        return;
      }
      const eski = this.byPlayer.get(mevcut.id);
      if (eski && eski !== key) {
        const ek = this.conns.get(eski);
        if (ek) {
          this.hataGonder(ek.conn, 'SUPERSEDED');
          this.conns.set(eski, { ...ek, playerId: null });
          ek.conn.close(4001, 'SUPERSEDED');
        }
      }
      k.playerId = mevcut.id;
      this.byPlayer.set(mevcut.id, key);
      const onceBagli = mevcut.connected;
      mevcut.connected = true;
      mevcut.disconnectedAt = null;
      if (mevcut.id === this.hostId) this.hostLostAt = null;
      this.emptySince = null;
      this.kirli = true;
      this.welcome(c, mevcut, undefined);
      this.rosterYayinla();
      if (!onceBagli && mevcut.role === 'player') this.game.oyuncuDegisti(this.baglam(), 'reconnect', mevcut);
      return;
    }

    // yeni katılım
    const role = p.role === 'display' || p.role === 'spectator' ? p.role : 'player';
    const ham = typeof p.nickname === 'string' ? p.nickname : '';
    const ad = ham.trim().replace(/\s+/g, ' ');
    if (ad.length < 2 || ad.length > 16 || !takmaAdUygun(ad)) {
      this.hataGonder(c, 'NICKNAME_REJECTED');
      return;
    }
    if (this.bannedInstalls.includes(installHash)) {
      this.hataGonder(c, 'PLAYER_KICKED');
      c.close(4403, 'PLAYER_KICKED');
      return;
    }
    const basladi = this.phase !== 'LOBBY';
    if (role === 'display') {
      if (this.players.some((x) => x.role === 'display' && x.connected)) {
        this.hataGonder(c, 'ROOM_FULL');
        return;
      }
    } else if (role === 'spectator') {
      if (this.def.gecKatilim !== 'seyirci') {
        this.hataGonder(c, 'LATE_JOIN_CLOSED');
        return;
      }
    } else {
      if (this.oyuncular().length >= this.def.maxOyuncu) {
        this.hataGonder(c, 'ROOM_FULL');
        return;
      }
      if (basladi && this.def.gecKatilim !== 'acik') {
        this.hataGonder(c, 'LATE_JOIN_CLOSED');
        return;
      }
      if (basladi && this.def.gecKatilim === 'acik' && this.settings.gecKatilim === false) {
        this.hataGonder(c, 'LATE_JOIN_CLOSED');
        return;
      }
    }
    const token = rastgeleBelirtec(this.dep.rand);
    const yeni = this.yeniOyuncu(ad, role, installId, token);
    k.playerId = yeni.id;
    this.byPlayer.set(yeni.id, key);
    this.emptySince = null;
    this.welcome(c, yeni, token);
    this.rosterYayinla();
    if (role === 'player') this.game.oyuncuDegisti(this.baglam(), 'join', yeni);
  }

  private welcome(c: Baglanti, p: Player, token: string | undefined): void {
    this.guvenliGonder(
      c,
      this.zarf(
        'welcome',
        {
          playerId: p.id,
          ...(token ? { resumeToken: token } : {}),
          role: p.role,
          hostId: this.hostId,
          settings: this.settings,
          snapshot: this.anlikGoruntu(p),
        },
        false,
      ),
    );
  }

  // ---------------------------------------------------------------- ortak mesajlar
  private dagit(o: Player, t: string, p: Record<string, unknown>): { ok: true } | { err: string } {
    const host = o.id === this.hostId;
    switch (t) {
      case 'ready': {
        if (o.role !== 'player') return { err: 'NOT_PLAYER' };
        if (this.phase !== 'LOBBY') return { err: 'WRONG_PHASE' };
        o.ready = p.ready === true;
        this.kirli = true;
        this.rosterYayinla();
        return { ok: true };
      }
      case 'setSettings': {
        if (!host) return { err: 'NOT_HOST' };
        if (this.phase !== 'LOBBY') return { err: 'WRONG_PHASE' };
        if ('premiumHavuz' in p) return { err: 'INVALID_MESSAGE' };
        const g = this.def.ayarlariDogrula(p, this.settings);
        if (!g) return { err: 'INVALID_MESSAGE' };
        this.settings = g;
        this.kirli = true;
        this.durumYayinla();
        this.yayin('settings', { settings: this.settings });
        return { ok: true };
      }
      case 'start': {
        if (!host) return { err: 'NOT_HOST' };
        if (this.phase !== 'LOBBY') return { err: 'WRONG_PHASE' };
        if (this.oyuncular().length < this.def.minOyuncu) return { err: 'MIN_PLAYERS' };
        const e = this.game.basla(this.baglam());
        if (e) return { err: e };
        this.kirli = true;
        return { ok: true };
      }
      case 'kick': {
        if (!host) return { err: 'NOT_HOST' };
        const hedef = typeof p.playerId === 'string' ? this.oyuncuBul(p.playerId) : undefined;
        if (!hedef || hedef.id === this.hostId) return { err: 'INVALID_TARGET' };
        this.ayril(hedef, true);
        return { ok: true };
      }
      case 'leave': {
        this.ayril(o, false);
        return { ok: true };
      }
      case 'reaction': {
        if (this.game.tepkiAcik && !this.game.tepkiAcik(this.baglam())) return { err: 'REACTION_DISABLED' };
        const e = typeof p.emoji === 'string' ? p.emoji : '';
        if (!EMOJILER.includes(e)) return { err: 'INVALID_MESSAGE' };
        const simdi = this.dep.now();
        this.tepki.jeton = Math.min(5, this.tepki.jeton + ((simdi - this.tepki.zaman) / 1000) * 5);
        this.tepki.zaman = simdi;
        if (this.tepki.jeton < 1) return { err: 'RATE_LIMITED' };
        this.tepki.jeton -= 1;
        this.yayin('reaction', { playerId: o.id, emoji: e });
        return { ok: true };
      }
      case 'reportPlayer': {
        const hedef = typeof p.playerId === 'string' ? p.playerId : '';
        const neden = typeof p.reason === 'string' ? p.reason.slice(0, 40) : '';
        if (this.reports.length < 50) this.reports.push({ by: o.id, target: hedef, reason: neden });
        return { ok: true };
      }
      case 'transferHost': {
        if (!host) return { err: 'NOT_HOST' };
        const hedef = typeof p.playerId === 'string' ? this.oyuncuBul(p.playerId) : undefined;
        if (!hedef || hedef.role !== 'player' || hedef.left) return { err: 'INVALID_TARGET' };
        this.hostDevret(hedef.id);
        return { ok: true };
      }
      case 'rematch': {
        if (!host) return { err: 'NOT_HOST' };
        if (this.phase !== 'FINAL') return { err: 'WRONG_PHASE' };
        this.yenidenOyna();
        return { ok: true };
      }
      default: {
        if (o.role !== 'player') {
          // seyirci/ekran oyun mesajı gönderemez
          return { err: 'NOT_PLAYER' };
        }
        const r = this.game.mesaj(this.baglam(), o, t, p);
        if ('ok' in r) this.kirli = true;
        return r;
      }
    }
  }

  private yenidenOyna(): void {
    this.players = this.players.filter((p) => !p.left);
    for (const p of this.players) p.ready = false;
    this.game = this.def.olustur(this.settings, { rand: this.dep.rand, icerik: this.dep.icerik });
    this.phase = 'LOBBY';
    this.endsAt = null;
    this.kirli = true;
    this.durumYayinla();
    this.rosterYayinla();
    for (const p of this.oyuncular()) {
      this.gonder(p.id, 'private', { kind: 'reset' });
    }
  }

  private ayril(o: Player, atildi: boolean): void {
    const key = this.byPlayer.get(o.id);
    if (atildi) this.bannedInstalls.push(o.installHash);
    if (key) {
      const k = this.conns.get(key);
      if (k) {
        this.hataGonder(k.conn, atildi ? 'PLAYER_KICKED' : 'LEFT');
        this.conns.delete(key);
        k.conn.close(atildi ? 4403 : 1000, atildi ? 'PLAYER_KICKED' : 'LEFT');
      }
      this.byPlayer.delete(o.id);
    }
    o.connected = false;
    o.left = true;
    this.kirli = true;
    if (this.phase === 'LOBBY') {
      this.players = this.players.filter((p) => p.id !== o.id);
    }
    if (o.id === this.hostId) this.hostDevretOtomatik();
    this.bosKontrol();
    this.rosterYayinla();
    if (o.role === 'player') this.game.oyuncuDegisti(this.baglam(), 'leave', o);
  }

  private hostDevret(yeniId: string): void {
    this.hostId = yeniId;
    this.hostLostAt = null;
    this.kirli = true;
    this.yayin('hostChanged', { hostId: yeniId });
    this.rosterYayinla();
  }

  private hostDevretOtomatik(): void {
    const aday = this.oyuncular()
      .filter((p) => p.connected && p.id !== this.hostId)
      .sort((a, b) => a.joinedAt - b.joinedAt)[0];
    if (aday) this.hostDevret(aday.id);
  }

  // ---------------------------------------------------------------- zamanlayıcı
  /** Bir sonraki uyanış anı (alarm). Yoksa null. */
  sonrakiUyanis(): number | null {
    const adaylar: number[] = [];
    if (this.endsAt !== null) adaylar.push(this.endsAt);
    if (this.hostLostAt !== null) adaylar.push(this.hostLostAt + HOST_DEVIR_MS);
    if (this.emptySince !== null) adaylar.push(this.emptySince + BOS_ODA_MS);
    adaylar.push(this.createdAt + AZAMI_OMUR_MS);
    return adaylar.length ? Math.min(...adaylar) : null;
  }

  /** Alarm tetiklendiğinde çağrılır. */
  tik(): void {
    const simdi = this.dep.now();
    if (this.closed) return;
    if (simdi >= this.createdAt + AZAMI_OMUR_MS) {
      this.kapat('MAX_AGE');
      return;
    }
    if (this.emptySince !== null && simdi >= this.emptySince + BOS_ODA_MS) {
      this.kapat('IDLE');
      return;
    }
    if (this.hostLostAt !== null && simdi >= this.hostLostAt + HOST_DEVIR_MS) {
      const eski = this.hostId;
      this.hostDevretOtomatik();
      if (this.hostId === eski) this.hostLostAt = null; // aday yok; sonsuz alarm olmasın
    }
    if (this.endsAt !== null && simdi >= this.endsAt) {
      this.game.tik(this.baglam());
      this.kirli = true;
      // Oyun bir sonraki bitişi ilerletmediyse alarmın sonsuza dek tekrarlamasını önle.
      if (this.endsAt !== null && this.endsAt <= simdi) this.endsAt = null;
    }
  }

  private kapat(neden: string): void {
    this.yayin('closed', { reason: neden });
    this.closed = true;
    this.kirli = true;
    for (const k of this.conns.values()) {
      try {
        k.conn.close(1000, neden);
      } catch {
        /* yoksay */
      }
    }
    this.conns.clear();
    this.byPlayer.clear();
  }

  hostBitir(): void {
    this.kapat('HOST_ENDED');
  }

  /** GET /v1/rooms/{code} */
  ozet() {
    return {
      game: this.def.id,
      playerCount: this.oyuncular().length,
      max: this.def.maxOyuncu,
      phase: this.phase,
      joinable: !this.closed && this.oyuncular().length < this.def.maxOyuncu,
      minVersion: 1,
    };
  }
}
