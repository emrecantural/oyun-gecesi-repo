import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { KoyHatasi, KoyMotoru, type Rol } from '../src/games/koyMotoru.ts';

const veri = JSON.parse(readFileSync(new URL('../../golden/koy_vektorler.json', import.meta.url), 'utf8'));

function olumler(o: { id: string; neden: string }[]) {
  return o.map((x) => [Number(x.id), x.neden]);
}

for (const v of veri.vektorler) {
  test(`altın vektör: ${v.ad}`, () => {
    const ids = Array.from({ length: v.n }, (_, i) => String(i + 1));
    const ayar = { acikOylama: true, oluncRoluAc: true, esitOyYenidenOy: false, doktorKendiniKorur: true, ...v.ayar };
    let m: KoyMotoru;
    try {
      m = KoyMotoru.yeni({ oyuncular: ids, ayar, rolDagitimi: v.roller as Rol[] });
    } catch (e) {
      assert.equal((e as KoyHatasi).kod, v.bekleHata);
      return;
    }
    assert.equal(v.bekleHata, undefined);
    for (const a of v.adimlar) {
      const id = (x: number) => String(x);
      const calis = () => {
        switch (a.op) {
          case 'gece': return m.geceBasla();
          case 'kurtOyu': return m.kurtOyu(id(a.actor), id(a.hedef));
          case 'koru': return m.koru(id(a.actor), id(a.hedef));
          case 'kahin': return m.kahinSorgula(id(a.actor), id(a.hedef));
          case 'iyilestir': return m.cadiIyilestir(id(a.actor));
          case 'zehirle': return m.cadiZehirle(id(a.actor), id(a.hedef));
          case 'coz': return m.geceyiCoz();
          case 'oyBaslat': return m.oyBaslat();
          case 'oyVer': return m.oyVer(id(a.voter), a.hedef === null ? null : id(a.hedef));
          case 'oyBitir': return m.oylamayiBitir();
          case 'avciVur': return m.avciVur(id(a.actor), a.hedef === null ? null : id(a.hedef));
          case 'kazanan': return m.kazanan();
          default: throw new Error('bilinmeyen op ' + a.op);
        }
      };
      if (a.hata) {
        assert.throws(calis, (e: unknown) => e instanceof KoyHatasi && e.kod === a.hata, `${a.op} → ${a.hata}`);
        continue;
      }
      const sonuc: any = calis();
      if (a.op === 'coz') {
        assert.deepEqual(olumler(sonuc.olumler), a.bekle.olumler);
        assert.equal(sonuc.avciBekliyor === null ? null : Number(sonuc.avciBekliyor), a.bekle.avci);
      } else if (a.op === 'oyBitir') {
        assert.deepEqual(olumler(sonuc.olumler), a.bekle.olumler);
        assert.equal(sonuc.avci === null ? null : Number(sonuc.avci), a.bekle.avci);
        assert.deepEqual(sonuc.esitAdaylar.map(Number).sort(), a.bekle.esit);
      } else if (a.op === 'avciVur') {
        assert.deepEqual(olumler(sonuc), a.bekle);
      } else if (a.op === 'kazanan') {
        assert.equal(sonuc, a.bekle);
      } else if (a.op === 'kahin') {
        assert.equal(sonuc, a.bekle);
      }
    }
  });
}
