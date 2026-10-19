import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  GECIS_SURESI_MS,
  GecisDefteri,
  gecisBozdur,
  kurulumuSil,
  kimlikOzeti,
  URUN_ID,
  type Depo,
  type PlayIstemcisi,
  type SatinAlma,
} from '../src/gecis.ts';

class BellekDepo implements Depo {
  m = new Map<string, unknown>();
  async get<T>(k: string) {
    return this.m.get(k) as T | undefined;
  }
  async put(k: string, v: unknown) {
    this.m.set(k, structuredClone(v));
  }
  async delete(k: string) {
    return this.m.delete(k);
  }
}

const KIMLIK = 'kurulum-0123456789';
const TOKEN = 'purchase-token-abcdef';

function sahtePlay(s: SatinAlma) {
  const tuketilen: string[] = [];
  const play: PlayIstemcisi = {
    al: async () => s,
    tuket: async (t) => void tuketilen.push(t),
  };
  return { play, tuketilen };
}

test('geçerli satın alma geçişe çevrilir, tüketilir, tekrar aynı geçiş döner', async () => {
  const d = new GecisDefteri(new BellekDepo(), () => 1000);
  const { play, tuketilen } = sahtePlay({ durum: 'PURCHASED', hesap: kimlikOzeti(KIMLIK) });
  const g = { purchaseToken: TOKEN, productId: URUN_ID, installId: KIMLIK };
  const a = await gecisBozdur(g, play, d);
  const b = await gecisBozdur(g, play, d);
  assert.equal(a.status, 200);
  assert.deepEqual(a.body, b.body);
  assert.equal(tuketilen.length, 2);
});

test('hesap eşleşmezse ACCOUNT_MISMATCH, bekleyen satın alma PURCHASE_PENDING, geçersiz PURCHASE_INVALID', async () => {
  const d = new GecisDefteri(new BellekDepo());
  const g = { purchaseToken: TOKEN, productId: URUN_ID, installId: KIMLIK };
  assert.equal((await gecisBozdur(g, sahtePlay({ durum: 'PURCHASED', hesap: 'baska' }).play, d)).status, 403);
  assert.equal((await gecisBozdur(g, sahtePlay({ durum: 'PENDING' }).play, d)).status, 402);
  assert.equal((await gecisBozdur(g, sahtePlay({ durum: 'INVALID' }).play, d)).status, 400);
  assert.equal((await gecisBozdur({ ...g, productId: 'baska' }, sahtePlay({ durum: 'INVALID' }).play, d)).status, 400);
});

test('başka kurulum aynı token ile TOKEN_ALREADY_USED alır', async () => {
  const d = new GecisDefteri(new BellekDepo());
  const g1 = { purchaseToken: TOKEN, productId: URUN_ID, installId: KIMLIK };
  await gecisBozdur(g1, sahtePlay({ durum: 'PURCHASED', hesap: kimlikOzeti(KIMLIK) }).play, d);
  const diger = 'baska-kurulum-99';
  const r = await gecisBozdur(
    { ...g1, installId: diger },
    sahtePlay({ durum: 'PURCHASED', hesap: kimlikOzeti(diger) }).play,
    d,
  );
  assert.equal(r.status, 409);
});

test('Play hatasında 503; tüketim hatası geçişi bozmaz', async () => {
  const d = new GecisDefteri(new BellekDepo());
  const g = { purchaseToken: TOKEN, productId: URUN_ID, installId: KIMLIK };
  const bozuk: PlayIstemcisi = { al: async () => { throw new Error('x'); }, tuket: async () => {} };
  assert.equal((await gecisBozdur(g, bozuk, d)).status, 503);
  const tuketmez: PlayIstemcisi = {
    al: async () => ({ durum: 'PURCHASED', hesap: kimlikOzeti(KIMLIK) }),
    tuket: async () => { throw new Error('t'); },
  };
  assert.equal((await gecisBozdur(g, tuketmez, d)).status, 200);
});

test('ilk oda ücretsiz deneme: bir kez; sonra hak yok', async () => {
  const d = new GecisDefteri(new BellekDepo());
  const i = kimlikOzeti(KIMLIK);
  const hak = await d.bak(undefined, i);
  assert.equal(hak, 'deneme');
  await d.kullan(hak, undefined, i);
  assert.equal(await d.bak(undefined, i), null);
  assert.equal(await d.bak(undefined, kimlikOzeti('baska-kurulum-99')), 'deneme');
});

test('geçiş: ilk odadan sonra 4 saat içinde çok oda açılır, sonra kapanır', async () => {
  let t = 1000;
  const d = new GecisDefteri(new BellekDepo(), () => t);
  const i = kimlikOzeti(KIMLIK);
  const r = await d.redeem('a'.repeat(64), i);
  assert.ok(r.ok);
  const id = r.ok ? r.pass.id : '';
  // deneme hakkı bitmiş olsun
  await d.kullan('deneme', undefined, i);
  assert.equal(await d.bak(id, i), 'pass');
  await d.kullan('pass', id, i);
  t += GECIS_SURESI_MS - 1;
  assert.equal(await d.bak(id, i), 'pass');
  t += 2;
  assert.equal(await d.bak(id, i), null);
});

test('geçiş başka kuruluma ait olamaz; 30 gün bekleyen geçiş süresi dolar', async () => {
  let t = 0;
  const d = new GecisDefteri(new BellekDepo(), () => t);
  const i = kimlikOzeti(KIMLIK);
  const r = await d.redeem('b'.repeat(64), i);
  const id = r.ok ? r.pass.id : '';
  await d.kullan('deneme', undefined, i);
  assert.equal(await d.bak(id, kimlikOzeti('baska-kurulum-99')), 'deneme');
  t += 31 * 24 * 3600_000;
  assert.equal(await d.bak(id, i), null);
});

test('kimlik özeti SHA-256 vektörü (istemci ile aynı)', () => {
  assert.equal(kimlikOzeti('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
});

test('kurulum silme: deneme kaydı kalkar, geçersiz kimlik 400', async () => {
  const d = new GecisDefteri(new BellekDepo());
  const i = kimlikOzeti(KIMLIK);
  await d.kullan('deneme', undefined, i);
  assert.equal(await d.bak(undefined, i), null);
  assert.equal((await kurulumuSil({ installId: KIMLIK }, d)).status, 200);
  assert.equal(await d.bak(undefined, i), 'deneme');
  assert.equal((await kurulumuSil({ installId: 'x' }, d)).status, 400);
});
