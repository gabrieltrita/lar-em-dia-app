const monthName = new Intl.DateTimeFormat('pt-BR', { month: 'short', year: 'numeric' });

export function monthLeftover({ incomeCents, fixedCents, variableCents }) {
  return incomeCents - fixedCents - variableCents;
}

export function monthLabel(start, offset) {
  const date = new Date(start.getFullYear(), start.getMonth() + offset, 1);
  return monthName.format(date).replace('.', '');
}

export function shortMonthLabel(start, offset) {
  const date = new Date(start.getFullYear(), start.getMonth() + offset, 1);
  const month = monthName.formatToParts(date).find((part) => part.type === 'month').value.replace('.', '');
  return `${month}/${String(date.getFullYear()).slice(-2)}`;
}

export function projectMonths({ balanceCents, incomeCents, fixedCents, variableCents, start, months = 12 }) {
  const leftover = monthLeftover({ incomeCents, fixedCents, variableCents });
  return Array.from({ length: months }, (_, index) => {
    const endCents = balanceCents + leftover * (index + 1);
    return { index, label: monthLabel(start, index), shortLabel: shortMonthLabel(start, index), endCents, negative: endCents < 0 };
  });
}

export function firstNegativeMonth(rows) {
  return rows.find((row) => row.negative) ?? null;
}
