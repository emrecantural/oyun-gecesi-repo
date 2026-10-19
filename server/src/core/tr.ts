/** Türkçe büyük/küçük harf ve aksan duyarsız karşılaştırma anahtarı. */
export function foldTr(s: string): string {
  return s
    .replace(/İ/g, 'i')
    .replace(/I/g, 'ı')
    .toLowerCase()
    .replace(/ı/g, 'i')
    .replace(/ş/g, 's')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .replace(/â/g, 'a')
    .replace(/î/g, 'i')
    .replace(/û/g, 'u')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]/g, '');
}

// Asgari başlangıç listesi: tam liste insan editör tarafından genişletilir (mimari.md açık soru 4).
const YASAK = ['amk', 'aq', 'orospu', 'piç', 'sik', 'yarrak', 'götveren', 'ibne', 'puşt', 'siktir'];
const YASAK_KATLANMIS = YASAK.map(foldTr);

export function takmaAdUygun(ad: string): boolean {
  const k = foldTr(ad);
  if (k.length === 0) return false;
  return !YASAK_KATLANMIS.some((y) => k.includes(y));
}
