export type Rand = () => number;

/** Üretimde güvenli rastgelelik; testte tohumlu xorshift32. */
export function guvenliRand(): Rand {
  return () => {
    const a = new Uint32Array(1);
    crypto.getRandomValues(a);
    return a[0] / 0x100000000;
  };
}

export function tohumluRand(tohum: number): Rand {
  let x = tohum >>> 0 || 0x9e3779b9;
  return () => {
    x ^= x << 13; x >>>= 0;
    x ^= x >>> 17;
    x ^= x << 5; x >>>= 0;
    return x / 0x100000000;
  };
}

export function karistir<T>(liste: readonly T[], rand: Rand): T[] {
  const a = liste.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const ALFABE = '23456789ABCDEFGHJKMNPQRSTUVWXYZ'; // 0/O, 1/I/L yok

export function odaKodu(rand: Rand): string {
  let s = '';
  for (let i = 0; i < 6; i++) s += ALFABE[Math.floor(rand() * ALFABE.length)];
  return s;
}

export function rastgeleBelirtec(rand: Rand): string {
  let s = '';
  for (let i = 0; i < 4; i++) s += Math.floor(rand() * 0x100000000).toString(16).padStart(8, '0');
  return s;
}
