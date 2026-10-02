import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync('supabase/functions/checkout/index.ts', 'utf8');

assert.match(source, /rpc\('checkout_atomic_v2'/);
for (const arg of [
  'p_idempotency_key',
  'p_currency',
  'p_location_id',
  'p_items',
  'p_shipping_address',
  'p_customer_snapshot',
  'p_coupon_code',
]) {
  assert.equal(source.includes(arg), true, `checkout RPC contract missing ${arg}`);
}

assert.match(
  source,
  /p_coupon_code:\s*body\.couponCode\?\?null/,
  'checkout RPC must pass an explicit null coupon when absent',
);

console.log('checkout RPC contract: ok');
