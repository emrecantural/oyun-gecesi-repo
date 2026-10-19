import { odaKodu, guvenliRand } from './core/rng.ts';
import { oyunTanimi } from './games/index.ts';
import type { Env } from './odaNesnesi.ts';

import { gecisBozdur, kimlikOzeti, kurulumuSil } from './gecis.ts';
import { GooglePlay } from './play.ts';

export { OdaNesnesi } from './odaNesnesi.ts';
export { GecisNesnesi } from './gecisNesnesi.ts';

const KOD_RE = /^[2-9A-HJKMNP-Z]{6}$/;

function json(veri: unknown, status = 200): Response {
  return Response.json(veri, { status });
}

/** İstemci ayarları + (yalnız 07) kurucunun premium bildirimi. Premium doğrulaması istemci tarafıdır (kabul edilen risk, mobil-yayin §4.2). */
function odaAyarlari(game: string, b: Record<string, unknown>): Record<string, unknown> | undefined {
  const temel = typeof b.settings === 'object' && b.settings !== null ? { ...(b.settings as Record<string, unknown>) } : {};
  delete temel.premiumHavuz;
  if (game === '07') temel.premiumHavuz = b.premium === true;
  return Object.keys(temel).length ? temel : undefined;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const yol = url.pathname;

    if (yol === '/v1/health') return json({ v: 1, minClient: '0.1.0' });

    if (yol === '/v1/rooms' && request.method === 'POST') {
      let b: Record<string, unknown>;
      try {
        b = (await request.json()) as Record<string, unknown>;
      } catch {
        return json({ error: 'INVALID_MESSAGE' }, 400);
      }
      const game = typeof b.game === 'string' ? b.game : '';
      if (!oyunTanimi(game)) return json({ error: 'GAME_NOT_ONLINE' }, 400);
      if (typeof b.installId !== 'string' || b.installId.length < 8 || b.installId.length > 64) {
        return json({ error: 'INVALID_MESSAGE' }, 400);
      }
      // Oda hakkı: geliştirme kapısı, geçerli 4 saatlik geçiş (passToken) ya da kurulum başına bir ücretsiz deneme (D-022).
      const defter = env.GECIS.get(env.GECIS.idFromName('defter'));
      const install = kimlikOzeti(b.installId);
      const passToken = typeof b.passToken === 'string' ? b.passToken : undefined;
      const hak = env.GECIS_KAPISI === 'acik' ? null : await defter.bak(passToken, install);
      if (env.GECIS_KAPISI !== 'acik' && hak === null) return json({ error: 'NO_ROOM_RIGHT' }, 402);
      const rand = guvenliRand();
      for (let deneme = 0; deneme < 5; deneme++) {
        const code = odaKodu(rand);
        const stub = env.ODA.get(env.ODA.idFromName(code));
        const r = await stub.fetch('https://oda/init', {
          method: 'POST',
          body: JSON.stringify({
            code,
            game,
            nickname: typeof b.nickname === 'string' ? b.nickname : '',
            installId: b.installId,
            settings: odaAyarlari(game, b),
          }),
        });
        if (r.status === 409) continue;
        if (!r.ok) return json(await r.json(), r.status);
        const { joinToken } = (await r.json()) as { joinToken: string };
        if (hak !== null) await defter.kullan(hak, passToken, install);
        return json(
          { code, joinToken, wsUrl: `wss://${url.host}/v1/ws/${code}`, role: 'host', expiresAt: Date.now() + 6 * 3600_000 },
          201,
        );
      }
      return json({ error: 'INTERNAL' }, 500);
    }

    if (yol === '/v1/passes/redeem' && request.method === 'POST') {
      // Hizmet hesabı yapılandırılana dek kapalı (Play hesabı kullanıcıda).
      if (!env.PLAY_HIZMET_HESABI || !env.PLAY_PAKET) return json({ error: 'PURCHASE_INVALID' }, 501);
      let g: Record<string, unknown>;
      try {
        g = (await request.json()) as Record<string, unknown>;
      } catch {
        return json({ error: 'INVALID_MESSAGE' }, 400);
      }
      const defter = env.GECIS.get(env.GECIS.idFromName('defter'));
      const y = await gecisBozdur(g, new GooglePlay(env.PLAY_HIZMET_HESABI, env.PLAY_PAKET), defter);
      return json(y.body, y.status);
    }

    if (yol === '/v1/installs' && request.method === 'DELETE') {
      let g: Record<string, unknown>;
      try {
        g = (await request.json()) as Record<string, unknown>;
      } catch {
        return json({ error: 'INVALID_MESSAGE' }, 400);
      }
      const defter = env.GECIS.get(env.GECIS.idFromName('defter'));
      const y = await kurulumuSil(g, defter);
      return json(y.body, y.status);
    }

    const oda = /^\/v1\/rooms\/([A-Za-z0-9]{6})$/.exec(yol);
    if (oda && request.method === 'GET') {
      const code = oda[1].toUpperCase();
      if (!KOD_RE.test(code)) return json({ error: 'ROOM_NOT_FOUND' }, 404);
      return env.ODA.get(env.ODA.idFromName(code)).fetch('https://oda/ozet');
    }

    const ws = /^\/v1\/ws\/([A-Za-z0-9]{6})$/.exec(yol);
    if (ws) {
      if (request.headers.get('Upgrade') !== 'websocket') return new Response('upgrade required', { status: 426 });
      const code = ws[1].toUpperCase();
      if (!KOD_RE.test(code)) return json({ error: 'ROOM_NOT_FOUND' }, 404);
      return env.ODA.get(env.ODA.idFromName(code)).fetch(new Request('https://oda/ws', request));
    }

    return json({ error: 'NOT_FOUND' }, 404);
  },
};
