import type { OyunTanimi } from './types.ts';
import { enOlasiKimTanimi } from './enOlasiKim.ts';

const TANIMLAR: Record<string, OyunTanimi> = {
  '07': enOlasiKimTanimi,
};

export function oyunTanimi(id: string): OyunTanimi | undefined {
  return TANIMLAR[id];
}
