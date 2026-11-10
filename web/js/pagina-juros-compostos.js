import { attachTooltip, chartWidth } from './dica.js';
import { donutChart, lineChart } from './graficos.js';
import { simulate, totalMonths, yearlyPoints } from './juros-compostos.js';
import { formatCents, formatCompactCents, parseCents, parsePercent } from './money.js';

const form = document.getElementById('calculator');
const byId = (id) => document.getElementById(id);
let points = [];
let monthlyView = true;
let scenarios = [];

function field(name, parse) {
  const input = form.elements[name];
  const value = parse(input.value);
  input.setAttribute('aria-invalid', String(value === null));
  return value;
}

function read() {
  const values = {
    initialCents: field('initial', parseCents),
    monthlyCents: field('monthly', parseCents),
    ratePercent: field('rate', parsePercent),
    duration: field('duration', parsePercent),
    yearlyRaisePercent: field('raise', parsePercent),
    inflationPercent: field('inflation', parsePercent),
    rateB: form.elements.rateB.value.trim() === '' ? undefined : field('rateB', parsePercent),
    rateC: form.elements.rateC.value.trim() === '' ? undefined : field('rateC', parsePercent),
  };
  if (Object.values(values).includes(null)) return null;
  if (values.initialCents < 0 || values.monthlyCents < 0) return null;
  const months = Math.round(totalMonths(values.duration, form.elements.durationUnit.value));
  if (months < 1 || months > 1200) {
    form.elements.duration.setAttribute('aria-invalid', 'true');
    return null;
  }
  return { ...values, months, ratePeriod: form.elements.ratePeriod.value };
}

function yearsAndMonths(month) {
  const years = Math.floor(month / 12);
  const rest = month % 12;
  const parts = [];
  if (years > 0) parts.push(`${years} ${years === 1 ? 'ano' : 'anos'}`);
  if (rest > 0) parts.push(`${rest} ${rest === 1 ? 'mês' : 'meses'}`);
  return parts.join(' e ');
}

function labelFor(row, monthly) {
  return monthly ? `Mês ${row.month}` : `Ano ${Math.ceil(row.month / 12)}`;
}

function renderSummary(result, input) {
  byId('final').textContent = formatCents(result.finalCents);
  byId('invested').textContent = formatCents(result.investedCents);
  byId('interest').textContent = formatCents(result.interestCents);
  byId('real-card').hidden = input.inflationPercent === 0;
  byId('real').textContent = formatCents(result.realFinalCents);
  byId('crossover').textContent = result.crossoverMonth
    ? `Em ${yearsAndMonths(result.crossoverMonth)}, os juros do mês passam a ser maiores que o seu aporte. Daí em diante, o dinheiro trabalha mais do que você.`
    : 'Nesse prazo, os juros do mês ainda não passam o valor do seu aporte.';
}

function renderCharts(result, input) {
  const monthly = input.months <= 24;
  monthlyView = monthly;
  points = monthly ? result.rows : yearlyPoints(result.rows);
  const labels = points.map((row) => (monthly ? String(row.month) : String(Math.ceil(row.month / 12))));
  byId('evolution-unit').textContent = monthly ? 'mês' : 'ano';
  byId('evolution').innerHTML = lineChart({
    labels,
    series: [
      { tone: 'invested', values: points.map((row) => row.investedCents) },
      { tone: 'interest', values: points.map((row) => row.interestCents) },
    ],
    stacked: true,
    label: 'Evolução do patrimônio: total investido e juros acumulados',
    formatY: formatCompactCents,
    width: chartWidth(byId('evolution')),
  });
  byId('donut').innerHTML = donutChart({
    parts: [{ tone: 'invested', value: result.investedCents }, { tone: 'interest', value: Math.max(0, result.interestCents) }],
    label: 'Composição do valor final',
  });
  const share = result.finalCents > 0 ? Math.round((Math.max(0, result.interestCents) / result.finalCents) * 100) : 0;
  byId('donut-share').textContent = `${share}% do valor final veio dos juros`;
  renderComparison(input, labels, monthly);
}

function renderComparison(input, labels, monthly) {
  const rates = [['a', input.ratePercent], ['b', input.rateB], ['c', input.rateC]].filter(([, rate]) => rate !== undefined);
  byId('comparison-figure').hidden = rates.length < 2;
  if (rates.length < 2) return;
  const unit = input.ratePeriod === 'year' ? 'ao ano' : 'ao mês';
  scenarios = rates.map(([tone, rate]) => {
    const rows = simulate({ ...input, ratePercent: rate }).rows;
    const selected = monthly ? rows : yearlyPoints(rows);
    return { tone, rate, values: selected.map((row) => row.balanceCents) };
  });
  byId('comparison').innerHTML = lineChart({
    labels,
    series: scenarios,
    label: 'Comparação do valor final entre taxas',
    formatY: formatCompactCents,
    width: chartWidth(byId('comparison')),
  });
  byId('comparison-legend').replaceChildren(...scenarios.map((s) => {
    const item = document.createElement('li');
    item.className = `swatch-${s.tone}`;
    item.textContent = `${String(s.rate).replace('.', ',')}% ${unit}: ${formatCents(s.values.at(-1))}`;
    return item;
  }));
}

function renderTable(result) {
  byId('table-body').replaceChildren(...result.rows.map((row) => {
    const tr = document.createElement('tr');
    for (const value of [String(row.month), formatCents(row.contributionCents), formatCents(row.monthInterestCents), formatCents(row.investedCents), formatCents(row.interestCents), formatCents(row.balanceCents)]) {
      const td = document.createElement('td');
      td.textContent = value;
      tr.append(td);
    }
    return tr;
  }));
}

function render() {
  const input = read();
  if (!input) return;
  const result = simulate(input);
  renderSummary(result, input);
  renderCharts(result, input);
  renderTable(result);
}

attachTooltip(byId('evolution-figure'), (i) => {
  const row = points[i];
  return [labelFor(row, monthlyView), `Total: ${formatCents(row.balanceCents)}`, `Investido: ${formatCents(row.investedCents)}`, `Juros: ${formatCents(row.interestCents)}`];
});
attachTooltip(byId('comparison-figure'), (i) => [labelFor(points[i], monthlyView), ...scenarios.map((s) => `${String(s.rate).replace('.', ',')}%: ${formatCents(s.values[i])}`)]);
form.addEventListener('input', render);
window.addEventListener('resize', render);
form.addEventListener('submit', (event) => { event.preventDefault(); render(); });
render();
