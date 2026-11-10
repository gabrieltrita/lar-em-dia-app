import assert from 'node:assert/strict';
import { test } from 'node:test';

import { barChart, donutChart, escapeXml, labelStep, lineChart, niceStep, niceTicks } from '../../web/js/graficos.js';

const format = (value) => String(value);

test('niceTicks covers zero and the range with round steps', () => {
  assert.equal(niceStep(1000, 4), 250);
  assert.equal(niceStep(4000, 4), 1000);
  assert.deepEqual(niceTicks(0, 950), [0, 250, 500, 750, 1000]);
  assert.deepEqual(niceTicks(-300, 900), [-500, 0, 500, 1000]);
  assert.deepEqual(niceTicks(0, 0), [0, 1]);
});

test('escapeXml neutralises markup', () => {
  assert.equal(escapeXml('<a & "b">'), '&#60;a &#38; &#34;b&#34;&#62;');
});

test('lineChart stacks areas and adds one hit area per point', () => {
  const svg = lineChart({
    labels: ['1', '2', '3'],
    series: [{ tone: 'invested', values: [1, 2, 3] }, { tone: 'interest', values: [0, 1, 2] }],
    stacked: true,
    label: 'Evolução',
    formatY: format,
  });
  assert.match(svg, /^<svg class="chart"/);
  assert.equal(svg.match(/<polygon class="area/g).length, 2);
  assert.equal(svg.match(/class="hit"/g).length, 3);
  assert.match(svg, /aria-label="Evolução"/);
});

test('lineChart draws plain lines when not stacked', () => {
  const svg = lineChart({
    labels: ['a'],
    series: [{ tone: 'a', values: [5] }, { tone: 'b', values: [7] }],
    label: 'Cenários',
    formatY: format,
  });
  assert.equal(svg.includes('<polygon'), false);
  assert.equal(svg.match(/<polyline/g).length, 2);
});

test('barChart marks negative months', () => {
  const svg = barChart({ labels: ['a', 'b'], values: [100, -50], label: 'Saldo', formatY: format });
  assert.equal(svg.match(/tone-positive/g).length, 1);
  assert.equal(svg.match(/tone-negative/g).length, 1);
});

test('donutChart splits the ring by value', () => {
  const svg = donutChart({ parts: [{ tone: 'a', value: 1 }, { tone: 'b', value: 3 }], label: 'Composição' });
  assert.equal(svg.match(/class="ring/g).length, 2);
  assert.match(donutChart({ parts: [{ tone: 'a', value: 0 }], label: 'x' }), /stroke-dasharray="0.00/);
});

test('labelStep skips x labels that would not fit', () => {
  assert.equal(labelStep(12, 640), 2);
  assert.equal(labelStep(12, 1200), 1);
  assert.equal(labelStep(120, 320), 30);
  assert.equal(labelStep(3, 640, 2), 2);
});
