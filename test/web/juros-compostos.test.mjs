import assert from 'node:assert/strict';
import { test } from 'node:test';

import { monthlyRate, simulate, totalMonths, yearlyPoints } from '../../web/js/juros-compostos.js';

test('monthlyRate converts a yearly rate into the equivalent monthly rate', () => {
  assert.equal(monthlyRate(1, 'month'), 0.01);
  assert.ok(Math.abs(monthlyRate(12.682503, 'year') - 0.01) < 1e-9);
});

test('totalMonths converts years into months', () => {
  assert.equal(totalMonths(2, 'year'), 24);
  assert.equal(totalMonths(7, 'month'), 7);
});

test('simulate compounds monthly and adds the contribution after the interest', () => {
  const result = simulate({ initialCents: 100000, monthlyCents: 10000, ratePercent: 1, months: 2 });
  assert.deepEqual(result.rows.map((row) => row.balanceCents), [111000, 122110]);
  assert.deepEqual(result.rows.map((row) => row.monthInterestCents), [1000, 1110]);
  assert.equal(result.finalCents, 122110);
  assert.equal(result.investedCents, 120000);
  assert.equal(result.interestCents, 2110);
});

test('simulate raises the contribution once a year', () => {
  const result = simulate({ initialCents: 0, monthlyCents: 10000, ratePercent: 0, months: 13, yearlyRaisePercent: 10 });
  assert.equal(result.rows[11].contributionCents, 10000);
  assert.equal(result.rows[12].contributionCents, 11000);
  assert.equal(result.investedCents, 131000);
});

test('simulate finds the month when interest passes the contribution', () => {
  const result = simulate({ initialCents: 1000000, monthlyCents: 5000, ratePercent: 1, months: 3 });
  assert.equal(result.crossoverMonth, 1);
  assert.equal(simulate({ initialCents: 0, monthlyCents: 0, ratePercent: 1, months: 3 }).crossoverMonth, null);
});

test('simulate shows the final amount in today\'s money', () => {
  const result = simulate({ initialCents: 100000, monthlyCents: 0, ratePercent: 0, months: 12, inflationPercent: 10 });
  assert.equal(result.realFinalCents, 90909);
});

test('simulate with zero months keeps the initial amount', () => {
  const result = simulate({ initialCents: 5000, monthlyCents: 100, ratePercent: 1, months: 0 });
  assert.equal(result.finalCents, 5000);
  assert.equal(result.interestCents, 0);
});

test('yearlyPoints keeps every twelfth month and the last one', () => {
  const rows = simulate({ initialCents: 0, monthlyCents: 100, ratePercent: 1, months: 30 }).rows;
  assert.deepEqual(yearlyPoints(rows).map((row) => row.month), [12, 24, 30]);
});
