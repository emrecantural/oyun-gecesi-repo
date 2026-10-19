// CSV içeriğinden sunucu içerik modülünü üretir. Varsayılan: yalnız durum=onayli.
// Taslak dahil etmek için: ICERIK_TASLAK=1 node scripts/icerik.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const kok = join(dirname(fileURLToPath(import.meta.url)), '..');
const taslak = process.env.ICERIK_TASLAK === '1' || process.env.ICERIK_TASLAK === 'true';

function csvAyristir(metin) {
  const satirlar = [];
  let alan = '';
  let satir = [];
  let tirnak = false;
  for (let i = 0; i < metin.length; i++) {
    const c = metin[i];
    if (tirnak) {
      if (c === '"' && metin[i + 1] === '"') { alan += '"'; i++; }
      else if (c === '"') tirnak = false;
      else alan += c;
    } else if (c === '"') tirnak = true;
    else if (c === ',') { satir.push(alan); alan = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && metin[i + 1] === '\n') i++;
      satir.push(alan); alan = '';
      if (satir.length > 1 || satir[0] !== '') satirlar.push(satir);
      satir = [];
    } else alan += c;
  }
  if (alan !== '' || satir.length) { satir.push(alan); satirlar.push(satir); }
  return satirlar;
}

const csv = readFileSync(join(kok, '..', 'app', 'assets', 'icerik', '07-en-olasi-kim.csv'), 'utf8');
const [baslik, ...govde] = csvAyristir(csv);
const ix = Object.fromEntries(baslik.map((b, i) => [b, i]));
const soru07 = govde
  .filter((r) => r[ix.tur] === 'soru' && (taslak || r[ix.durum] === 'onayli'))
  .map((r) => ({ id: r[ix.id], metin: r[ix.metin], kategori: r[ix.seviye] }));

// Ücretsiz bölme (uygulamadaki ucretsizBol ile aynı): her seviyede dosya sırasının ilk min(n, max(5, ceil(0,4n))) öğesi.
const gruplar = new Map();
for (const q of soru07) {
  if (!gruplar.has(q.kategori)) gruplar.set(q.kategori, []);
  gruplar.get(q.kategori).push(q);
}
for (const liste of gruplar.values()) {
  const n = liste.length;
  const serbest = Math.min(n, Math.max(5, Math.ceil(0.4 * n)));
  liste.forEach((q, i) => {
    q.ucretsiz = i < serbest;
  });
}

const cikti =
  '// Bu dosya scripts/icerik.mjs ile üretilir; elle düzenlemeyin.\n' +
  `// Taslak dahil: ${taslak ? 'evet' : 'hayır'}\n` +
  "import type { Icerik } from './games/types.ts';\n\n" +
  `export const ICERIK: Icerik = ${JSON.stringify({ soru07 }, null, 2)};\n`;
writeFileSync(join(kok, 'src', 'icerik_uretilen.ts'), cikti);
console.log(`soru07: ${soru07.length} (taslak ${taslak ? 'dahil' : 'hariç'})`);
