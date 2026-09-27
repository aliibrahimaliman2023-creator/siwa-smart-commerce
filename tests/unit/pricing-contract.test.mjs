import assert from 'node:assert/strict';
const round=(n)=>Math.round((n+Number.EPSILON)*100)/100;
assert.equal(round(10.125),10.13);
assert.equal(round(100*2.5),250);
console.log('pricing contract: ok');