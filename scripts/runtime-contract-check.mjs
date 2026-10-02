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

function sourceFiles(dir) {
  const out = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = `${dir}/${entry.name}`;
    if (entry.isDirectory()) out.push(...sourceFiles(path));
    else if (/\.(ts|tsx)$/.test(entry.name)) out.push(path);
  }
  return out;
}

const files = sourceFiles('apps');
const forbidden = /db\.from\(['"](commerce|inventory|production|logistics|catalog|marketing|cms|identity|platform|finance|customer|communication)\./;

for (const file of files) {
  const content = readFileSync(file, 'utf8');
  assert.equal(forbidden.test(content), false, `invalid domain-schema access in ${file}`);
}

const storefront = readFileSync('apps/storefront/src/main.tsx', 'utf8');
const money = readFileSync('apps/storefront/src/money.ts', 'utf8');
const checkout = readFileSync('supabase/functions/checkout/index.ts', 'utf8');
const recovery = readFileSync('supabase/functions/checkout-recovery/index.ts', 'utf8');

assert.match(storefront, /idempotencyKey/);
assert.match(storefront, /from'\.\/money'/);
assert.equal(/\bNumber\(/.test(storefront), false, 'storefront must not use Number() for monetary arithmetic');
assert.equal(/\bparseFloat\(/.test(storefront), false, 'storefront must not use parseFloat() for monetary arithmetic');
assert.match(money, /BigInt/);
assert.match(money, /multiplyMoney/);
assert.match(storefront, /idempotency-key/);
assert.match(storefront, /functions\.invoke\(['"]checkout-recovery['"]/);
assert.match(checkout, /checkout_atomic_v2/);
assert.match(recovery, /Authorization/);
assert.match(recovery, /UNAUTHENTICATED/);

console.log('runtime contracts: ok');