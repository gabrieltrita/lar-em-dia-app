export function monthlyRate(ratePercent, period) {
  const rate = ratePercent / 100;
  return period === 'year' ? (1 + rate) ** (1 / 12) - 1 : rate;
}

export function totalMonths(length, unit) {
  return unit === 'year' ? length * 12 : length;
}

export function simulate({
  initialCents,
  monthlyCents,
  ratePercent,
  ratePeriod = 'month',
  months,
  yearlyRaisePercent = 0,
  inflationPercent = 0,
}) {
  const rate = monthlyRate(ratePercent, ratePeriod);
  const inflation = monthlyRate(inflationPercent, 'year');
  let balanceCents = initialCents;
  let investedCents = initialCents;
  let contributionCents = monthlyCents;
  let crossoverMonth = null;
  const rows = [];
  for (let month = 1; month <= months; month += 1) {
    if (month > 1 && (month - 1) % 12 === 0) {
      contributionCents = Math.round(contributionCents * (1 + yearlyRaisePercent / 100));
    }
    const monthInterestCents = Math.round(balanceCents * rate);
    balanceCents += monthInterestCents + contributionCents;
    investedCents += contributionCents;
    if (crossoverMonth === null && contributionCents > 0 && monthInterestCents >= contributionCents) {
      crossoverMonth = month;
    }
    rows.push({
      month,
      contributionCents,
      monthInterestCents,
      investedCents,
      interestCents: balanceCents - investedCents,
      balanceCents,
      realBalanceCents: Math.round(balanceCents / (1 + inflation) ** month),
    });
  }
  const last = rows.at(-1) ?? { balanceCents: initialCents, investedCents: initialCents, realBalanceCents: initialCents };
  return {
    rows,
    finalCents: last.balanceCents,
    investedCents: last.investedCents,
    interestCents: last.balanceCents - last.investedCents,
    realFinalCents: last.realBalanceCents,
    crossoverMonth,
  };
}

export function yearlyPoints(rows) {
  return rows.filter((row) => row.month % 12 === 0 || row.month === rows.length);
}
