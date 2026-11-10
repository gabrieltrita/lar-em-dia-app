import assert from 'node:assert/strict';
import { test } from 'node:test';

import { formatCents, parseCents, parsePercent } from '../../web/js/money.js';

test('parseCents reads Brazilian amounts into integer cents', () => {
  assert.equal(parseCents('1.234,56'), 123456);
  assert.equal(parseCents('R$ 2500'), 250000);
  assert.equal(parseCents('10,5'), 1050);
  assert.equal(parseCents('-300'), -30000);
  assert.equal(parseCents(''), 0);
});

test('parseCents rejects text that is not an amount', () => {
  for (const text of ['abc', '1,234', '12.34', '1,999']) {
    assert.equal(parseCents(text), null, text);
  }
});

test('parsePercent reads a decimal comma', () => {
  assert.equal(parsePercent('0,8'), 0.8);
  assert.equal(parsePercent('12 %'), 12);
  assert.equal(parsePercent(''), 0);
  assert.equal(parsePercent('-1'), null);
});

test('formatCents writes reais', () => {
  assert.equal(formatCents(123456).replace(/\s/g, ' '), 'R$ 1.234,56');
});
