const PAD = { top: 16, right: 12, bottom: 28, left: 64 };

export function escapeXml(text) {
  return String(text).replace(/[&<>"']/g, (char) => `&#${char.charCodeAt(0)};`);
}

export function niceStep(range, count) {
  const raw = range / count;
  const magnitude = 10 ** Math.floor(Math.log10(raw));
  const fraction = raw / magnitude;
  const nice = [1, 2, 2.5, 5, 10].find((candidate) => fraction <= candidate);
  return nice * magnitude;
}

export function niceTicks(min, max, count = 4) {
  const low = Math.min(0, min);
  const high = Math.max(0, max);
  if (low === high) return [0, 1];
  const step = niceStep(high - low, count);
  const ticks = [];
  for (let value = Math.floor(low / step) * step; value <= Math.ceil(high / step) * step + step / 2; value += step) {
    ticks.push(Math.round(value));
  }
  return ticks;
}

function frame(width, height, ticks, formatY) {
  const plotHeight = height - PAD.top - PAD.bottom;
  const low = ticks[0];
  const high = ticks.at(-1);
  const y = (value) => PAD.top + plotHeight - ((value - low) / (high - low)) * plotHeight;
  const grid = ticks
    .map((tick) => {
      const ty = y(tick).toFixed(1);
      const zero = tick === 0 ? ' zero' : '';
      return `<line class="grid${zero}" x1="${PAD.left}" x2="${width - PAD.right}" y1="${ty}" y2="${ty}"/>`
        + `<text class="axis" x="${PAD.left - 8}" y="${ty}" text-anchor="end" dominant-baseline="middle">${escapeXml(formatY(tick))}</text>`;
    })
    .join('');
  return { y, grid };
}

function xPositions(count, width) {
  const plotWidth = width - PAD.left - PAD.right;
  if (count === 1) return [PAD.left + plotWidth / 2];
  return Array.from({ length: count }, (_, i) => PAD.left + (i / (count - 1)) * plotWidth);
}

export function labelStep(count, width, every = 1) {
  const room = Math.max(2, Math.floor((width - PAD.left - PAD.right) / 56));
  return Math.max(every, Math.ceil(count / room));
}

function xAxis(labels, xs, width, height, every) {
  const step = labelStep(labels.length, width, every);
  return labels
    .map((label, i) => (i % step === 0
      ? `<text class="axis" x="${xs[i].toFixed(1)}" y="${height - 8}" text-anchor="middle">${escapeXml(label)}</text>`
      : ''))
    .join('');
}

function hitAreas(xs, height) {
  const half = xs.length > 1 ? (xs[1] - xs[0]) / 2 : 20;
  return xs
    .map((x, i) => `<rect class="hit" data-index="${i}" x="${(x - half).toFixed(1)}" y="0" width="${(half * 2).toFixed(1)}" height="${height}"/>`)
    .join('');
}

function svg(width, height, label, body) {
  return `<svg class="chart" viewBox="0 0 ${width} ${height}" role="img" aria-label="${escapeXml(label)}">${body}</svg>`;
}

export function lineChart({ labels, series, stacked = false, label, formatY, width = 640, height = 280, every = 1 }) {
  const totals = labels.map((_, i) => series.reduce((sum, s) => sum + s.values[i], 0));
  const values = stacked ? totals : series.flatMap((s) => s.values);
  const ticks = niceTicks(Math.min(...values), Math.max(...values));
  const { y, grid } = frame(width, height, ticks, formatY);
  const xs = xPositions(labels.length, width);
  const base = labels.map(() => 0);
  const shapes = series
    .map((s) => {
      const top = s.values.map((value, i) => (stacked ? base[i] + value : value));
      const line = top.map((value, i) => `${xs[i].toFixed(1)},${y(value).toFixed(1)}`).join(' ');
      let area = '';
      if (stacked) {
        const bottom = base.map((value, i) => `${xs[i].toFixed(1)},${y(value).toFixed(1)}`).reverse().join(' ');
        area = `<polygon class="area tone-${s.tone}" points="${line} ${bottom}"/>`;
        top.forEach((value, i) => { base[i] = value; });
      }
      return `${area}<polyline class="line tone-${s.tone}" points="${line}"/>`;
    })
    .join('');
  return svg(width, height, label, grid + shapes + xAxis(labels, xs, width, height, every) + hitAreas(xs, height));
}

export function barChart({ labels, values, label, formatY, width = 640, height = 280 }) {
  const ticks = niceTicks(Math.min(...values), Math.max(...values));
  const { y, grid } = frame(width, height, ticks, formatY);
  const slot = (width - PAD.left - PAD.right) / labels.length;
  const barWidth = Math.max(4, slot * 0.6);
  const plotXs = labels.map((_, i) => PAD.left + slot * (i + 0.5));
  const bars = values
    .map((value, i) => {
      const top = Math.min(y(value), y(0));
      const barHeight = Math.max(1, Math.abs(y(value) - y(0)));
      const tone = value < 0 ? 'negative' : 'positive';
      return `<rect class="bar tone-${tone}" x="${(plotXs[i] - barWidth / 2).toFixed(1)}" y="${top.toFixed(1)}" width="${barWidth.toFixed(1)}" height="${barHeight.toFixed(1)}" rx="3"/>`;
    })
    .join('');
  const hits = plotXs
    .map((x, i) => `<rect class="hit" data-index="${i}" x="${(x - slot / 2).toFixed(1)}" y="0" width="${slot.toFixed(1)}" height="${height}"/>`)
    .join('');
  return svg(width, height, label, grid + bars + xAxis(labels, plotXs, width, height, 1) + hits);
}

export function donutChart({ parts, label, size = 200, thickness = 32 }) {
  const total = parts.reduce((sum, part) => sum + part.value, 0);
  const radius = (size - thickness) / 2;
  const circumference = 2 * Math.PI * radius;
  let offset = 0;
  const rings = parts
    .map((part, i) => {
      const length = total > 0 ? (part.value / total) * circumference : 0;
      const ring = `<circle class="ring tone-${part.tone}" data-index="${i}" cx="${size / 2}" cy="${size / 2}" r="${radius.toFixed(1)}" stroke-width="${thickness}" stroke-dasharray="${length.toFixed(2)} ${(circumference - length).toFixed(2)}" stroke-dashoffset="${(-offset).toFixed(2)}" transform="rotate(-90 ${size / 2} ${size / 2})"/>`;
      offset += length;
      return ring;
    })
    .join('');
  const track = `<circle class="track" cx="${size / 2}" cy="${size / 2}" r="${radius.toFixed(1)}" stroke-width="${thickness}"/>`;
  return `<svg class="chart donut" viewBox="0 0 ${size} ${size}" role="img" aria-label="${escapeXml(label)}">${track}${rings}</svg>`;
}
