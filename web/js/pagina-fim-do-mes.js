import { firstNegativeMonth, monthLeftover, projectMonths } from './fim-do-mes.js';
import { barChart } from './graficos.js';
import { attachTooltip, chartWidth } from './dica.js';
import { formatCents, formatCompactCents, parseCents } from './money.js';

const form = document.getElementById('calculator');
const fields = ['balance', 'income', 'fixed', 'variable'];

function read() {
  const values = {};
  let valid = true;
  for (const name of fields) {
    const input = form.elements[name];
    const cents = parseCents(input.value);
    input.setAttribute('aria-invalid', String(cents === null));
    if (cents === null) valid = false;
    values[name] = cents;
  }
  return valid ? values : null;
}

function renderTable(rows) {
  const body = document.getElementById('months-table');
  body.replaceChildren(...rows.map((row) => {
    const tr = document.createElement('tr');
    const month = document.createElement('td');
    month.textContent = row.label;
    const amount = document.createElement('td');
    amount.textContent = formatCents(row.endCents);
    if (row.negative) amount.className = 'negative';
    tr.append(month, amount);
    return tr;
  }));
}

function render() {
  const values = read();
  if (!values) return;
  const input = { balanceCents: values.balance, incomeCents: values.income, fixedCents: values.fixed, variableCents: values.variable };
  const rows = projectMonths({ ...input, start: new Date() });
  const leftover = monthLeftover(input);
  const negative = firstNegativeMonth(rows);
  document.getElementById('leftover').textContent = formatCents(leftover);
  document.getElementById('leftover-card').classList.toggle('alert', leftover < 0);
  document.getElementById('first-month').textContent = formatCents(rows[0].endCents);
  document.getElementById('last-month').textContent = formatCents(rows.at(-1).endCents);
  const message = document.getElementById('message');
  message.classList.toggle('alert', negative !== null);
  message.textContent = negative
    ? `Atenção: nesse ritmo, o saldo fica negativo em ${negative.label}.`
    : 'Nesse ritmo, o saldo fica no azul nos próximos 12 meses.';
  document.getElementById('chart').innerHTML = barChart({
    labels: rows.map((row) => row.shortLabel),
    values: rows.map((row) => row.endCents),
    width: chartWidth(document.getElementById('chart')),
    label: 'Saldo previsto no fim de cada mês',
    formatY: formatCompactCents,
  });
  renderTable(rows);
  chartRows = rows;
}

let chartRows = [];
attachTooltip(document.getElementById('chart-figure'), (i) => [chartRows[i].label, formatCents(chartRows[i].endCents)]);
form.addEventListener('input', render);
window.addEventListener('resize', render);
form.addEventListener('submit', (event) => { event.preventDefault(); render(); });
render();
