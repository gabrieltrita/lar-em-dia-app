import assert from 'node:assert/strict';
import { test } from 'node:test';

import { firstNegativeMonth, monthLabel, monthLeftover, projectMonths, shortMonthLabel } from '../../web/js/fim-do-mes.js';

const start = new Date(2026, 10, 15);

test('monthLeftover subtracts fixed and variable expenses from income', () => {
  assert.equal(monthLeftover({ incomeCents: 500000, fixedCents: 300000, variableCents: 150000 }), 50000);
});

test('projectMonths adds the leftover to the balance month by month', () => {
  const rows = projectMonths({
    balanceCents: 100000, incomeCents: 400000, fixedCents: 350000, variableCents: 100000, start, months: 3,
  });
  assert.deepEqual(rows.map((row) => row.endCents), [50000, 0, -50000]);
  assert.deepEqual(rows.map((row) => row.negative), [false, false, true]);
  assert.equal(firstNegativeMonth(rows).index, 2);
});

test('projectMonths defaults to twelve months and labels each one', () => {
  const rows = projectMonths({ balanceCents: 0, incomeCents: 1, fixedCents: 0, variableCents: 0, start });
  assert.equal(rows.length, 12);
  assert.equal(rows[0].label, monthLabel(start, 0));
  assert.match(rows[2].label, /jan/);
  assert.equal(firstNegativeMonth(rows), null);
});

test('shortMonthLabel fits a chart axis', () => {
  assert.equal(shortMonthLabel(start, 0), 'nov/26');
  assert.equal(shortMonthLabel(start, 2), 'jan/27');
});
