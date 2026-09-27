import assert from 'node:assert/strict';
const available=(onHand,reserved,damaged,quarantine)=>onHand-reserved-damaged-quarantine;
assert.equal(available(10,2,1,1),6);
assert.equal(available(5,5,0,0),0);
console.log('inventory contract: ok');