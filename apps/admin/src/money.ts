const SCALE=4n;
const FACTOR=10n**SCALE;
export type MoneyInput=string|number|bigint;
function toScaled(value:MoneyInput):bigint{
  const raw=String(value).trim();
  if(!/^-?\d+(?:\.\d+)?$/.test(raw)) throw new Error('INVALID_MONEY');
  const neg=raw.startsWith('-');
  const unsigned=neg?raw.slice(1):raw;
  const [whole,fraction='']=unsigned.split('.');
  const frac=(fraction+'0000').slice(0,4);
  const scaled=BigInt(whole)*FACTOR+BigInt(frac);
  return neg?-scaled:scaled;
}
export function formatMoney(value:MoneyInput):string{
  const scaled=toScaled(value);
  const negative=scaled<0n;
  const abs=negative?-scaled:scaled;
  const cents=(abs+50n).toString().padStart(5,'0').slice(0,-2);
  const whole=cents.slice(0,-2)||'0';
  const fraction=cents.slice(-2);
  return (negative?'-':'')+whole+'.'+fraction;
}