// Google Play Developer API (androidpublisher v3) istemcisi. Hizmet hesabı anahtarı yalnız Worker gizli değişkenindedir.
// NOT: Gerçek Play hesabıyla henüz denenmedi; sözleşme (alan adları) resmi belgeye göre yazıldı.
import type { PlayIstemcisi, SatinAlma } from './gecis.ts';

const b64url = (b: ArrayBuffer | string): string => {
  const bytes = typeof b === 'string' ? new TextEncoder().encode(b) : new Uint8Array(b);
  let s = '';
  for (const x of bytes) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

function pemToDer(pem: string): ArrayBuffer {
  const govde = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const ikili = atob(govde);
  const out = new Uint8Array(ikili.length);
  for (let i = 0; i < ikili.length; i++) out[i] = ikili.charCodeAt(i);
  return out.buffer;
}

interface HizmetHesabi {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export class GooglePlay implements PlayIstemcisi {
  private erisim: { jeton: string; bitis: number } | null = null;
  private readonly hesap: HizmetHesabi;
  private readonly paket: string;
  private readonly getir: typeof fetch;

  constructor(hesapJson: string, paket: string, getir: typeof fetch = fetch) {
    this.hesap = JSON.parse(hesapJson) as HizmetHesabi;
    this.paket = paket;
    this.getir = getir;
  }

  private async jeton(): Promise<string> {
    const simdi = Math.floor(Date.now() / 1000);
    if (this.erisim && this.erisim.bitis - 60 > simdi) return this.erisim.jeton;
    const tokenUri = this.hesap.token_uri ?? 'https://oauth2.googleapis.com/token';
    const baslik = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const iddia = b64url(
      JSON.stringify({
        iss: this.hesap.client_email,
        scope: 'https://www.googleapis.com/auth/androidpublisher',
        aud: tokenUri,
        iat: simdi,
        exp: simdi + 3600,
      }),
    );
    const anahtar = await crypto.subtle.importKey(
      'pkcs8',
      pemToDer(this.hesap.private_key),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const imza = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', anahtar, new TextEncoder().encode(`${baslik}.${iddia}`));
    const r = await this.getir(tokenUri, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${baslik}.${iddia}.${b64url(imza)}`,
      }),
    });
    if (!r.ok) throw new Error('PLAY_AUTH');
    const j = (await r.json()) as { access_token: string; expires_in: number };
    this.erisim = { jeton: j.access_token, bitis: simdi + j.expires_in };
    return j.access_token;
  }

  private adres(token: string, urunId: string): string {
    return (
      'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
      `${encodeURIComponent(this.paket)}/purchases/products/${encodeURIComponent(urunId)}/tokens/${encodeURIComponent(token)}`
    );
  }

  async al(token: string, urunId: string): Promise<SatinAlma> {
    const r = await this.getir(this.adres(token, urunId), {
      headers: { authorization: `Bearer ${await this.jeton()}` },
    });
    if (r.status === 400 || r.status === 404 || r.status === 410) return { durum: 'INVALID' };
    if (!r.ok) throw new Error('PLAY_HATA');
    const j = (await r.json()) as {
      purchaseState?: number;
      consumptionState?: number;
      obfuscatedExternalAccountId?: string;
    };
    // purchaseState: 0 satın alındı, 1 iptal, 2 beklemede. consumptionState 1 = zaten tüketilmiş.
    if (j.purchaseState === 2) return { durum: 'PENDING' };
    if (j.purchaseState !== 0) return { durum: 'INVALID' };
    return { durum: 'PURCHASED', hesap: j.obfuscatedExternalAccountId };
  }

  async tuket(token: string, urunId: string): Promise<void> {
    const r = await this.getir(`${this.adres(token, urunId)}:consume`, {
      method: 'POST',
      headers: { authorization: `Bearer ${await this.jeton()}` },
    });
    if (!r.ok && r.status !== 400) throw new Error('PLAY_TUKET');
  }
}
