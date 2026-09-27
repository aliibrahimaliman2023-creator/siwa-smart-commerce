import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { readdirSync } from 'node:fs';

const requiredFunctions = [
  'supabase/functions/checkout/index.ts',
  'supabase/functions/api-v1/index.ts',
  'supabase/functions/checkout-recovery/index.ts',
];

for (const file of requiredFunctions) {
  assert.ok(existsSync(file), `missing required edge function: ${file}`);
}

const sourceFiles = globSync('apps/**/*.{ts,tsx}', { nodir: true });
const forbidden = /db\.from\(['"](commerce|inventory|production|logistics|catalog|marketing|cms|identity|platform|finance|customer|communication)\./;

for (const file of sourceFiles) {
  const content = readFileSync(file, 'utf8');
  assert.equal(forbidden.test(content), false, `invalid domain-schema access in ${file}`);
}

const storefront = readFileSync('apps/storefront/src/main.tsx', 'utf8');
const checkout = readFileSync('supabase/functions/checkout/index.ts', 'utf8');

assert.match(storefront, /idempotencyKey/);
assert.match(storefront, /idempotency-key/);
assert.match(checkout, /checkout_atomic_v2/);

console.log('runtime contracts: ok');
