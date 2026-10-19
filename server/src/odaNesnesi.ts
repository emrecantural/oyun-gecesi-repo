import { DurableObject } from 'cloudflare:workers';
import { Oda, type Baglanti, type OdaKaydi } from './core/room.ts';
import { guvenliRand } from './core/rng.ts';
import { ICERIK } from './icerik_uretilen.ts';

export interface Env {
  ODA: DurableObjectNamespace;
  /** 'acik': oda kurma kapısı kapalı (geliştirme). Üretimde satın alma doğrulaması gerekir. */
  GECIS_KAPISI?: string;
}

interface SoketEki {
  key: string;
}

function sarmala(ws: WebSocket): Baglanti {
  return {
    send: (s) => ws.send(s),
    close: (code, reason) => ws.close(code, reason),
  };
}

/** Oda başına bir Durable Object. Durum faz geçişlerinde ve her durum değiştiren mesajda SQLite'a yazılır. */
export class OdaNesnesi extends DurableObject<Env> {
  private oda: Oda | null = null;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }

  private bagimlilik() {
    return { now: () => Date.now(), rand: guvenliRand(), icerik: ICERIK };
  }

  private async yukle(): Promise<Oda | null> {
    if (this.oda) return this.oda;
    const k = await this.ctx.storage.get<OdaKaydi>('oda');
    if (!k) return null;
    const oda = Oda.geriYukle(this.bagimlilik(), k);
    for (const ws of this.ctx.getWebSockets()) {
      const ek = ws.deserializeAttachment() as SoketEki | null;
      if (!ek) continue;
      // Hibernation sonrası: soketi oyuncusuna yeniden bağla.
      const playerId = (await this.ctx.storage.get<Record<string, string>>('soket'))?.[ek.key] ?? null;
      oda.yenidenBagla(ek.key, sarmala(ws), playerId);
      if (playerId) {
        const p = oda.players.find((x) => x.id === playerId);
        if (p) p.connected = true;
      }
    }
    this.oda = oda;
    return oda;
  }

  private async kaydet(oda: Oda): Promise<void> {
    if (oda.closed) {
      for (const ws of this.ctx.getWebSockets()) {
        try {
          ws.close(1000, 'closed');
        } catch {
          /* yoksay */
        }
      }
      await this.ctx.storage.deleteAlarm();
      await this.ctx.storage.deleteAll();
      this.oda = null;
      return;
    }
    if (oda.kaydedilmeli()) await this.ctx.storage.put('oda', oda.toJSON());
    const w = oda.sonrakiUyanis();
    if (w !== null) await this.ctx.storage.setAlarm(Math.max(w, Date.now() + 50));
  }

  private async soketHaritasi(oda: Oda): Promise<void> {
    const harita: Record<string, string> = {};
    for (const ws of this.ctx.getWebSockets()) {
      const ek = ws.deserializeAttachment() as SoketEki | null;
      if (!ek) continue;
      const id = oda.baglantiOyuncusu(ek.key);
      if (id) harita[ek.key] = id;
    }
    await this.ctx.storage.put('soket', harita);
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === '/init' && request.method === 'POST') {
      if (await this.ctx.storage.get('oda')) return new Response('exists', { status: 409 });
      const b = (await request.json()) as {
        code: string;
        game: string;
        nickname: string;
        installId: string;
        settings?: Record<string, unknown>;
      };
      const r = Oda.kur(this.bagimlilik(), b);
      if ('err' in r) return Response.json({ error: r.err }, { status: 400 });
      this.oda = r.oda;
      await this.ctx.storage.put('oda', r.oda.toJSON());
      r.oda.kaydedilmeli();
      await this.ctx.storage.setAlarm(Date.now() + 10 * 60_000);
      return Response.json({ joinToken: r.joinToken });
    }
    const oda = await this.yukle();
    if (!oda || oda.closed) return Response.json({ error: 'ROOM_NOT_FOUND' }, { status: 404 });
    if (url.pathname === '/ozet') return Response.json(oda.ozet());
    if (url.pathname === '/ws') {
      if (request.headers.get('Upgrade') !== 'websocket') return new Response('upgrade required', { status: 426 });
      const cift = new WebSocketPair();
      const [istemci, sunucu] = [cift[0], cift[1]];
      const key = crypto.randomUUID();
      this.ctx.acceptWebSocket(sunucu);
      sunucu.serializeAttachment({ key } satisfies SoketEki);
      oda.baglantiAc(key, sarmala(sunucu));
      return new Response(null, { status: 101, webSocket: istemci });
    }
    return new Response('not found', { status: 404 });
  }

  async webSocketMessage(ws: WebSocket, mesaj: string | ArrayBuffer): Promise<void> {
    const oda = await this.yukle();
    const ek = ws.deserializeAttachment() as SoketEki | null;
    if (!oda || !ek) {
      ws.close(4404, 'ROOM_NOT_FOUND');
      return;
    }
    if (typeof mesaj !== 'string') return;
    oda.mesaj(ek.key, mesaj);
    await this.soketHaritasi(oda);
    await this.kaydet(oda);
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    const oda = await this.yukle();
    const ek = ws.deserializeAttachment() as SoketEki | null;
    if (!oda || !ek) return;
    oda.baglantiKapandi(ek.key);
    await this.soketHaritasi(oda);
    await this.kaydet(oda);
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    await this.webSocketClose(ws);
  }

  async alarm(): Promise<void> {
    const oda = await this.yukle();
    if (!oda) return;
    oda.tik();
    await this.kaydet(oda);
  }
}
