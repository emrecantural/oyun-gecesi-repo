import { DurableObject } from 'cloudflare:workers';
import { GecisDefteri, type OdaHakki, type RedeemSonucu } from './gecis.ts';
import type { Env } from './odaNesnesi.ts';

/** Tek örnek (idFromName('defter')): geçiş kayıtları ve deneme hakkı. Depo işlemleri DO tarafından sıralanır. */
export class GecisNesnesi extends DurableObject<Env> {
  private defter = new GecisDefteri(this.ctx.storage);

  redeem(tokenOzeti: string, installOzeti: string): Promise<RedeemSonucu> {
    return this.defter.redeem(tokenOzeti, installOzeti);
  }
  bak(passId: string | undefined, installOzeti: string): Promise<OdaHakki> {
    return this.defter.bak(passId, installOzeti);
  }
  kullan(hak: OdaHakki, passId: string | undefined, installOzeti: string): Promise<void> {
    return this.defter.kullan(hak, passId, installOzeti);
  }
}
