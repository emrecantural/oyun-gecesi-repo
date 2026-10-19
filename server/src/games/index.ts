import type { OyunTanimi } from './types.ts';
import { enOlasiKimTanimi } from './enOlasiKim.ts';
import { tombalaTanimi } from './tombala.ts';
import { koyKurtlarTanimi } from './koyKurtlar.ts';

const TANIMLAR: Record<string, OyunTanimi> = {
  '01': tombalaTanimi,
  '03': koyKurtlarTanimi,
  '07': enOlasiKimTanimi,
};

export function oyunTanimi(id: string): OyunTanimi | undefined {
  return TANIMLAR[id];
}
