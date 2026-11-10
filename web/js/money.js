const currency = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
const compact = new Intl.NumberFormat('pt-BR', { notation: 'compact', maximumFractionDigits: 1 });

export function parseCents(text) {
  const clean = String(text ?? '').replace(/[R$\s]/g, '');
  if (clean === '') return 0;
  if (!/^-?\d{1,3}(\.\d{3})*(,\d{1,2})?$|^-?\d+(,\d{1,2})?$/.test(clean)) return null;
  const [whole, fraction = ''] = clean.replace(/\./g, '').split(',');
  const sign = whole.startsWith('-') ? -1 : 1;
  const units = Math.abs(Number(whole)) * 100 + Number(fraction.padEnd(2, '0'));
  return sign * units;
}

export function parsePercent(text) {
  const clean = String(text ?? '').replace(/[%\s]/g, '');
  if (clean === '') return 0;
  if (!/^\d+(,\d+)?$/.test(clean)) return null;
  return Number(clean.replace(',', '.'));
}

export function formatCents(cents) {
  return currency.format(cents / 100);
}

export function formatCompactCents(cents) {
  return `R$ ${compact.format(cents / 100)}`;
}
