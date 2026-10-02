export type MoneyInput = string | number;

const SCALE = 4n;
const FACTOR = 10_000n;

function toScaled(value: MoneyInput): bigint {
  const text = String(value).trim();
  if (!/^\d+(?:\.\d+)?$/.test(text)) throw new Error("Invalid monetary value");
  const [whole, fraction = ""] = text.split(".");
  if (fraction.length > 4) throw new Error("Monetary value exceeds 4 decimal places");
  return BigInt(whole) * FACTOR + BigInt((fraction + "0000").slice(0, 4));
}

export function addMoney(a: MoneyInput, b: MoneyInput): string {
  return formatScaled(toScaled(a) + toScaled(b));
}

export function multiplyMoney(amount: MoneyInput, quantity: number): string {
  if (!Number.isSafeInteger(quantity) || quantity < 0) throw new Error("Invalid quantity");
  return formatScaled(toScaled(amount) * BigInt(quantity));
}

function formatScaled(value: bigint): string {
  const whole = value / FACTOR;
  const fraction = (value % FACTOR).toString().padStart(4, "0");
  return fraction === "0000" ? whole.toString() : `${whole}.${fraction.replace(/0+$/, "")}`;
}

export function formatMoney(value: MoneyInput, fractionDigits = 2): string {
  const scaled = toScaled(value);
  const rounded = fractionDigits === 4 ? scaled : (scaled + 50n) / 100n;
  if (fractionDigits === 2) {
    const whole = rounded / 100n;
    const fraction = (rounded % 100n).toString().padStart(2, "0");
    return `${whole}.${fraction}`;
  }
  return formatScaled(scaled);
}

export function hasMoney(value: unknown): value is string | number {
  return typeof value === "string" || (typeof value === "number" && Number.isFinite(value));
}
