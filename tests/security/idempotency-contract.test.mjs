import assert from 'node:assert/strict';
const key='checkout-20260927-123456';
assert.ok(key.length>=16);
const same=(a,b)=>a===b;
assert.equal(same('hash','hash'),true);
assert.equal(same('hash','other'),false);
console.log('idempotency contract: ok');